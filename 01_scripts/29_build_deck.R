#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------------------
# Builds the project deck as a single self-contained HTML file.
#
# The narrative lives in deck_content.R and the figures in 02_outputs/figures_chill. This script
# only assembles: it embeds every figure as a data URI so the result can be emailed as one file,
# injects the data the interactive panels need, and writes the page.
#
# Figures are embedded rather than linked because a deck that breaks when it leaves the folder is
# not a deck. To keep the file sendable the heavy ones are halved and re-encoded as JPEG, while
# anything already small stays as the original lossless PNG: line charts lose more from a lossy
# pass than they gain, and the maps are where the megabytes actually are.
#
# Four interactive panels, chosen because each one answers a question that prose answers badly:
#   response   the chill response curve, because "colder is better" is the standard misconception
#   timeline   which source covers which years, and where the seams are
#   workflow   what feeds what across the 22 scripts and two machines
#   threshold  the cultivar requirements swept over their real uncertainty, in km2
#
# Usage:
#   Rscript 29_build_deck.R
#   Rscript 29_build_deck.R --out ../03_presentacion/deck.html --maxkb 120
#
# Requires: png, jpeg, base64enc, jsonlite, data.table, chillR (for the response curve).
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(png); library(jpeg); library(base64enc); library(jsonlite); library(data.table)
}))

args <- commandArgs(trailingOnly = TRUE)
# A flag given as the last argument used to yield NA instead of its value, which for --maxst
# turned an intended smoke test into the full run writing to production paths.
getarg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i)) return(default)
  if (i[1] >= length(args)) stop(sprintf("%s needs a value after it", flag), call. = FALSE)
  args[i[1] + 1]
}

# Paths come from 00_paths.R, which also exports SCRIPTS_DIR; the local .script_dir() this file
# used to carry was a second, subtly different copy of the same helper.
.f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
source(file.path(if (length(.f)) dirname(normalizePath(sub("^--file=", "", .f[1]))) else getwd(), "00_paths.R"))

FIGDIR <- FIG_DIR
OUTD   <- PRES_DIR
OUT    <- getarg("--out", file.path(OUTD, "deck.html"))
MAXKB  <- as.numeric(getarg("--maxkb", 120))   # below this, keep the original PNG untouched
JPEGQ  <- as.numeric(getarg("--quality", 0.90))

SD <- SCRIPTS_DIR
source(file.path(SD, "deck_content.R"))
dir.create(OUTD, showWarnings = FALSE, recursive = TRUE)

# --- § 1 - figure embedding ------------------------------------------------------------------
# Block-mean downscaling rather than dropping every other pixel: averaging keeps axis labels and
# tick text legible at half size, decimation turns them into noise.
shrink2 <- function(a) {
  h <- dim(a)[1]; w <- dim(a)[2]; nh <- floor(h / 2); nw <- floor(w / 2)
  out <- array(0, c(nh, nw, dim(a)[3]))
  for (ch in seq_len(dim(a)[3])) {
    m <- a[1:(nh * 2), 1:(nw * 2), ch]; dim(m) <- c(2, nh, 2, nw)
    out[, , ch] <- apply(m, c(2, 4), mean)
  }
  out
}

emb_cache <- new.env(parent = emptyenv())
embed_fig <- function(name) {
  if (!is.null(emb_cache[[name]])) return(emb_cache[[name]])
  p <- file.path(FIGDIR, paste0(name, ".png"))
  if (!file.exists(p)) { warning(sprintf("figure %s is missing", name)); return(NULL) }
  sz <- file.size(p)
  uri <- if (sz <= MAXKB * 1024) {
    paste0("data:image/png;base64,", base64encode(p))
  } else {
    a <- readPNG(p)
    if (length(dim(a)) == 3 && dim(a)[3] == 4) a <- a[, , 1:3, drop = FALSE]
    if (length(dim(a)) == 2) a <- array(a, c(dim(a), 1))[, , c(1, 1, 1), drop = FALSE]
    tmp <- tempfile(fileext = ".jpg"); writeJPEG(shrink2(a), tmp, quality = JPEGQ)
    on.exit(unlink(tmp), add = TRUE)
    paste0("data:image/jpeg;base64,", base64encode(tmp))
  }
  assign(name, uri, envir = emb_cache)
  uri
}

# --- § 2 - data for the interactive panels ----------------------------------------------------
cat("1. panel data\n")

