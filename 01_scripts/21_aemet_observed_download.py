#!/usr/bin/env python3
"""Download observed daily Tmax/Tmin from the AEMET OpenData API for the ESD-RegBA station set.

The PNACC archive serves observations only to 2020-12-31, so the recent years have to come from
the API. Rather than grafting 2021-2025 onto the archive series, the whole 1995-2025 period is
pulled from a single source: the archive product is curated and homogenised while the API serves
raw records, and splicing the two would put an inhomogeneity exactly where the recent warming
signal lives. The 1995-2020 overlap against the archive then becomes a measurable check instead
of a hidden assumption.

The API answers in two steps: the first call returns a JSON envelope carrying a 'datos' URL, and
the payload is fetched from there. It rate-limits with HTTP 429 past roughly 50 calls a minute,
and each request covers a limited span, which --probe measures instead of assuming.

Only the standard library is used, so this runs under any Python 3 on Ladon without an env.

Credentials: the key is read from AEMET_API_KEY and never written to disk or into the logs.
    export AEMET_API_KEY='...'

Usage (Ladon):
    python3 21_aemet_observed_download.py --probe --stations stations_obs.txt
    nohup python3 21_aemet_observed_download.py --stations stations_obs.txt \\
        --out obs_api --from 1995 --to 2025 --chunk-months 6 > obs_download.log 2>&1 &
    python3 21_aemet_observed_download.py --merge --out obs_api --csv observed_1995_2025.csv
"""

import argparse
import csv
import json
import os
import ssl
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta

BASE = "https://opendata.aemet.es/opendata"
INVENTORY = f"{BASE}/api/valores/climatologicos/inventarioestaciones/todasestaciones"
DAILY = f"{BASE}/api/valores/climatologicos/diarios/datos/fechaini/{{ini}}/fechafin/{{fin}}/estacion/{{idema}}"

# stay clear of the documented ~50 calls/minute ceiling. Only the keyed first step is throttled.
RATE_PER_MIN = 40.0
MIN_INTERVAL = 60.0 / RATE_PER_MIN
_last_call = [0.0]
_rate_lock = threading.Lock()


def api_key():
    k = os.environ.get("AEMET_API_KEY", "").strip()
    if not k:
        sys.exit("AEMET_API_KEY is not set. export AEMET_API_KEY='...' before running.")
    return k


def _throttle():
    """Global gate on keyed calls. With several workers the sleep has to be computed and the slot
    claimed under one lock, or they all read the same timestamp and fire together."""
    with _rate_lock:
        wait = MIN_INTERVAL - (time.time() - _last_call[0])
        if wait < 0:
            wait = 0.0
        _last_call[0] = time.time() + wait
    if wait > 0:
        time.sleep(wait)


