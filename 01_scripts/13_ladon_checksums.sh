#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------
# Freeze the version of the input data by checksumming every NetCDF on Ladon, so that a rerun
# years from now can prove it read the same bytes. The AdapteCCa THREDDS server publishes no
# version tag and no checksum of its own, and the files can be revised in place, which is the gap
# this closes.
#
# Writes a manifest of one line per file, sorted by name so two runs are diffable, and prints a
# single checksum of that manifest: one string that identifies the whole 88-file set. Put that
# string in the methods section and any later run can be compared against it with one command.
#
# Reads only in the sense that matters: the NetCDF are never modified, moved or opened for
# writing. The manifest itself does land next to them by default, so the record travels with the
# data it describes; pass a second argument to put it somewhere else.
#
# Usage (Ladon):
#   nohup bash 13_ladon_checksums.sh > checksums.log 2>&1 &
#   tail -f checksums.log
#
# It takes a while: md5sum reads all 15 GB. Expect the order of ten minutes on a warm cache and
# considerably more on a cold one.
# ---------------------------------------------------------------------------------------
set -u

DATA="${1:-/data/training2/egu_agroclimatico}"
OUT="${2:-${DATA}/netcdf_md5.txt}"

if [ ! -d "$DATA" ]; then
  echo "no such directory: $DATA"
  echo "pass the data directory as the first argument if it moved"
  exit 1
fi

echo "hashing the NetCDF under $DATA"
echo "manifest -> $OUT"
echo

# -print0/-0 so a path with a space cannot split a line, and LC_ALL=C so the sort order is the
# same on any machine that repeats this.
find "$DATA" -type f -name '*.nc' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 -n 1 md5sum \
  > "$OUT"

n=$(wc -l < "$OUT")
bytes=$(find "$DATA" -type f -name '*.nc' -printf '%s\n' | awk '{s+=$1} END {print s}')
manifest=$(md5sum "$OUT" | cut -d' ' -f1)

echo "files hashed : $n"
echo "total bytes  : $bytes"
echo "manifest md5 : $manifest"
echo

# The 88 belong to the projections set (11 models x 4 experiments x 2 variables), so the check
# only fires when those files are in the manifest. Hashing the observed archive on its own, or
# the whole data root at once, is legitimate and must not raise a false alarm.
n_proj=$(grep -c 'ESD-RegBA_day\.nc$' "$OUT" || true)
if [ "$n_proj" -gt 0 ]; then
  echo "projections   : $n_proj of the 88 expected (11 models x 4 experiments x 2 variables)"
  if [ "$n_proj" -ne 88 ]; then
    echo "WARNING: that is not 88. Check the download before quoting this manifest anywhere."
  fi
fi
echo

# md5sum -c resolves the manifest paths against the current directory, and they are relative
# whenever the data directory was given as a relative path, so the hint carries the directory.
echo "to compare a later run against this one:"
echo "  cd $(pwd) && md5sum -c \"$OUT\""