# response curve: run the project's own model over a temperature range, so the panel cannot drift
# from what the pipeline actually computes
source_dm_jose()
temps <- seq(-12, 22, by = 0.5)
cpday <- vapply(temps, function(tt) tail(DM_JOSE(rep(tt, 24 * 120)), 1) / 120, 0)
resp <- list(t = temps, cp = round(cpday, 4))

# threshold sweep, from script 28
SWEEP <- file.path(ROOT, "02_outputs", "cropland_threshold_sweep.csv")
META  <- file.path(ROOT, "02_outputs", "cropland_threshold_meta.csv")
if (!file.exists(SWEEP)) stop("cropland_threshold_sweep.csv is missing; run script 28 first")
sw <- fread(SWEEP)
meta <- fread(META)
total_km2 <- meta[metric == "total_cropland_km2"]$value
SITLAB <- c(observaciones_present = "Observado 1995-2020",
            observaciones_obsref  = "Observado 1991-2020",
            presente_present      = "Modelo, línea base 1995-2020",
            presente_current      = "Modelo, clima actual 1995-2025",
            historical_ref        = "Modelo, histórico 1985-2014",
            pooled_nearterm       = "2021-2040, escenarios agregados",
            ssp126_near = "SSP1-2.6, 2041-2070", ssp245_near = "SSP2-4.5, 2041-2070",
            ssp370_near = "SSP3-7.0, 2041-2070", ssp126_far  = "SSP1-2.6, 2071-2100",
            ssp245_far  = "SSP2-4.5, 2071-2100", ssp370_far  = "SSP3-7.0, 2071-2100")
sits <- intersect(names(SITLAB), unique(sw$situation))
thr <- sort(unique(sw$threshold))
curves <- lapply(sits, function(s) {
  d <- sw[situation == s][match(thr, threshold)]
  round(d$km2_at_or_above, 1)
})
names(curves) <- sits
sweep_js <- list(thr = thr, total = round(total_km2, 1),
                 sits = sits, labs = unname(SITLAB[sits]), curves = curves)

# the published summary table, for the results slide
TALK <- file.path(ROOT, "02_outputs", "talk_numbers_cropland.csv")
viab <- if (file.exists(TALK)) fread(TALK) else NULL

# --- § 3 - html helpers -----------------------------------------------------------------------
esc <- function(x) { x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE)
                     gsub(">", "&gt;", x, fixed = TRUE) }
para <- function(v) paste(sprintf("<p>%s</p>", esc(v)), collapse = "\n")

fig_block <- function(names, caps = NULL, cls = "figs") {
  if (is.null(names) || !length(names)) return("")
  items <- vapply(seq_along(names), function(i) {
    uri <- embed_fig(names[i]); if (is.null(uri)) return("")
    cap <- if (!is.null(caps) && length(caps) >= i && nzchar(caps[i])) caps[i] else names[i]
    sprintf('<figure><img loading="lazy" src="%s" alt="%s"><figcaption>%s</figcaption></figure>',
            uri, esc(names[i]), esc(cap))
  }, "")
  sprintf('<div class="%s">%s</div>', cls, paste(items, collapse = "\n"))
}

viab_table <- function() {
  if (is.null(viab)) return("")
  v <- viab[, .(label, pct_both = round(pct_both, 1), pct_only_precoz = round(pct_only_precoz, 1),
                pct_none = round(pct_none, 1), swc = round(swc_median, 1))]
  rows <- paste(sprintf("<tr><td>%s</td><td>%.1f</td><td class='hl'>%.1f</td><td>%.1f</td><td>%.1f</td></tr>",
                        esc(v$label), v$pct_both, v$pct_only_precoz, v$pct_none, v$swc), collapse = "\n")
  paste0("<table class='tbl'><thead><tr><th>Situación</th><th>Ambas</th>",
         "<th>Solo 'Búlida Precoz'</th><th>Ninguna</th><th>SWC mediano</th></tr></thead><tbody>",
         rows, "</tbody></table><p class='small'>Porcentaje de los 229.604 km² de suelo cultivable. ",
         "Fuente: <code>talk_numbers_cropland.csv</code>.</p>")
}

# --- § 4 - assemble ----------------------------------------------------------------------------
cat("2. assembling blocks\n")
body <- character(0)
toc  <- character(0)
sec_n <- 0

