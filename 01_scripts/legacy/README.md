# legacy

Code from a line of work the project turned away from. It is kept because it documents a decision,
and because one of its outputs is still in use: the AEMET station list it caches,
`02_outputs/tables/aemet_station_inventory_public.csv`, is where `40_idw_crossval.R` gets station
elevation. No script in `01_scripts/` imports code from here.

## `build_aemet_matching.py`

This was the project's original first stage. Egea et al. (2022) mapped Safe Winter Chill across
Spain from 270 stations run by the regional agrometeorological services, and the first plan was to
reuse that network by pairing each of those stations with its nearest AEMET counterpart.

Dropped after the meeting of 9 July 2026, for two reasons. The regional series arrived with chill
already computed and without the raw daily temperatures, so there was no way to recompute it under
the parametrisation this project needs. And AEMET's own network turned out to offer an order of
magnitude more stations with daily data. The pairing survives only as a possible cross-check
against the published 2022 maps, which has not been done.

Two caveats if you ever run it. Its inputs are two spreadsheets compiled by the regional services
and passed on through a third party, one of station coordinates and one of administrative metadata
and chill-start dates, with no terms of transfer, so they are not in this repository. Neither is
any output derived from them, with the single exception of the cached AEMET station list, published
because `40_idw_crossval.R` reads it. And it carries four hard-coded URLs, of which any one run
fetches at most three: the AEMET API and its public mirror are alternatives, picked by whether
`AEMET_API_KEY` is set. Two of them are third-party GitHub repositories with no guarantee of
permanence; pin them to a commit or cache a copy before depending on the result.