def _get(url, key, tries=5, throttled=True):
    """One GET with backoff. 429 means the rate limit was hit, so back off and retry.

    Only the keyed call is throttled: the second step fetches a temporary URL that carries no
    api_key, so it should not count against the quota. If it turns out it does, the 429 branch
    below absorbs it."""
    ctx = ssl.create_default_context()
    for attempt in range(tries):
        if throttled:
            _throttle()
        req = urllib.request.Request(url, headers={"api_key": key, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=90, context=ctx) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(15 * (attempt + 1))
                continue
            if e.code == 404:
                return None                      # station has no data for the period
            if e.code == 401:
                sys.exit("HTTP 401: the API key is rejected. Keys expire after 3 months; renew it.")
            if attempt == tries - 1:
                raise
            time.sleep(5 * (attempt + 1))
        except Exception:                                         # noqa: BLE001
            # Everything else is a transport hiccup and must be retried here. RemoteDisconnected in
            # particular does NOT arrive wrapped in URLError, so listing exception types let it
            # escape to the station level and discard that station's whole 62-request run.
            if attempt == tries - 1:
                raise
            time.sleep(5 * (attempt + 1))
    return None


class FetchFailed(Exception):
    """The request did not complete. Distinct from 'this period genuinely has no records'."""


def fetch(url, key, strict=False):
    """Resolve the two-step response: envelope first, then the payload it points at.

    With strict=True the two outcomes are separated, which matters when the caller is deciding
    whether a station may be written as complete. AEMET answers 'no records here' with estado 404
    inside an HTTP 200, so that case returns an empty list; anything else that stops the request
    from completing (a 429 or a 5xx arriving inside a 200 envelope, a payload URL that fails) raises
    instead of returning empty, because an empty result would be checkpointed as a finished station
    carrying a six-month hole."""
    env = _get(url, key)
    if env is None:
        if strict:
            raise FetchFailed(f"no envelope from {url[:110]}")
        return None
    if isinstance(env, dict) and env.get("estado") == 404:
        return [] if strict else None                      # no records for this period: legitimate
    if not isinstance(env, dict) or "datos" not in env:
        if strict:
            est = env.get("estado") if isinstance(env, dict) else None
            desc = env.get("descripcion", "") if isinstance(env, dict) else ""
            raise FetchFailed(f"envelope without 'datos' (estado={est}, {desc!r})")
        return None
    data = _get(env["datos"], key, throttled=False)
    if data is None:
        if strict:
            raise FetchFailed("the envelope resolved but its payload did not")
        return None
    return data


def num(v):
    """AEMET writes decimals with a comma and uses Ip/Acum markers for trace values."""
    if v is None:
        return None
    s = str(v).strip().replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def chunk_ranges(y0, y1, months):
    """Split [y0, y1] into spans the API accepts. It refuses anything over 6 months per request:
    'El rango de fechas no puede ser superior a 6 meses'."""
    cur, end = date(y0, 1, 1), date(y1, 12, 31)
    while cur <= end:
        m = cur.month - 1 + months
        nxt = date(cur.year + m // 12, m % 12 + 1, 1)      # first day after this span
        fin = min(nxt - timedelta(days=1), end)
        yield cur, fin
        cur = fin + timedelta(days=1)


def station_rows(idema, y0, y1, months, key):
    """Daily records for one station, requested in spans the API will accept.

    A chunk that will not come back after its retries raises, so the station is left unwritten and
    the resume picks it up later. Returning a short series instead would be worse: it would be
    checkpointed as complete and silently hold a gap."""
    out = []
    for ini, fin in chunk_ranges(y0, y1, months):
        url = DAILY.format(ini=f"{ini}T00:00:00UTC", fin=f"{fin}T23:59:59UTC", idema=idema)
        data = fetch(url, key, strict=True)   # raises rather than skipping, so the docstring holds
        if data:
            for rec in data:
                tmax, tmin = num(rec.get("tmax")), num(rec.get("tmin"))
                if tmax is None and tmin is None:
                    continue
                out.append((rec.get("fecha", ""), tmax, tmin))
    return out


def probe_request(url, key):
    """One request reported in full. fetch() collapses every failure into None, which hides whether
    a station simply has no records, the date format was rejected, or the payload step failed."""
    ctx = ssl.create_default_context()
    _throttle()
    req = urllib.request.Request(url, headers={"api_key": key, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=90, context=ctx) as r:
            env = json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:160]}"
    except Exception as e:                                        # noqa: BLE001 - the point is to report it
        return None, f"{type(e).__name__}: {e}"
    if not isinstance(env, dict):
        return None, f"envelope is not an object: {str(env)[:120]}"
    estado, desc = env.get("estado"), env.get("descripcion", "")
    if "datos" not in env:
        return None, f"estado={estado} descripcion={desc!r} (no 'datos' url)"
    _throttle()
    try:
        req2 = urllib.request.Request(env["datos"], headers={"api_key": key, "Accept": "application/json"})
        with urllib.request.urlopen(req2, timeout=90, context=ctx) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
    except Exception as e:                                        # noqa: BLE001
        return None, f"estado={estado} but the payload failed: {type(e).__name__}: {e}"
    return data, f"estado={estado}, {len(data)} records"


def cmd_probe(args, key):
    """Measure what the API actually allows instead of guessing: inventory match and chunk size."""
    print("1. inventory")
    inv = fetch(INVENTORY, key)
    if not inv:
        sys.exit("   could not read the station inventory; check the key and connectivity")
    by_id = {str(s.get("indicativo", "")).strip(): s for s in inv}
    print(f"   AEMET publishes {len(by_id)} stations")
    wanted = read_stations(args.stations) if args.stations else []
    hits = [s for s in wanted if s in by_id] if wanted else sorted(by_id)
    if wanted:
        print(f"   of our {len(wanted)} station ids, {len(hits)} exist in AEMET ({100*len(hits)/len(wanted):.1f}%)")
        missing = [s for s in wanted if s not in by_id][:8]
        if missing:
            print(f"   examples that do not match: {', '.join(missing)}")
    if not hits:
        sys.exit("   no usable station to probe")

    # Several stations, not one: a single dead station would otherwise look like a broken endpoint.
    sample = args.probe_stations.split(",") if args.probe_stations else hits[:4]
    print(f"\n2. does a plain request return data? ({len(sample)} stations, first half of 2019)")
    working = []
    for sid in sample:
        name = str(by_id.get(sid, {}).get("nombre", "?"))[:28]
        url = DAILY.format(ini="2019-01-01T00:00:00UTC", fin="2019-06-30T23:59:59UTC", idema=sid)
        data, note = probe_request(url, key)
        print(f"   {sid:8s} {name:28s} -> {note}")
        if data:
            working.append(sid)
    if not working:
        print("\n   Every station came back empty. Read the notes above:")
        print("     'estado=404' with a descripcion about no data  -> those stations have no daily")
        print("        climatological records; try others with --probe-stations id1,id2")
        print("     'HTTP 401'                                     -> the key is rejected or expired")
        print("     anything about the date format                 -> the request shape is wrong")
        print(f"\n   URL used (key travels in the header, not here):\n     {url}")
        return

    print(f"\n3. largest span the API accepts (station {working[0]})")
    for months in (6, 3, 1):
        ini, fin = next(iter(chunk_ranges(2019, 2019, months)))
        url = DAILY.format(ini=f"{ini}T00:00:00UTC", fin=f"{fin}T23:59:59UTC", idema=working[0])
        data, note = probe_request(url, key)
        n = len(data) if data else 0
        verdict = "OK" if n > months * 30 * 0.5 else "TRUNCATED or empty"
        print(f"   {months:2d} month(s) ({ini}..{fin}): {n:4d} records -> {verdict}   [{note}]")

    print(f"\n4. do the recent years exist? (station {working[0]}, first half of each year)")
    for y in (2020, 2022, 2024, 2025):
        url = DAILY.format(ini=f"{y}-01-01T00:00:00UTC", fin=f"{y}-06-30T23:59:59UTC", idema=working[0])
        data, note = probe_request(url, key)
        print(f"   {y}: {len(data) if data else 0:4d} records   [{note}]")

    print(f"\n5. sizing, at 6 months per request and {RATE_PER_MIN:.0f} keyed calls/min")
    n_st = len(hits)
    for y0, y1, label in ((1995, 2025, "full 1995-2025"), (2016, 2025, "2016-2025"), (2021, 2025, "2021-2025 only")):
        reqs = sum(1 for _ in chunk_ranges(y0, y1, 6))
        print(f"   {label:20s}: {reqs:3d} requests x {n_st} stations = {n_st*reqs:6d} calls -> "
              f"~{n_st * reqs / RATE_PER_MIN / 60:.1f} h")


def read_stations(path):
    with open(path, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.startswith("#")]


def cmd_census(args, key):
    """How many of our stations still report recently, and which ones.

    A station present in the archive (which ends in 2020) may have closed since: the probe found
    Vandellòs delivering 181 days in 2019, 21 in 2020 and nothing from 2022 on. One request per
    station settles whether the full download is worth its hours, and writes the filtered list the
    download should actually use, so no time is spent on stations that will return nothing.
    """
    stations = read_stations(args.stations)
    inv = fetch(INVENTORY, key)
    ids = {str(s.get("indicativo", "")).strip() for s in inv} if inv else set()
    cand = [s for s in stations if s in ids] if ids else stations
    y = args.census_year
    print(f"census: {len(cand)} stations, one request each for the first half of {y}")
    print(f"       ~{len(cand)/RATE_PER_MIN:.0f} min\n", flush=True)
    alive, t0 = [], time.time()
    for i, sid in enumerate(cand, 1):
        url = DAILY.format(ini=f"{y}-01-01T00:00:00UTC", fin=f"{y}-06-30T23:59:59UTC", idema=sid)
        try:
            data = fetch(url, key)
        except Exception:                                          # noqa: BLE001 - a station is not worth aborting for
            data = None
        if data:
            alive.append(sid)
        if i % 50 == 0 or i == len(cand):
            el = (time.time() - t0) / 60
            print(f"  {i}/{len(cand)}  con datos: {len(alive)}  "
                  f"({el:.1f} min, ~{el/i*(len(cand)-i):.0f} min restantes)", flush=True)
    with open(args.census_out, "w", encoding="utf-8") as f:
        f.write("\n".join(alive) + "\n")
    pct = 100 * len(alive) / len(cand) if cand else 0
    print(f"\n{len(alive)} of {len(cand)} stations have data in {y} ({pct:.1f}%)")
    print(f"list written to {args.census_out}")
    if alive:
        reqs = sum(1 for _ in chunk_ranges(1995, 2025, 6))
        print(f"descarga completa 1995-2025 sobre esas {len(alive)}: "
              f"{reqs*len(alive)} llamadas -> ~{reqs*len(alive)/RATE_PER_MIN/60:.1f} h")


def range_guard(outdir, y0, y1):
    """Refuse to resume a directory that was filled with a different period.

    The per-station file name carries no year range, so resuming with a different --from/--to would
    find those files, skip them, and ship a series covering the earlier and shorter span while
    reporting success. Same failure shape as a checkpoint that ignores which window produced it."""
    os.makedirs(outdir, exist_ok=True)
    marker = os.path.join(outdir, "_range.json")
    want = {"from": y0, "to": y1}
    if os.path.exists(marker):
        with open(marker, encoding="utf-8") as f:
            have = json.load(f)
        if have != want:
            sys.exit(f"{outdir} already holds {have['from']}-{have['to']} but {y0}-{y1} was requested.\n"
                     f"Point --out at a different directory, or remove that one to start over.")
    else:
        with open(marker, "w", encoding="utf-8") as f:
            json.dump(want, f)


def cmd_download(args, key):
    stations = read_stations(args.stations)
    range_guard(args.out, args.from_year, args.to_year)
    todo = [s for s in stations if not os.path.exists(os.path.join(args.out, f"{s}.csv"))]
    print(f"{len(stations)} stations, {len(stations)-len(todo)} already on disk, {len(todo)} to go", flush=True)
    t0 = time.time()
    counter = {"done": 0, "empty": 0}
    progress_lock = threading.Lock()

    def one(idema):
        """Fetch and store one station. Each worker owns its own file, so nothing is shared."""
        try:
            rows = station_rows(idema, args.from_year, args.to_year, args.chunk_months, key)
        except Exception as e:                                    # noqa: BLE001 - never lose the run to one station
            print(f"  [{idema}] ERROR {type(e).__name__}: {e}", flush=True)
            return
        # write to a temp name and rename, so a kill mid-write cannot leave a partial file that the
        # resume would accept as complete. An empty file is the marker for "asked, nothing there".
        tmp = os.path.join(args.out, f"{idema}.csv.tmp")
        with open(tmp, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["fecha", "tmax", "tmin"])
            w.writerows(rows)
        os.replace(tmp, os.path.join(args.out, f"{idema}.csv"))
        with progress_lock:
            counter["done"] += 1
            if not rows:
                counter["empty"] += 1
            i = counter["done"]
            if i % 25 == 0 or i == len(todo):
                el = (time.time() - t0) / 60
                print(f"  {i}/{len(todo)} stations, {el:.1f} min elapsed, "
                      f"~{el/i*(len(todo)-i):.0f} min left, {counter['empty']} empty", flush=True)

    if args.workers > 1:
        # Requests are latency bound, not rate bound: the census managed 21/min against a 40/min
        # ceiling because the two calls of each request run back to back. Overlapping stations puts
        # the shared throttle back in charge and roughly halves the wall clock.
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            list(ex.map(one, todo))
    else:
        for idema in todo:
            one(idema)
    print(f"done: {counter['done']} processed, {counter['empty']} with no data, "
          f"{(time.time()-t0)/60:.1f} min", flush=True)


def cmd_merge(args):
    """Single tidy table, in the Year/Month/Day/Tmax/Tmin shape the chill scripts already read."""
    files = sorted(f for f in os.listdir(args.out) if f.endswith(".csv"))
    n = 0
    with open(args.csv, "w", newline="", encoding="utf-8") as fo:
        w = csv.writer(fo)
        w.writerow(["station_id", "Year", "Month", "Day", "Tmax", "Tmin"])
        for fn in files:
            sid = fn[:-4]
            with open(os.path.join(args.out, fn), encoding="utf-8") as fi:
                for rec in csv.DictReader(fi):
                    try:
                        d = datetime.strptime(rec["fecha"][:10], "%Y-%m-%d")
                    except ValueError:
                        continue
                    w.writerow([sid, d.year, d.month, d.day, rec["tmax"], rec["tmin"]])
                    n += 1
    print(f"wrote {args.csv}: {n} rows from {len(files)} stations")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--probe", action="store_true", help="measure inventory match and max span, download nothing")
    p.add_argument("--merge", action="store_true", help="join the per-station files into one table")
    p.add_argument("--census", action="store_true",
                   help="one request per station for a recent year: how many still report, and which")
    p.add_argument("--census-year", dest="census_year", type=int, default=2024)
    p.add_argument("--census-out", dest="census_out", default="stations_recent.txt")
    p.add_argument("--probe-stations", dest="probe_stations",
                   help="comma separated station ids to probe instead of the first matches")
    p.add_argument("--workers", type=int, default=1,
                   help="stations fetched concurrently; the keyed-call rate stays capped globally")
    p.add_argument("--stations", help="text file with one station id per line")
    p.add_argument("--out", default="obs_api", help="directory of per-station csv files")
    p.add_argument("--csv", default="observed_api.csv", help="merged output")
    p.add_argument("--from", dest="from_year", type=int, default=1995)
    p.add_argument("--to", dest="to_year", type=int, default=2025)
    p.add_argument("--chunk-months", dest="chunk_months", type=int, default=6,
                   help="months per request; AEMET refuses more than 6")
    args = p.parse_args()

    if args.merge:
        return cmd_merge(args)
    key = api_key()
    if args.probe:
        return cmd_probe(args, key)
    if args.census:
        if not args.stations:
            sys.exit("--stations is required for the census")
        return cmd_census(args, key)
    if not args.stations:
        sys.exit("--stations is required to download")
    cmd_download(args, key)


if __name__ == "__main__":
    main()