for (b in DECK) {
  if (b$kind == "cover") {
    body <- c(body, sprintf('<header class="cover"><h1>%s</h1><p class="sub">%s</p><div class="meta">%s</div></header>',
                            esc(b$title), esc(b$subtitle),
                            paste(sprintf("<div>%s</div>", esc(b$meta)), collapse = "")))
  } else if (b$kind == "section") {
    sec_n <- sec_n + 1
    id <- sprintf("sec%s", b$n)
    toc <- c(toc, sprintf('<a href="#%s"><span class="num">%s</span>%s</a>', id, esc(b$n), esc(b$title)))
    body <- c(body, sprintf('<section class="divider" id="%s"><div class="dnum">%s</div><h2>%s</h2><p class="lead">%s</p></section>',
                            id, esc(b$n), esc(b$title), esc(b$lead)))
  } else if (b$kind == "slide") {
    tb <- if (!is.null(b$table) && b$table == "viability") viab_table() else ""
    nt <- if (!is.null(b$note)) sprintf('<aside class="note"><strong>Nota para la charla.</strong> %s</aside>', esc(b$note)) else ""
    body <- c(body, sprintf('<article class="slide"><h3>%s</h3>%s%s%s%s</article>',
                            esc(b$title), para(b$body), tb,
                            fig_block(b$figs, b$figcap), nt))
  } else if (b$kind == "gallery") {
    body <- c(body, sprintf('<article class="slide"><h3>%s</h3>%s%s</article>',
                            esc(b$title), para(b$body), fig_block(b$figs, NULL, "figs grid")))
  } else if (b$kind == "gadget") {
    nt <- if (!is.null(b$note)) sprintf('<aside class="note"><strong>Nota para la charla.</strong> %s</aside>', esc(b$note)) else ""
    body <- c(body, sprintf('<article class="slide"><h3>%s</h3>%s<div class="gadget" id="g-%s"></div>%s</article>',
                            esc(b$title), para(b$body), b$id, nt))
  }
}

