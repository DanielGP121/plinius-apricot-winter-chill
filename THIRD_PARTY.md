# Third-party data and code

None of this is redistributed here. The repository holds the code that consumes it, and
[`00_data/README.md`](00_data/README.md) explains how to obtain each piece. This file records who
owns what and how it should be credited, which several of these licences require.

## Data

**PNACC AR6 climate projections, regionalised to stations (ESD-RegBA)**
AEMET and the Spanish Ministry for the Ecological Transition, distributed through the AdapteCCa
scenario viewer (`escenarios.adaptecca.es`). Free reuse with attribution. Producers of the station
files: IFCA and Predictia. Version 2.0 of the product; the daily station files carry
`date_created` 2026-02-20.

Note for anyone reproducing the figures: the portal serves this product by two routes that do not
carry the same station census. The THREDDS server used here (group `SP-005`) returns 3460 stations
and the interactive download form returns 3044. Numbers computed from the two are not directly
comparable.

**PNACC observational archive, daily station data 1975-2020**
AEMET. Delivered by email in response to a request through the scenario archive form, not by open
download. The terms of that delivery are not published, so no derivative of it is redistributed
here either.

**AEMET OpenData**
AEMET. Requires a personal API key, free on request at `opendata.aemet.es`. The key expires every
three months. Reuse is governed by AEMET's own terms; the raw download is not republished here.

**CORINE Land Cover 2018, 100 m raster**
European Union, Copernicus Land Monitoring Service, European Environment Agency. Free access after
registration, with attribution required.

**Daily temperature at the CEBAS experimental orchard, Cieza (Murcia), 2011-2025**
Published in the repository accompanying: Muñoz-Morales AM, Ortuño-Hernández G, Salazar JA,
Martínez-Gómez P, Egea JA, Ruiz D, Delgado A (2025). *R-based workflow to estimate chilling
requirements in multiple fruit tree genotypes using Partial Least Squares regression: Prunus
armeniaca L. case.* MethodsX 15:103686. DOI [10.1016/j.mex.2025.103686](https://doi.org/10.1016/j.mex.2025.103686).
Code and data at `github.com/CEBASFruitBreed/R-workflow-ChillPLS`. Cite the paper if you use it.

**Cultivar chill requirements**
'Búlida' 47.5 chill portions and 'Búlida Precoz' 33.7, from: Ruiz D, Egea J, Salazar JA, Campoy JA
(2019). *Chilling and heat requirements of Japanese plum cultivars and their association with
maturity date.* Scientia Horticulturae 254:187-192. These two numbers carry the whole result, so
the reference matters more than a citation usually does.

**Administrative boundaries**
Retrieved at runtime by the `mapSpain` R package, which sources them from the Instituto Geográfico
Nacional. Several scripts therefore need network access on first use, and cache afterwards.

## Code

**chillR**
Eduardo Luedeling and contributors. GPL-3. Supplies `fix_weather`, `tempResponse_daily_list`,
`Utah_Model` and `Dynamic_Model`, which is the backbone of every chill calculation here. Install
from CRAN; see `install_deps.R` for the dependency order that makes it install cleanly.

**DM_JOSE.R**
The Dynamic Model under the parametrisation of Fishman et al. (1987), written by J. A. Egea and
provided privately to the author. **Not distributed in this repository**, because co-authorship of
the work is not a licence to redistribute the code, and because its body closely follows chillR's
own `Dynamic_Model`, which is GPL-3.

It matters which parametrisation is used. chillR's default carries the 1988 parameters, and on the
Cieza series the two differ by 6.94 chill portions on average, which is half the 13.8 that separate
the two cultivars. `00_paths.R` fails with instructions when the file is absent, including the
constants themselves, which come from a published paper:

    E0 = 4457.8, E1 = 10161.9, A0 = 419700, A1 = 1.797e14, slope = 1.6, Tf = 277

Fishman S, Erez A, Couvillon GA (1987). *The temperature dependence of dormancy breaking in
plants: computer simulation of processes studied under controlled temperatures.* Journal of
Theoretical Biology 126:309-321, and *mathematical analysis of a two-step model involving a
cooperative transition*, ibid. 124:473-483.
