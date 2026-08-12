# legacy

Code from a line of work the project turned away from. It is kept because it documents a decision,
not because anything downstream uses it. Nothing in `01_scripts/` imports from here.

## `build_aemet_matching.py`

The original Phase 1. Egea et al. (2022) mapped safe winter chill across Spain from 270 stations
run by the regional agrometeorological services, and the first plan was to reuse that network by
pairing each of those stations with its nearest AEMET counterpart.

Dropped after the meeting of 9 July 2026, for two reasons. The regional series arrived with chill
already computed and without the raw daily temperatures, so there was no way to recompute it under
the parametrisation this project needs. And AEMET's own network turned out to offer an order of
magnitude more stations with daily data. The pairing survives only as a possible cross-check
against the published 2022 maps, which has not been done.

Two caveats if you ever run it. Its inputs are spreadsheets of station coordinates compiled by the
regional services and passed on through a third party, with no terms of transfer, so neither they
nor its outputs are in this repository. And it fetches four URLs at runtime, two of them
third-party GitHub repositories with no guarantee of permanence; pin them to a commit or cache a
copy before depending on the result.