css <- '
:root{--bg:#fbfbfa;--fg:#1d1d1f;--mut:#6b6b70;--acc:#0b6fa4;--acc2:#e6550d;--line:#e2e2df;--card:#fff;--warn:#fff8e6}
@media (prefers-color-scheme:dark){:root{--bg:#141416;--fg:#e9e9ea;--mut:#9a9aa0;--acc:#5aa9d6;--acc2:#f08a3c;--line:#2c2c30;--card:#1c1c1f;--warn:#2a2415}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:960px;margin:0 auto;padding:0 24px 120px}
.cover{padding:80px 0 48px;border-bottom:3px solid var(--fg)}
.cover h1{font-size:2.5rem;line-height:1.15;margin:0 0 16px;letter-spacing:-.02em}
.cover .sub{font-size:1.25rem;color:var(--mut);margin:0 0 32px}
.cover .meta div{color:var(--mut);font-size:.9rem}
nav.toc{margin:40px 0 0;padding:20px 0;border-bottom:1px solid var(--line)}
nav.toc a{display:block;color:var(--fg);text-decoration:none;padding:5px 0;font-size:.95rem}
nav.toc a:hover{color:var(--acc)}
nav.toc .num{display:inline-block;width:2.2em;color:var(--mut);font-variant-numeric:tabular-nums}
.divider{margin:88px 0 0;padding-top:24px;border-top:1px solid var(--line)}
.dnum{font-size:.8rem;letter-spacing:.16em;text-transform:uppercase;color:var(--acc2);font-weight:600}
.divider h2{font-size:1.9rem;margin:6px 0 12px;letter-spacing:-.015em}
.lead{font-size:1.1rem;color:var(--mut);max-width:62ch;margin:0}
.slide{margin:44px 0 0}
.slide h3{font-size:1.3rem;margin:0 0 14px;letter-spacing:-.01em}
.slide p{max-width:70ch}
.figs{margin:22px 0 0;display:flex;flex-direction:column;gap:22px}
.figs.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}
figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px;overflow:hidden}
figure img{width:100%;height:auto;display:block;border-radius:6px}
figcaption{font-size:.85rem;color:var(--mut);margin-top:8px}
.note{margin:20px 0 0;padding:12px 16px;background:var(--warn);border-left:3px solid var(--acc2);border-radius:0 6px 6px 0;font-size:.92rem}
.tbl{width:100%;border-collapse:collapse;margin:20px 0 8px;font-size:.9rem}
.tbl th,.tbl td{padding:7px 10px;text-align:right;border-bottom:1px solid var(--line)}
.tbl th:first-child,.tbl td:first-child{text-align:left}
.tbl thead th{border-bottom:2px solid var(--fg);font-size:.82rem}
.tbl .hl{color:var(--acc2);font-weight:600}
.small{font-size:.82rem;color:var(--mut)}
.gadget{margin:22px 0 0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:20px}
.ctl{display:flex;flex-wrap:wrap;gap:20px;align-items:center;margin-bottom:16px}
.ctl label{font-size:.85rem;color:var(--mut);display:block;margin-bottom:4px}
.ctl input[type=range]{width:210px;accent-color:var(--acc)}
.ctl select{padding:6px 8px;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--fg);font-size:.9rem}
.val{font-variant-numeric:tabular-nums;font-weight:600;color:var(--acc)}
.bar{display:flex;height:42px;border-radius:6px;overflow:hidden;margin:14px 0 6px;font-size:.8rem}
.bar div{display:flex;align-items:center;justify-content:center;color:#fff;font-weight:600;white-space:nowrap;transition:width .18s}
.legend{display:flex;gap:18px;flex-wrap:wrap;font-size:.85rem;color:var(--mut)}
.legend i{display:inline-block;width:11px;height:11px;border-radius:2px;margin-right:5px}
.kpi{display:flex;gap:26px;flex-wrap:wrap;margin-top:14px}
.kpi div{font-size:.85rem;color:var(--mut)}
.kpi b{display:block;font-size:1.35rem;color:var(--fg);font-variant-numeric:tabular-nums}
.tl{width:100%;height:auto}
.wf{display:grid;grid-template-columns:1fr 1fr;gap:18px}
@media(max-width:700px){.wf{grid-template-columns:1fr}}
.wfcol h4{margin:0 0 10px;font-size:.8rem;letter-spacing:.12em;text-transform:uppercase;color:var(--acc2)}
.wfc{background:var(--bg);border:1px solid var(--line);border-left:3px solid var(--acc);border-radius:0 6px 6px 0;padding:9px 12px;margin-bottom:8px;font-size:.87rem}
.wfc b{display:block;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.83rem}
.wfc span{color:var(--mut)}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.88em;background:var(--line);padding:1px 5px;border-radius:4px}
footer{margin:90px 0 0;padding-top:20px;border-top:1px solid var(--line);color:var(--mut);font-size:.85rem}
'

# Raw string: the panel code carries both quote characters (cultivar names in single quotes, HTML
# attributes in double), so any ordinary R literal would need escaping that hides real syntax errors.
js_tpl <- r"---(
const RESP = __RESP_JSON__;
const SWEEP = __SWEEP_JSON__;
const fmt = n => n.toLocaleString("es-ES",{maximumFractionDigits:0});

