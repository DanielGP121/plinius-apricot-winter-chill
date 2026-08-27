# External data

Nothing in this folder is versioned except this file and `stations_obs.txt`. The inputs weigh
several gigabytes and belong to third parties, so the repository holds the code that consumes them
and this page explains how to get each one, including who owns it.

Point `PLINIUS_DATA` at wherever you put them:

```bash
export PLINIUS_DATA=/path/to/plinius_data
```

Every R script resolves paths through `01_scripts/00_paths.R`, which aborts on the first line with
instructions if that variable is missing, rather than failing later inside a raster call.

## Expected layout

```
$PLINIUS_DATA/
├── proyecciones_peninsula/       88 NetCDF, ~15 GB   PNACC AR6 projections (script 10 downloads them)
├── observado/                    2 NetCDF            PNACC observational archive 1975-2020
├── corine/                       ~1 GB unzipped      CORINE Land Cover 2018, 100 m raster
├── cieza_cebas/                  19 MB               Cieza11-25.xlsx, CEBAS orchard series
└── tables/                                          only for the Murcia test-run (scripts 62-68)
    ├── murcia/stations.csv
    └── peninsula/stations.csv
```

## How to obtain each one

### PNACC AR6 projections (required for the national analysis)

Public, no credentials. `01_scripts/10_ladon_download_thredds.sh` fetches all 88 files from the
AdapteCCa THREDDS server. It takes hours and 15 GB, so run it where the computation will happen:

```bash
bash 10_ladon_download_thredds.sh /path/to/proyecciones_peninsula
```

**Use this route, not the portal's download form.** They serve the same product over different
station sets, 3460 through THREDDS and 3044 through the form, so results from the two do not
reconcile. This is measured and explained in `info/`.

### PNACC observational archive 1975-2020 (required for the observed record)

Not an open download. Request it through the scenario archive form at
`archivo-proyecciones-climaticas.aemet.es`, choosing the observed daily product for the
Peninsula and Balearics; it arrives by email as a zip. Place the two NetCDFs in `observado/` as
`tasmax_obs.nc` and `tasmin_obs.nc`.

### AEMET OpenData (required only to extend the record past 2020)

Free personal key from `opendata.aemet.es`, valid three months. Then:

```bash
export AEMET_API_KEY='your-key'
python3 01_scripts/11_aemet_observed_download.py --stations 00_data/stations_obs.txt \
        --out obs_api --from 1995 --to 2025 --chunk-months 6 --workers 4
python3 01_scripts/11_aemet_observed_download.py --merge --out obs_api --csv observed_1995_2025.csv
```

Expect roughly a day and a half: the API caps requests at six months each, so 31 years is 62 calls
per station across 666 stations, under a rate limit of about 50 calls a minute. The download
resumes, so an interrupted run can simply be relaunched.

Two things worth knowing before relying on it. Only 703 of the 3044 archive stations exist in
AEMET's climatological inventory and 666 still report, so this covers 22% of the network. And it is
thin going backwards: only 131 stations reach 1995, with 293 starting in 2008-2009.

### CORINE Land Cover 2018 (required for every surface figure)

Free after registration at the Copernicus Land Monitoring Service. Download the 100 m raster and
unzip it under `corine/`. `00_paths.R` finds the GeoTIFF by pattern, preferring the European raster
over the French overseas ones that ship in the same archive; `PLINIUS_CLC` overrides it.

### Cieza orchard series (required only for script 44)

Public, from the repository accompanying Muñoz-Morales et al. (2025), MethodsX 15:103686:

```bash
curl -L -o cieza_cebas/Cieza11-25.xlsx \
  https://raw.githubusercontent.com/CEBASFruitBreed/R-workflow-ChillPLS/main/data/Cieza11-25.xlsx
```

Cite that paper if you use it.

## DM_JOSE.R, which is not here either

The chill model itself is missing from the repository. It implements the Dynamic Model under the
Fishman et al. (1987) parametrisation, it was written by J. A. Egea, and this project has no
licence to redistribute it. Scripts 60, 20, 22, 44 and 70 need it and fail with instructions when
it is absent.

Two ways forward. Request the file from the authors and drop it in `01_scripts/`, or point
`PLINIUS_DM` at it. Or write the equivalent: it is chillR's `Dynamic_Model` with the constants from
the 1987 paper,

    E0 = 4457.8, E1 = 10161.9, A0 = 419700, A1 = 1.797e14, slope = 1.6, Tf = 277

**chillR's own defaults will not do.** Those are the 1988 parametrisation, and on the Cieza series
the two differ by 6.94 chill portions on average, which is half the gap between the two cultivars
this whole study is about. If you substitute one for the other, every number changes.