/* ---- response curve ---------------------------------------------------------------- */
(function(){
  const el = document.getElementById("g-response"); if(!el) return;
  const W=680,H=260,P={l:52,r:14,t:14,b:34};
  const xs=t=>P.l+(t-RESP.t[0])/(RESP.t[RESP.t.length-1]-RESP.t[0])*(W-P.l-P.r);
  const mx=Math.max(...RESP.cp), ys=v=>H-P.b-v/mx*(H-P.t-P.b);
  const d=RESP.t.map((t,i)=>(i?"L":"M")+xs(t).toFixed(1)+" "+ys(RESP.cp[i]).toFixed(1)).join(" ");
  const ticks=[-10,-5,0,5,10,15,20].map(t=>`<text x="${xs(t)}" y="${H-12}" text-anchor="middle" class="ax">${t}</text>`).join("");
  el.innerHTML=`<div class="ctl"><div><label>Temperatura constante</label>
     <input type="range" id="rt" min="${RESP.t[0]}" max="${RESP.t[RESP.t.length-1]}" step="0.5" value="8">
     <span class="val" id="rtv">8,0 °C</span></div></div>
   <svg viewBox="0 0 ${W} ${H}" class="tl" role="img">
     <style>.ax{font-size:11px;fill:var(--mut)}</style>
     <line x1="${P.l}" y1="${H-P.b}" x2="${W-P.r}" y2="${H-P.b}" stroke="var(--line)"/>
     <line x1="${P.l}" y1="${P.t}" x2="${P.l}" y2="${H-P.b}" stroke="var(--line)"/>
     <path d="${d}" fill="none" stroke="var(--acc)" stroke-width="2.2"/>
     <line id="rl" x1="0" y1="${P.t}" x2="0" y2="${H-P.b}" stroke="var(--acc2)" stroke-width="1.5" stroke-dasharray="4 3"/>
     <circle id="rc" r="5" fill="var(--acc2)"/>
     ${ticks}<text x="${W/2}" y="${H-1}" text-anchor="middle" class="ax">Temperatura (°C)</text>
     <text x="12" y="${(H-P.b)/2}" text-anchor="middle" class="ax" transform="rotate(-90 12 ${(H-P.b)/2})">Porciones de frío por día</text>
   </svg>
   <div class="kpi"><div><b id="rv">0,79</b>porciones de frío por día</div>
   <div><b id="rp">100%</b>del óptimo, que está en 8 °C</div></div>`;
  const r=el.querySelector("#rt");
  function upd(){const t=parseFloat(r.value);
    let i=RESP.t.findIndex(x=>x>=t); if(i<0)i=RESP.t.length-1;
    const v=RESP.cp[i];
    el.querySelector("#rtv").textContent=t.toFixed(1).replace(".",",")+" °C";
    el.querySelector("#rv").textContent=v.toFixed(3).replace(".",",");
    el.querySelector("#rp").textContent=Math.round(v/mx*100)+"%";
    const X=xs(t),Y=ys(v);
    el.querySelector("#rl").setAttribute("x1",X);el.querySelector("#rl").setAttribute("x2",X);
    el.querySelector("#rc").setAttribute("cx",X);el.querySelector("#rc").setAttribute("cy",Y);}
  r.addEventListener("input",upd);upd();
})();

/* ---- threshold explorer ------------------------------------------------------------ */
(function(){
  const el=document.getElementById("g-threshold"); if(!el) return;
  const opts=SWEEP.sits.map((s,i)=>`<option value="${i}"${s==="ssp370_far"?" selected":""}>${SWEEP.labs[i]}</option>`).join("");
  el.innerHTML=`<div class="ctl">
    <div><label>Situación</label><select id="ts">${opts}</select></div>
    <div><label>Requerimiento de 'Búlida' <span class="val" id="tbv">47,5</span></label>
      <input type="range" id="tb" min="${SWEEP.thr[0]}" max="${SWEEP.thr[SWEEP.thr.length-1]}" step="0.1" value="47.5"></div>
    <div><label>Requerimiento de 'Búlida Precoz' <span class="val" id="tpv">33,7</span></label>
      <input type="range" id="tp" min="${SWEEP.thr[0]}" max="${SWEEP.thr[SWEEP.thr.length-1]}" step="0.1" value="33.7"></div>
  </div>
  <div class="bar"><div id="b1" style="background:#2c7bb6"></div><div id="b2" style="background:#fdae61;color:#3b2200"></div><div id="b3" style="background:#d7191c"></div></div>
  <div class="legend"><span><i style="background:#2c7bb6"></i>Ambas variedades</span>
    <span><i style="background:#fdae61"></i>Solo 'Búlida Precoz'</span>
    <span><i style="background:#d7191c"></i>Ninguna</span></div>
  <div class="kpi"><div><b id="k1">-</b>km² para las dos</div><div><b id="k2">-</b>km² que rescata el mutante</div>
    <div><b id="k3">-</b>km² perdidos del todo</div><div><b id="k4">-</b>de la pérdida, rescatada</div></div>
  <p class="small" id="tnote"></p>`;
  const F=(c,x)=>{let lo=0,hi=SWEEP.thr.length-1;
    if(x<=SWEEP.thr[0])return c[0]; if(x>=SWEEP.thr[hi])return c[hi];
    while(hi-lo>1){const m=(lo+hi)>>1; if(SWEEP.thr[m]<=x)lo=m;else hi=m;}
    const w=(x-SWEEP.thr[lo])/(SWEEP.thr[hi]-SWEEP.thr[lo]); return c[lo]+w*(c[hi]-c[lo]);};
  const S=el.querySelector("#ts"),B=el.querySelector("#tb"),P=el.querySelector("#tp");
  function upd(){
    let cb=parseFloat(B.value),cp=parseFloat(P.value);
    if(cp>cb){cp=cb;P.value=cp;}                      /* the mutant cannot need more chill */
    const c=SWEEP.curves[SWEEP.sits[+S.value]];
    const both=F(c,cb),vp=F(c,cp),only=vp-both,none=SWEEP.total-vp,lost=SWEEP.total-both;
    el.querySelector("#tbv").textContent=cb.toFixed(1).replace(".",",");
    el.querySelector("#tpv").textContent=cp.toFixed(1).replace(".",",");
    const p=v=>Math.max(0,v)/SWEEP.total*100;
    const set=(id,v,txt)=>{const e=el.querySelector(id);e.style.width=p(v)+"%";e.textContent=p(v)>7?txt:"";};
    set("#b1",both,p(both).toFixed(1)+"%");set("#b2",only,p(only).toFixed(1)+"%");set("#b3",none,p(none).toFixed(1)+"%");
    el.querySelector("#k1").textContent=fmt(both);el.querySelector("#k2").textContent=fmt(only);
    el.querySelector("#k3").textContent=fmt(none);
    el.querySelector("#k4").textContent=lost>0?Math.round(only/lost*100)+"%":"-";
    el.querySelector("#tnote").textContent=
      "Umbrales oficiales: 47,5 y 33,7 (Ruiz et al. 2019, error estándar 3,3). El desfase entre parametrizaciones del modelo dinámico medido en Cieza es de 6,94 porciones: prueba a subir los dos deslizadores esa cantidad. Superficie cultivable total: "+fmt(SWEEP.total)+" km².";
  }
  [S,B,P].forEach(e=>e.addEventListener("input",upd));upd();
})();

/* ---- timeline ---------------------------------------------------------------------- */
(function(){
  const el=document.getElementById("g-timeline"); if(!el) return;
  const y0=1975,y1=2100,W=880,rowH=26,P={l:190,r:20,t:26,b:26};
  const rows=[
    {n:"Observado, archivo PNACC",a:1975,b:2020,c:"#2c7bb6",s:"3044 estaciones"},
    {n:"Observado, API AEMET",a:1995,b:2025,c:"#5aa9d6",s:"666 estaciones, ralo antes de 2008"},
    {n:"CMIP6 histórico",a:1950,b:2014,c:"#7f7f7f",s:"11 modelos"},
    {n:"CMIP6 escenarios SSP",a:2015,b:2100,c:"#9e9e9e",s:"3 escenarios x 11 modelos"},
    {n:"Línea base 1995-2020",a:1995,b:2020,c:"#e6550d",s:"empalmada, 26 temporadas",w:1},
    {n:"Próximo plazo 2021-2040",a:2021,b:2040,c:"#e6550d",s:"AR6 near-term, 20 temporadas",w:1},
    {n:"Medio siglo 2041-2070",a:2041,b:2070,c:"#e6550d",s:"30 temporadas",w:1},
    {n:"Fin de siglo 2071-2100",a:2071,b:2100,c:"#e6550d",s:"30 temporadas",w:1}
  ];
  const H=P.t+P.b+rows.length*rowH+16;
  const xs=y=>P.l+(y-y0)/(y1-y0)*(W-P.l-P.r);
  let g="";
  rows.forEach((r,i)=>{const y=P.t+i*rowH;
    g+=`<text x="${P.l-10}" y="${y+13}" text-anchor="end" class="tn">${r.n}</text>`;
    g+=`<rect x="${xs(Math.max(r.a,y0))}" y="${y+3}" width="${xs(r.b)-xs(Math.max(r.a,y0))}" height="${r.w?15:13}" rx="3" fill="${r.c}" opacity="${r.w?.92:.72}"/>`;
    g+=`<text x="${xs(r.b)+6}" y="${y+13}" class="ts">${r.s}</text>`;});
  [1980,2000,2014,2020,2040,2060,2080,2100].forEach(y=>{
    g+=`<line x1="${xs(y)}" y1="${P.t-6}" x2="${xs(y)}" y2="${H-P.b}" stroke="var(--line)"/>`;
    g+=`<text x="${xs(y)}" y="${H-10}" text-anchor="middle" class="ts">${y}</text>`;});
  g+=`<line x1="${xs(2014.5)}" y1="${P.t-6}" x2="${xs(2014.5)}" y2="${H-P.b}" stroke="var(--acc2)" stroke-width="1.6" stroke-dasharray="4 3"/>`;
  g+=`<text x="${xs(2014.5)}" y="${P.t-12}" text-anchor="middle" class="ts" fill="var(--acc2)">costura histórico / SSP</text>`;
  el.innerHTML=`<svg viewBox="0 0 ${W} ${H}" class="tl" role="img">
    <style>.tn{font-size:11.5px;fill:var(--fg)}.ts{font-size:10.5px;fill:var(--mut)}</style>${g}</svg>
    <p class="small">Las cuatro barras naranjas teselan 1995-2100 sin huecos ni solapes. El hueco 2015-2040 que dejaba el plan original está cubierto por la segunda.</p>`;
})();

/* ---- workflow ---------------------------------------------------------------------- */
(function(){
  const el=document.getElementById("g-workflow"); if(!el) return;
  const L=[["14_ladon_download_thredds.sh","88 NetCDF desde THREDDS, ~15 GB"],
           ["15_chill_national_parallel.R","motor nacional de frío; modos de ventana, empalme, checkpoints"],
           ["21_aemet_observed_download.py","observado reciente por API, 666 estaciones"]];
  const Lo=[["22_merge_chill_tables.R","fusiona las corridas en chill_all_windows.csv"],
            ["19_cropland_viability_national.R","IDW + CORINE + clasificación → fig20-22"],
            ["28_threshold_sweep_cropland.R","barrido de umbrales sobre las mismas superficies"],
            ["23_chill_from_api.R","frío por temporada desde los CSV de la API"],
            ["24_observed_api_vs_archive.R","contraste pareado entre fuentes → fig23"],
            ["25_splice_observed_1995_2025.R","empalme archivo + API → fig24"],
            ["26_observed_long_record.R","registro 1976-2025, tendencia y bloques → fig25"],
            ["27_cieza_independent_check.R","comprobación fuera de AEMET → fig26"],
            ["29_build_deck.R","este documento"]];
  const card=a=>`<div class="wfc"><b>${a[0]}</b><span>${a[1]}</span></div>`;
  el.innerHTML=`<div class="wf">
    <div class="wfcol"><h4>HPC Ladon</h4>${L.map(card).join("")}</div>
    <div class="wfcol"><h4>Local</h4>${Lo.map(card).join("")}</div></div>
    <p class="small">Los outputs pesados no bajan a local. Lo que viaja son tablas de frío por estación, que pesan megabytes en vez de gigabytes.</p>`;
})();
)---"
# Token substitution rather than sprintf: the panel code is well past sprintf's 8192-character
# format limit, and a fixed sub also avoids every percent sign in the CSS and the labels becoming
# a format specifier.
js <- sub("__RESP_JSON__", toJSON(resp, digits = 6, auto_unbox = TRUE), js_tpl, fixed = TRUE)
js <- sub("__SWEEP_JSON__", toJSON(sweep_js, digits = 6, auto_unbox = TRUE), js, fixed = TRUE)

html <- paste0(
  '<!doctype html><html lang="es"><head><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<title>Búlida Precoz y el frío invernal · documento de trabajo</title>',
  '<style>', css, '</style></head><body><div class="wrap">',
  body[1],
  '<nav class="toc">', paste(toc, collapse = ""), '</nav>',
  paste(body[-1], collapse = "\n"),
  '<footer>Documento de trabajo generado por <code>29_build_deck.R</code> el ',
  format(Sys.Date(), "%d/%m/%Y"),
  '. Todas las cifras proceden de las tablas de <code>02_outputs/</code>. ',
  'Las figuras están en inglés porque van a la charla; el texto está en español porque es material interno.</footer>',
  '</div><script>', js, '</script></body></html>')

writeLines(html, OUT, useBytes = TRUE)

# The PowerPoint build reads this rather than parsing the R source, so both decks come from one
# narrative. Exported on every run: a JSON that lags behind deck_content.R is worse than none,
# because the two decks would then disagree without anyone noticing.
json_out <- file.path(OUTD, "deck_content.json")
writeLines(toJSON(list(deck = DECK, viability = viab, sweep = sweep_js, response = resp),
                  auto_unbox = TRUE, digits = 6, null = "null"), json_out, useBytes = TRUE)
cat(sprintf("   content exported to %s\n", basename(json_out)))
cat(sprintf("\n3. wrote %s\n   %.1f MB, %d figures embedded, %d blocks\n",
            OUT, file.size(OUT) / 1048576, length(ls(emb_cache)), length(DECK)))
