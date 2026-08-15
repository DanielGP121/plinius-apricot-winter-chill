"""Narrative of the talk deck, read by 35_build_talk_pptx.py.

Kept apart from the builder so the wording can be reworked without touching layout code, the same
split the project already uses for deck_content.R and 29_build_deck.R.

Every slide title is an assertion, not a label. That is the convention the IPCC WGI Visual Style
Guide calls the intent rule and applied to every visual in the AR6 Summary for Policymakers: write
the message as a sentence, then use the sentence as the title. A title that reads "Results" makes
the audience find the message; a title that states it lets them spend their attention on the
evidence underneath.

Every number that comes out of the analysis arrives through `N`, loaded from talk_key_numbers.csv
and method_figure_numbers.csv, so those cannot drift from the tables that produced them. Numbers
that are NOT analysis outputs are typed here: the two chill requirements, which are literature
values from Ruiz et al. 2019, the dataset descriptions, and the figures quoted from the canonical
project document. Those are the ones to re-check by hand, and an earlier version of this docstring
claimed no number was ever typed here, which was false and hid exactly that.

Slide kinds:
    cover       title page
    section     part divider
    figure      assertion + one image, optionally with a caption under it
    figure_side assertion + image on the left, short points on the right
    compare     assertion + two labelled columns of native shapes (no image)
    ingredients assertion + the three data layers as native shapes
    close       take-home page

Prose is Spanish: this is the working version, for the author and for the coauthor. What gets
projected on 8 October is a translation of a subset of it.
"""

FIG = "02_outputs/figures_chill"
GIF = "02_outputs/gifs"
FRAME = "02_outputs/gif_frames"

# Situations drawn by 19_cropland_viability_national.R, in the order its SIT_ORDER fixes. Used to
# build the contact sheet in the annex without hard-coding fifteen file names.
GALLERY_MAPS = [
    ("fig20_01_viability_observaciones_present.png", "Observado 1995-2020"),
    ("fig20_02_viability_presente_present.png", "Modelo, base 1995-2020"),
    ("fig20_03_viability_presente_current.png", "Modelo, clima actual 1995-2025"),
    ("fig20_04_viability_observaciones_obsref.png", "Observado 1991-2020"),
    ("fig20_05_viability_historical_ref.png", "Histórico simulado 1985-2014"),
    ("fig20_06_viability_pooled_nearterm.png", "2021-2040, los 3 juntos"),
    ("fig20_07_viability_ssp126_nearterm.png", "SSP1-2.6 · 2021-2040"),
    ("fig20_08_viability_ssp245_nearterm.png", "SSP2-4.5 · 2021-2040"),
    ("fig20_09_viability_ssp370_nearterm.png", "SSP3-7.0 · 2021-2040"),
    ("fig20_10_viability_ssp126_near.png", "SSP1-2.6 · 2041-2070"),
    ("fig20_11_viability_ssp245_near.png", "SSP2-4.5 · 2041-2070"),
    ("fig20_12_viability_ssp370_near.png", "SSP3-7.0 · 2041-2070"),
    ("fig20_13_viability_ssp126_far.png", "SSP1-2.6 · 2071-2100"),
    ("fig20_14_viability_ssp245_far.png", "SSP2-4.5 · 2071-2100"),
    ("fig20_15_viability_ssp370_far.png", "SSP3-7.0 · 2071-2100"),
]


def es(x, dec=0):
    """Format a number the Spanish way: full stop for thousands, comma for decimals.

    Written as a function rather than as a `.replace(",", ".")` on the finished sentence, which is
    what this file did at first. That shortcut also rewrote every comma in the surrounding prose,
    turning "cultivables de España, 'Búlida' deja de..." into "cultivables de España. 'Búlida'
    deja de...", and it left the decimal separator as a full stop, which is wrong in Spanish. The
    swap goes through a placeholder because the two separators trade places.
    """
    s = f"{x:,.{dec}f}"
    return s.replace(",", "\x00").replace(".", ",").replace("\x00", ".")


def slides(N):
    """Build the slide list. `N` maps metric name to value, straight from the output tables.

    Six sections, in the order an audience needs them: what data went in, what was done to it,
    what was and was not adjusted, what came out, what it means, and what it does not mean.

    Titles change register between sections on purpose. In datos, lógica and ajustes they describe
    what the slide shows, because forcing an assertion onto a slide that introduces a dataset reads
    as sales. In resultados and discusión they assert, following the IPCC intent rule.
    """
    pct_resc = N["rescued_pct_of_lost"]
    return [
        dict(kind="cover",
             title="El frío que se va, y una mutación que compra tiempo",
             subtitle="Cómo se calcula dónde deja de cumplirse el requerimiento de frío invernal "
                      "del albaricoquero 'Búlida', y hasta dónde lo rescata su mutante somático "
                      "'Búlida Precoz'",
             authors="Daniel González-Palazón¹ · José A. Egea²",
             affil="¹ Estación Experimental de Aula Dei (EEAD-CSIC), Zaragoza    "
                   "² Centro de Edafología y Biología Aplicada del Segura (CEBAS-CSIC), Murcia",
             venue="19th Plinius Conference on Mediterranean Risks · Murcia · 8 de octubre de 2026",
             notes="Versión de trabajo en español, orientada a explicar el método. Seis secciones: "
                   "datos, lógica, ajustes, resultados, discusión y cierre. El material que se "
                   "proyecte en octubre será una traducción de un subconjunto."),

        # ---------------------------------------------------------------- 1. DATOS
        dict(kind="section", n="1", title="Los datos",
             lead="Cuatro fuentes con papeles distintos: una dice cuánto frío habrá, dos dicen "
                  "cuánto ha hecho, y la cuarta dice dónde eso le importa a alguien."),

        dict(kind="ingredients",
             title="Cuatro fuentes, cuatro papeles",
             items=[
                 dict(head="Proyecciones", body="PNACC AR6, método ESD-RegBA\n"
                                                "11 modelos CMIP6 × 3 escenarios\n"
                                                "3.460 estaciones, diario\n"
                                                "88 ficheros, ~15 GB"),
                 dict(head="Observado", body="AEMET, dos productos\n"
                                             "Archivo 1975-2020 (3.044 est.)\n"
                                             "API 2021-2025\n"
                                             "Registro empalmado de 665"),
                 dict(head="Suelo", body="CORINE Land Cover 2018\n"
                                         "ráster de 100 m\n"
                                         "clases 211-244 sin pastos\n"
                                         "229.604 km² cultivables"),
                 dict(head="Requerimientos", body="Ruiz et al. 2019\n"
                                                  "'Búlida' 47,5 CP\n"
                                                  "'Búlida Precoz' 33,7 CP\n"
                                                  "medidos con el mismo modelo"),
             ],
             foot="Las tres primeras son capas de datos. La cuarta es lo que convierte un mapa de "
                  "temperatura en un mapa de decisiones agronómicas.",
             source="§ 2 del documento canónico v2",
             notes="Merece la pena detenerse en la cuarta. Sin los requerimientos varietales esto "
                   "sería un mapa de frío más; con ellos es un mapa de dónde se puede plantar "
                   "qué. Y es también la mayor incertidumbre del trabajo, porque depende de con "
                   "qué parametrización se midieron. Sale otra vez en la sección de discusión."),

        dict(kind="compare",
             title="Las proyecciones vienen ya regionalizadas a estación, no en rejilla",
             left=dict(head="Qué es ESD-RegBA", big="11 × 3",
                       lines=["Regionalización estadística del PNACC AR6, publicada por AEMET",
                              "Entrega temperatura diaria máxima y mínima en cada estación",
                              "Histórico 1950-2014, escenarios 2015-2100",
                              "Es el único método publicado para temperatura en este producto"]),
             right=dict(head="La trampa de la descarga", big="3.460 ≠ 3.044",
                        lines=["THREDDS sirve 3.460 estaciones; el formulario web, 3.044",
                               "Es el mismo producto científico en dos empaquetados",
                               "Comprobado por aritmética sobre el propio fichero recibido",
                               "En Methods hay que declarar la vía usada, o nadie reproduce los km²"]),
             foot="Trabajar con estaciones y no con rejilla es lo que permite comparar directamente "
                  "con las observaciones en el mismo punto, sin interpolar antes de validar.",
             source="§ 2.1 y § 2.1.1 del documento canónico v2",
             notes="Si alguien pregunta por qué estaciones y no rejilla: porque la validación "
                   "contra observaciones se hace en el mismo punto, sin meter por medio una "
                   "interpolación. La interpolación viene después, y sólo para pasar a superficie.\n\n"
                   "Lo de las dos vías se descubrió comprobando si el script de descarga bajaba lo "
                   "mismo que la interfaz web. No lo bajaba. Consecuencia práctica: 416 estaciones "
                   "entran en la interpolación sin haber pasado por el contraste con observado, "
                   "porque el observado sólo cubre las 3.044."),

        dict(kind="figure_side",
             title="El observado llega hasta 2025 empalmando dos productos de AEMET",
             image=f"{FIG}/fig25_01_observed_chill_series_1976_2025.png",
             points=["El archivo histórico cubre 1975-2020 con 3.044 estaciones.",
                     "La API abierta cubre 2021-2025, y es un producto distinto: otra cadena de "
                     "control de calidad.",
                     "Empalmarlos exige demostrar antes que miden lo mismo. Se hizo, y se ve en "
                     "la sección de ajustes.",
                     "El registro resultante tiene 665 estaciones con serie continua de 50 "
                     "inviernos."],
             source="§ 2.2 y § 6.7 del documento canónico v2 · scripts 21 a 26",
             notes="Este empalme no estaba en el plan original. Surgió de una pregunta menor "
                   "(¿son intercambiables los dos productos?) y acabó produciendo un resultado "
                   "propio, que sale en la sección 4."),

        dict(kind="figure",
             title="El suelo cultivable se define por clases CORINE, y la elección se comprobó",
             image=f"{FIG}/fig6_soil_criteria_compare.png",
             caption="Criterio adoptado: clases 211 a 244 excluyendo 231 (pastos). Son 229.604 km².",
             source="§ 2.3 del documento canónico v2 · 05_cropland_filter.py",
             notes="La pregunta razonable es si el resultado depende de dónde se ponga la frontera "
                   "de 'suelo cultivable'. Se probaron criterios más estrechos y más anchos y la "
                   "diferencia en los porcentajes finales es de dos puntos y medio como mucho. "
                   "Se eligió el criterio ancho porque el albaricoquero convive con otros cultivos "
                   "leñosos en mosaico, que es justo lo que recogen las clases 241-244."),

        # ---------------------------------------------------------------- 2. LÓGICA
        dict(kind="section", n="2", title="La lógica del cálculo",
             lead="De una temperatura diaria a un kilómetro cuadrado clasificado hay cinco pasos, "
                  "y cada uno reduce el número de valores."),

        dict(kind="figure",
             title="Cómo se mide el frío: el modelo dinámico tiene un óptimo a 8 °C",
             image=f"{FIG}/fig34_dynamic_model_response.png",
             caption="El frutal necesita acumular frío en invierno para salir de la dormancia. Se "
                     "mide en chill portions, y la temperatura que más aporta no es la mínima: "
                     f"a 0 °C sólo se acumula el {es(N['dm_pct_at_0C'])} % del óptimo.",
             source="Fishman et al. 1987 · curva medida sobre el propio modelo en 34_method_figures.R",
             notes="Punto de partida obligado. Tres ideas para el público que no viene de "
                   "fruticultura: el árbol necesita pasar frío para florecer bien; ese frío se "
                   "mide en porciones y no en horas bajo un umbral; y un invierno gélido puede "
                   "acumular MENOS que uno templado, porque por debajo de −4 °C no se acumula "
                   "nada. De ahí que el calentamiento no reduzca el frío de forma lineal."),

        dict(kind="figure",
             title="De las temporadas a un solo número: por qué el percentil 10",
             image=f"{FIG}/fig35_swc_concept.png",
             caption="Al agricultor no lo arruina el invierno medio, sino el invierno pobre. El "
                     "Safe Winter Chill es el frío que se supera nueve de cada diez inviernos.",
             source="§ 4 del documento canónico v2 · temporadas JDay 305-59, completitud ≥ 85 %",
             notes="Si un emplazamiento da 47,5 CP de media y el cultivo necesita 47,5, fracasa "
                   "uno de cada dos años. El P10 traslada la pregunta de 'cuánto frío hace' a "
                   "'con cuánto puedo contar', que es la que se responde antes de plantar un árbol "
                   f"que estará veinte años. La estación del ejemplo tiene media "
                   f"{es(N['swc_example_mean'], 1)} CP y P10 {es(N['swc_example_p10'], 1)}."),

        dict(kind="figure",
             title="La cadena completa: cinco reducciones sucesivas",
             image=f"{FIG}/fig44_aggregation_chain.png",
             source="§ 6.10 del documento canónico v2",
             notes="Esta es la diapositiva que contesta a 'de dónde sale el mapa'. Los números "
                   f"importan: se parte de {es(N['chain_stations'])} estaciones por "
                   f"{es(N['chain_models'])} modelos, se obtienen {es(N['chain_swc_values'])} "
                   f"valores de Safe Winter Chill, se colapsan a {es(N['chain_stations'])} "
                   f"tomando la mediana entre modelos, y de ahí se interpola a "
                   f"{es(N['chain_cells'])} celdas de 1 km.\n\n"
                   "El punto que hay que decir en voz alta es dónde se pierde la dispersión entre "
                   "modelos: en el cuarto paso. Por eso la sección de discusión la recupera "
                   "aparte, en vez de darla por perdida."),

        dict(kind="figure",
             title="De estaciones a superficie: interpolación y máscara de cultivo",
             image=f"{FIG}/fig36_method_chain.png",
             caption="Lo que hay, lo que se interpola y dónde se recorta. Las estaciones se "
                     "agrupan en valles, aeropuertos y ciudades, y 151 puntos llevan dos a la "
                     "vez, así que contarlas no estima territorio.",
             source="§ 34_method_figures.R · método de Egea et al. 2022 "
                    "(Front. Plant Sci. 13:842628)",
             notes="La interpolación es IDW con radio de 50 km y potencia 2, replicando el método "
                   "de Egea et al. 2022 sobre esta misma región. Las celdas sin ninguna estación "
                   "a menos de 50 km se quedan vacías, que es la máscara de aquel trabajo.\n\n"
                   "Si preguntan por qué IDW y no kriging con covariables, que es lo habitual en "
                   "la literatura reciente: porque se replica un método publicado para esta región "
                   "y con estos cultivares, y se hace con 3.460 estaciones frente a las 270 de "
                   "aquella referencia, así que la superficie está mucho mejor sujeta."),

        dict(kind="figure",
             title="La misma cadena, seguida en una estación real",
             image=f"{FIG}/fig46_station_walkthrough.png",
             caption=f"Calasparra (Murcia, 394 m). P10 observado "
                     f"{es(N['walk_p10_obs'], 1)} CP; mediana del ensemble "
                     f"{es(N['walk_med_base'], 1)} hoy y {es(N['walk_med_far'], 1)} a fin de siglo.",
             source="§ 38_method_figures.R · estación 7121A del inventario de AEMET",
             notes="Aquí se puede comprobar la aritmética del método en un caso concreto. "
                   "Calasparra está en el valle del Segura, en zona de albaricoquero.\n\n"
                   f"Lo observado y lo simulado casi coinciden hoy ({es(N['walk_p10_obs'], 1)} "
                   f"contra {es(N['walk_med_base'], 1)} CP), lo cual es el contraste de la sección "
                   f"siguiente en un solo punto. Y a fin de siglo la mediana cae a "
                   f"{es(N['walk_med_far'], 1)} CP: por debajo de los 47,5 que necesita 'Búlida' "
                   "y muy por encima de los 33,7 de su mutante. Esta estación es, literalmente, "
                   "el argumento de la charla en un punto del mapa."),

        # ---------------------------------------------------------------- 3. AJUSTES
        dict(kind="section", n="3", title="Los ajustes",
             lead="Qué se corrigió, qué se decidió no corregir, y con qué evidencia se tomó cada "
                  "una de las dos decisiones."),

        dict(kind="figure",
             title="No se aplicó corrección de sesgo, y esta figura es por qué",
             image=f"{FIG}/fig43_model_bias.png",
             caption=f"Los once modelos caben en {es(N['bias_range_CP'], 1)} CP de amplitud, sobre "
                     f"una variable cuya mediana nacional ronda los 74. El peor se desvía "
                     f"{es(N['bias_worst_abs_CP'], 2)} CP.",
             source="§ 6.1 del documento canónico v2 · § 38_method_figures.R",
             notes="Contesta directamente a la pregunta de si se ajustaron los datos. La respuesta "
                   "es que llegan ya ajustados de origen (ESD-RegBA es una regionalización "
                   "estadística con corrección incorporada, hecha por AEMET) y que NO se aplicó "
                   "ninguna corrección adicional.\n\n"
                   f"La decisión no se asumió, se midió: sobre las mismas "
                   f"{es(N['n_bias_stations'])} estaciones y la misma ventana, el sesgo de la "
                   f"mediana del ensemble es {es(N['bias_ensemble_CP'], 2)} CP y la correlación "
                   f"espacial 0,984. Modelo a modelo va de {es(N['bias_min_CP'], 2)} "
                   f"({N['bias_min_model']}) a +{es(N['bias_max_CP'], 2)} "
                   f"({N['bias_max_model']}), y ninguna correlación baja de "
                   f"{es(N['r_min'], 3)}.\n\n"
                   "CAVEAT obligatorio, decirlo sin que lo pregunten: ESD-RegBA se calibró contra "
                   "estas mismas estaciones, así que esto no es validación independiente. Es una "
                   "comprobación de consistencia. Y hay 416 estaciones que entran en la "
                   "interpolación sin haber pasado por ella, porque no tienen observado."),

        dict(kind="figure",
             title="Y aunque lo hubiera, el resultado no depende de ello",
             image=f"{FIG}/fig45_delta_vs_absolute.png",
             caption="Comparando cada modelo con su propia línea base, cualquier sesgo constante "
                     "que arrastre se cancela en la resta.",
             source="§ 6.6 del documento canónico v2 · § 38_method_figures.R",
             notes="Es el argumento que blinda la decisión anterior. Si la conclusión sólo se "
                   "sostuviera con valores absolutos, dependería de no haber corregido. "
                   f"Trabajando en diferencias, la pérdida mediana bajo SSP3-7.0 a fin de siglo es "
                   f"de {es(abs(N['delta_median_CP']), 1)} CP, con un rango entre modelos de "
                   f"{es(abs(N['delta_max_CP']), 1)} a {es(abs(N['delta_min_CP']), 1)} CP, y el "
                   "88 % de las estaciones pierde frío.\n\n"
                   "Detalle bonito para quien pregunte por el orden de agregación: aquí las tres "
                   "formas de promediar dan −12,8, −11,8 y −12,2 CP, o sea que coinciden. En la "
                   "ventana 2021-2040 esas mismas tres formas llegan a cambiar el signo. Cuando "
                   "hay señal, el orden deja de importar."),

        dict(kind="figure",
             title="El único empalme que sí hubo que verificar: los dos observados",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             caption="Safe Winter Chill calculado sobre las mismas temporadas desde el archivo y "
                     "desde la API: sesgo +0,13 CP y correlación espacial 0,9865.",
             source="§ 6.7 del documento canónico v2 · 24_observed_api_vs_archive.R",
             notes="Aquí sí hubo que demostrar algo antes de usarlo. Por temporada suelta los dos "
                   "productos discrepan (MAE 1,35 CP), pero el estadístico que alimenta los mapas "
                   "es el P10 sobre muchas temporadas, y ahí coinciden.\n\n"
                   "Tampoco se corrigió el +0,13 CP. Y conviene decir por qué es seguro no "
                   "hacerlo: ese sesgo empuja al alza, o sea EN CONTRA del hallazgo de que los "
                   "últimos cinco inviernos son pobres en frío. Si corrigiéramos, el resultado "
                   "sería aún más marcado."),

        # ---------------------------------------------------------------- 4. RESULTADOS
        dict(kind="section", n="4", title="Los resultados",
             lead="Un punto de partida, tres futuros, y una superficie que cambia de manos."),

        dict(kind="figure_side",
             title="Lo que dicen los termómetros, antes de meter ningún modelo",
             image=f"{FIG}/fig47_observed_viability.png",
             points=["Azul: las dos variedades cumplen su requerimiento.",
                     "Naranja: sólo lo cumple el mutante. Hoy es una franja fina en el sur y en "
                     "la costa mediterránea.",
                     "Rojo: no lo cumple ninguna de las dos. Hoy casi no existe.",
                     "Esto está medido, no simulado: son las 3.044 estaciones con observado "
                     "entre 1995 y 2020."],
             source="§ 37_model_figures.R · observado 1995-2020",
             notes="Ancla visual y punto de partida honesto: antes de pedir al público que se "
                   "crea ningún futuro, esto es lo que hay medido. Dedicarle unos segundos de "
                   "silencio para que fije la clave de color, porque todo lo que viene después es "
                   "esta misma imagen cambiando."),

        dict(kind="figure",
             title="Los once modelos, cada uno por su cuenta, en esa misma ventana",
             image=f"{FIG}/fig40_small_multiples_presente_present.png",
             caption="Línea base 1995-2020. Cada mapa es un modelo climático distinto, sin "
                     "promediar nada. Compárense con el mapa observado de la diapositiva anterior.",
             source="§ 37_model_figures.R · 11 modelos CMIP6, ESD-RegBA",
             notes="Aquí es donde se ve que los modelos parten de un sitio razonable. Ninguno es "
                   "idéntico al observado, pero todos reproducen el mismo patrón: la franja "
                   "naranja en el sur y la costa, y el azul en el resto.\n\n"
                   "Es la versión visual del sesgo que se midió en la sección 3: los once caben "
                   f"en {es(N['bias_range_CP'], 1)} CP de amplitud."),

        dict(kind="figure_side",
             title="La mediana de esos once es el mapa que se usa como línea base",
             image=f"{FIG}/fig37_baseline_today.png",
             points=["Se toma, en cada estación por separado, el valor central de los once "
                     "modelos.",
                     "No es el mapa de ningún modelo: el que queda en el centro cambia de una "
                     "estación a otra.",
                     "Se parece mucho al observado, que es lo que había que comprobar antes de "
                     "aplicar la misma receta a los futuros.",
                     "Esta operación es la cuarta de las cinco reducciones de la cadena, y es "
                     "donde se pierde la dispersión entre modelos."],
             source="§ 34_method_figures.R · mediana del ensemble, línea base 1995-2020",
             notes="La diapositiva bisagra. Se acaba de ver lo medido y los once simulados; aquí "
                   "se explica la operación que los convierte en un solo mapa, y se comprueba en "
                   "la ventana donde hay observado con qué compararlo. La misma receta se aplica "
                   "después a los tres escenarios, y ahí ya no hay observado que sirva de "
                   "control."),

        dict(kind="figure",
             title="SSP1-2.6 a fin de siglo, modelo a modelo",
             image=f"{FIG}/fig40_small_multiples_ssp126_far.png",
             caption="Ordenados de mayor a menor fracción de suelo que el mutante todavía cubre.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="Escenario de emisiones bajas. La franja naranja crece respecto a la línea "
                   "base, pero el rojo apenas aparece. Conviene ir pasando las tres hojas "
                   "seguidas y sin detenerse mucho: el mensaje está en la comparación entre ellas, "
                   "no en ningún mapa concreto."),

        dict(kind="figure",
             title="SSP2-4.5 a fin de siglo, modelo a modelo",
             image=f"{FIG}/fig40_small_multiples_ssp245_far.png",
             caption="El mismo orden y la misma escala de color que la hoja anterior.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="Escenario intermedio. Empieza a aparecer rojo en el Guadalquivir y en el "
                   "sureste, y en algunos modelos bastante."),

        dict(kind="figure",
             title="SSP3-7.0 a fin de siglo, modelo a modelo",
             image=f"{FIG}/fig40_small_multiples_ssp370_far.png",
             caption="Aquí se ve la dispersión completa: entre el modelo más suave y el más duro "
                     "hay más diferencia que entre este escenario y SSP1-2.6.",
             source="§ 37_model_figures.R · 2071-2100",
             notes="La hoja que más conviene dejar respirar. Dos lecturas: todos los modelos "
                   "coinciden en que hay pérdida y en dónde está (sur y costa mediterránea), pero "
                   "discrepan mucho en cuánta.\n\n"
                   f"Cuantificado: la fracción que el mutante rescata va del "
                   f"{es(N['km2_rescued_min_pct'], 1)} % ({N['km2_rescued_min_model']}) al "
                   f"{es(N['km2_rescued_max_pct'], 1)} % ({N['km2_rescued_max_model']}). Es la "
                   "figura que hay detrás de la diapositiva de rango por modelo de la sección 5."),

        dict(kind="figure",
             title="Y así es como esos 33 mapas se convierten en tres",
             image=f"{GIF}/sidebyside.gif",
             caption="La mediana entre modelos, estación por estación, aplicada a cada escenario "
                     "y a cada ventana. Las líneas diagonales marcan dónde menos del 80 % de los "
                     "modelos coinciden, así que la dispersión que se acaba de ver no desaparece: "
                     "queda dibujada encima.",
             source="§ 31_scenario_frames.R · mediana de 11 modelos CMIP6",
             gif=True,
             notes="ATENCIÓN: es un GIF, sólo se anima en modo presentación. Dejar que dé una "
                   "vuelta entera en silencio antes de hablar.\n\n"
                   "Señalar tres cosas: el naranja crece desde el suroeste y desde la costa "
                   "mediterránea, el rojo aparece primero en el valle del Guadalquivir, y a "
                   "2021-2040 los tres paneles son casi iguales.\n\n"
                   "PREGUNTA CASI SEGURA: en 2021-2040 SSP3-7.0 pierde MENOS suelo que SSP2-4.5, "
                   "lo cual parece del revés. No es un error: los km² del fotograma coinciden al "
                   "km² con la tabla. Es que a ese horizonte los modelos discrepan "
                   f"{es(N['nearterm_spread_models_CP'], 1)} CP entre sí donde los escenarios "
                   f"discrepan {es(N['nearterm_spread_scenarios_CP'], 1)}. Está desarrollado en la "
                   "sección 5 y hay una diapositiva de respaldo en el anexo."),

        dict(kind="figure",
             title="A fin de siglo el mutante cubre la mitad del suelo que 'Búlida' ya no puede",
             image=f"{FIG}/fig33_headline_flow.png",
             source="§ talk_numbers_cropland.csv · SSP3-7.0, 2071-2100",
             notes=f"El titular. De los {es(N['total_cropland_km2'])} km² cultivables de España, "
                   f"'Búlida' no cumple su requerimiento en {es(N['lost_km2'])} a fin de siglo. "
                   f"El mutante cubre {es(N['rescued_km2'])} de ellos, un {es(pct_resc, 1)} %.\n\n"
                   "OJO con la atribución si alguien pregunta: esa cifra es un estado final, no un "
                   f"cambio. {es(N['baseline_already_lost_km2'])} km² ya estaban fuera de 'Búlida' "
                   f"en la línea base. Lo que el calentamiento quita son "
                   f"{es(N['warming_lost_km2'])} km², y de eso el mutante rescata el "
                   f"{es(N['warming_rescued_pct'], 1)} %."),

        dict(kind="figure",
             title="Visto en el tiempo, el mutante reduce a la mitad el suelo que pierde el frío",
             image=f"{FIG}/fig30_time_of_emergence_ssp370.png",
             caption="Primera ventana en la que el frío cae por debajo del requerimiento. En gris, "
                     "el suelo donde eso no llega a ocurrir antes de 2100.",
             source="§ 33_talk_figures.R · convención de tiempo de emergencia de Schuhen et al. "
                    "2026 (NHESS 26:753)",
             notes=f"El suelo que 'Búlida' pierde en algún momento del siglo es el "
                   f"{es(N['toe_pct_lost_bulida'], 1)} %; para el mutante, el "
                   f"{es(N['toe_pct_lost_precoz'], 1)} %.\n\n"
                   "Dos precisiones. El gris no significa que allí no pase nada, sino que el "
                   "umbral de ese cultivar no se cruza antes de 2100. Y el mutante no saca el "
                   "problema del siglo: en ese 9,5 % lo cruza igual, sólo que más tarde."),

        dict(kind="figure",
             title="En Murcia, que es donde se cultiva, el mutante decide en la mitad de la región",
             image=f"{FIG}/fig31_murcia_ensemble_requirements.png",
             source="§ 33_talk_figures.R · estaciones dentro de la Región de Murcia",
             notes=f"Las {es(N['murcia_stations'])} estaciones de la Región. La mediana parte de "
                   f"unos 58 CP y termina en {es(N['murcia_median_far'], 1)} bajo SSP3-7.0.\n\n"
                   f"A fin de siglo el {es(N['murcia_below_bulida_pct'])} % de las estaciones "
                   f"queda por debajo de 47,5 CP y el {es(N['murcia_below_precoz_pct'])} % por "
                   "debajo incluso de 33,7. El mutante decide en la banda intermedia, que es "
                   "aproximadamente la mitad de la región; en la otra mitad no salva a nadie."),

        dict(kind="figure",
             title="Y el registro observado ya se movió: cuarenta y cinco inviernos planos, luego cinco",
             image=f"{FIG}/fig32_observed_stripes.png",
             source="§ 26_observed_long_record.R · anomalía por estación frente a la base 1976-2020",
             notes=f"Resultado propio, no proyección. El quinquenio 2021-2025 pierde "
                   f"{es(abs(N['obs_recent_anom_CP']), 2)} CP respecto a la base "
                   f"{es(N['obs_baseline_first_year'])}-2020, o "
                   f"{es(abs(N['obs_recent_sd']), 2)} desviaciones típicas, y aporta "
                   f"{es(N['obs_recent_in_10_mildest'])} de los 10 inviernos más pobres de los 50. "
                   f"De los {es(N['obs_n_baseline_blocks'])} quinquenios anteriores, "
                   f"{es(N['obs_blocks_as_mild'])} llegan a ser tan pobres (p = "
                   f"{es(N['obs_p_exchangeable'], 4)}).\n\n"
                   "La afirmación es sobre el BLOQUE, no sobre cada invierno: 2022 es del montón, "
                   f"puesto 21 de 50. Y ojo con la palabra tendencia: los "
                   f"{es(N['obs_baseline_n_seasons'])} inviernos de 1976 a 2020 no la tienen "
                   "(p = 0,90), pero el registro completo de 50 sí sale significativo (p = 0,047), "
                   "justo por culpa de este bloque."),

        # ---------------------------------------------------------------- 5. DISCUSIÓN
        dict(kind="section", n="5", title="Discusión",
             lead="Qué parte de esto se sostiene, qué parte depende del modelo que se mire, y qué "
                  "podría estar mal."),

        dict(kind="figure",
             title="A corto plazo los modelos ni siquiera coinciden en la dirección del cambio",
             image=f"{FIG}/fig42_sign_agreement_ssp370.png",
             caption=f"El acuerdo pasa del {es(N['agree_sign_nearterm'], 1)} % al "
                     f"{es(N['agree_sign_far'], 1)} % del suelo cultivable entre las dos ventanas. "
                     f"Sobre la clasificación, en cambio, coinciden en el "
                     f"{es(N['agree_class_far'], 1)} % ya a fin de siglo.",
             source="§ 36_per_model_stats.R · § 37_model_figures.R",
             notes="Son dos preguntas distintas y conviene no mezclarlas, porque el proyecto las "
                   "mezcló durante un tiempo. Si los modelos coinciden en CLASIFICAR una celda "
                   "por encima o por debajo de 47,5 CP, el acuerdo es alto en todas partes. Si "
                   "coinciden en el SIGNO del cambio a corto plazo, se hunde.\n\n"
                   "O sea: el mapa de dónde se puede cultivar está bien sostenido; lo que no se "
                   "sostiene es leer diferencias entre escenarios antes de 2040. En el 62 % de "
                   "las estaciones el escenario pesimista devuelve más frío que el optimista a "
                   "ese horizonte."),

        dict(kind="figure",
             title="El resultado depende del modelo, pero ninguno lo desmiente",
             image=f"{FIG}/fig41_per_model_range.png",
             caption="Cada punto es uno de los 11 modelos. La barra vertical es la mediana.",
             source="§ 36_per_model_stats.R · per_model_cropland_km2.csv",
             notes=f"Bajo SSP3-7.0 a fin de siglo la fracción rescatada va del "
                   f"{es(N['km2_rescued_min_pct'], 1)} % ({N['km2_rescued_min_model']}) al "
                   f"{es(N['km2_rescued_max_pct'], 1)} % ({N['km2_rescued_max_model']}), con "
                   f"mediana {es(N['km2_rescued_median_pct'], 1)} %. Ninguno baja de un tercio, "
                   "así que la conclusión cualitativa no depende de qué modelo se crea.\n\n"
                   "El panel derecho está porque el rango que cita el documento del proyecto "
                   f"({es(N['station_rescued_min_pct'], 1)}-"
                   f"{es(N['station_rescued_max_pct'], 1)} %) está medido sobre estaciones, "
                   "mientras los titulares están medidos sobre superficie. Sobre superficie la "
                   "frase 'ninguno baja de un tercio' es cierta; sobre estaciones es falsa. Los "
                   "dos números son reales, emparejarlos era el error."),

        dict(kind="figure_side",
             title="Un instrumento que no es de AEMET dice lo mismo",
             image=f"{FIG}/fig26_01_independent_records.png",
             points=["La serie de Cieza (CEBAS-CSIC) es una parcela experimental, con otro "
                     "instrumento y otro operador.",
                     "Sobre su propia base 2012-2020 da −6,84 CP, o −1,66 σ. Sólo tiene nueve "
                     "años, así que no admite otra base.",
                     "Las dos estaciones AEMET cercanas, sobre la base larga 1976-2020, dan "
                     "−1,45 y −1,94 σ.",
                     "El conjunto nacional, sobre esa misma base larga, da −1,95 σ."],
             source="§ 27_cieza_independent_check.R · cieza_check_summary.csv",
             notes="Cierra la objeción de 'esto es un problema de homogeneidad de la red de "
                   "AEMET'. Un termómetro ajeno a esa red reproduce la caída.\n\n"
                   "No mezclar las sigmas de las dos bases al hablar: sobre base corta la "
                   "anomalía sale mayor, y presentarlas juntas exageraría la convergencia."),

        dict(kind="figure_side",
             title="Lo que podría estar mal, dicho antes de que lo pregunten",
             image=f"{FIG}/fig26_02_parametrisation_gap.png",
             points=["La parametrización, y es la mayor. El modelo de 1987 y el de 1988 se llevan "
                     "6,94 CP medidos sobre Cieza, la mitad de la brecha entre los dos cultivares. "
                     "Si los requerimientos de Ruiz et al. 2019 estuvieran en la otra escala, "
                     "todas las superficies cambian.",
                     "La validación es circular: ESD-RegBA se calibró contra estas mismas "
                     "estaciones.",
                     "El censo de estaciones: las dos vías del portal dan 3.460 y 3.044, y la "
                     "validación sólo cubre las comunes.",
                     "La interpolación: IDW replica a Egea et al. 2022, pero la literatura "
                     "reciente prefiere kriging con covariables."],
             source="§ 27_cieza_independent_check.R · § 4.1.1 del documento canónico v2",
             notes="Ponerlo antes del cierre y no esconderlo. La primera es una pregunta abierta "
                   "para David Ruiz, no una debilidad del análisis: la sección de métodos de Ruiz "
                   "et al. 2019 cita Fishman 1987, así que es confirmación y no incógnita, pero "
                   "conviene tenerlo por escrito antes de publicar cifras de superficie."),

        # ---------------------------------------------------------------- 6. CIERRE
        dict(kind="close",
             title="Compra tiempo, no inmunidad",
             points=[f"De los {es(N['total_cropland_km2'])} km² cultivables de España, 'Búlida' "
                     f"deja de cumplir su requerimiento en {es(N['lost_km2'])} a fin de siglo bajo "
                     f"SSP3-7.0. El calentamiento aporta {es(N['warming_lost_km2'])} de ellos.",
                     f"Su mutante somático cubre {es(N['rescued_km2'])} km², la mitad, y el rango "
                     f"entre los 11 modelos va del {es(N['km2_rescued_min_pct'], 1)} % al "
                     f"{es(N['km2_rescued_max_pct'], 1)} %: ninguno baja de un tercio.",
                     "No se aplicó corrección de sesgo, y trabajando en diferencias el resultado "
                     "es el mismo, así que no depende de esa decisión.",
                     "Antes de 2040 los escenarios son indistinguibles: lo que decide esas dos "
                     "décadas es la variedad, no la política.",
                     "Y el registro observado ya se movió: el quinquenio 2021-2025 es el más pobre "
                     f"en frío de los {es(N['obs_n_baseline_blocks'])} anteriores."],
             foot="Código y figuras: github.com/DanielGP121/plinius-apricot-winter-chill",
             notes="Cerrar reformulando el problema y la respuesta, no con un 'gracias'. La frase "
                   "que resume: la mutación no resuelve el calentamiento, desplaza el momento en "
                   "que hay que tomar otra decisión."),
    ]


def annex(N):
    """Backup material, kept in its own file so the talk deck stays under the 20-slide cap.

    These are the slides the speaker jumps to when asked, not the ones they present. Everything
    here answers a question that has actually been asked about this work at some point: what does
    each scenario look like on its own, is the interpolated surface hiding the thresholds, are the
    two observational sources really interchangeable, and what do all fifteen situations look like
    side by side.
    """
    return [
        dict(kind="cover",
             title="Material de respaldo",
             subtitle="Las figuras que contestan a las preguntas más probables del turno de "
                      "discusión. No forman parte del recorrido de la charla.",
             authors="Daniel González-Palazón · José A. Egea",
             affil="EEAD-CSIC Zaragoza · CEBAS-CSIC Murcia",
             venue="Anexo de charla_plinius.pptx · 19th Plinius Conference, Murcia, 2026",
             notes="Fichero aparte para que la charla no pase de 20 diapositivas."),

        dict(kind="figure", title="SSP1-2.6, el escenario de emisiones bajas",
             image=f"{GIF}/ssp126.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="Bajo SSP1-2.6 el mutante rescata casi todo lo que 'Búlida' pierde: 89,3 %."),

        dict(kind="figure", title="SSP2-4.5, el escenario intermedio",
             image=f"{GIF}/ssp245.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="Intermedio también en el resultado."),

        dict(kind="figure", title="SSP3-7.0, el escenario severo",
             image=f"{GIF}/ssp370.gif", gif=True,
             source="§ 31_scenario_frames.R",
             notes="Es el que se usa en la charla porque es el que separa a los dos cultivares."),

        dict(kind="figure",
             title="La superficie continua de frío que hay detrás de las clases",
             image=f"{GIF}/swc_ssp370.gif", gif=True,
             caption="Los umbrales de 47,5 y 33,7 CP se aplican sobre esta superficie. Las clases "
                     "no son un artefacto del corte: son un gradiente cortado.",
             source="§ 31_scenario_frames.R · escala de color fija en todos los fotogramas",
             notes="Contesta a 'vuestro mapa depende del umbral'. Depende, claro, pero el "
                   "gradiente subyacente es continuo y suave, y el barrido de umbrales está "
                   "cuantificado en 28_threshold_sweep_cropland.R."),

        dict(kind="figure",
             title="El acuerdo entre modelos, con escala propia y todos sus niveles",
             image=f"{FIG}/fig48_agreement_scale_ssp370.png",
             caption="Aquí nada compite por el color, así que se ven los seis niveles posibles en "
                     "vez de las tres franjas del rayado.",
             source="§ 37_model_figures.R · § 36_per_model_stats.R",
             notes="El mapa de la izquierda es casi todo verde y el de la derecha casi todo rojo, "
                   "y son la misma región y los mismos once modelos: sólo cambia la pregunta. "
                   "Sobre en qué lado del umbral cae una celda, los modelos coinciden; sobre si "
                   "el frío sube o baja a veinte años vista, no.\n\n"
                   "Detalle que conviene tener claro por si lo preguntan: con 11 modelos el bando "
                   "mayoritario no puede ser menor que 6, así que el acuerdo sólo puede tomar "
                   "seis valores (55, 64, 73, 82, 91 y 100 %) y no existe nada por debajo del "
                   "55 %. El criterio del AR6, el 80 %, cae entre 8 y 9 modelos."),

        dict(kind="figure",
             title="El acuerdo entre modelos sobre el propio resultado",
             image=f"{FIG}/fig39_model_agreement_far.png",
             caption="Los tres escenarios a fin de siglo, con líneas diagonales donde menos del "
                     "80 % de los modelos coinciden en la clasificación.",
             source="§ 36_per_model_stats.R · § 37_model_figures.R",
             notes="Complementa la diapositiva 15 de la charla. Aquí el acuerdo es sobre la "
                   "CLASIFICACIÓN, no sobre el signo del cambio, y es alto: entre el 83 y el 95 % "
                   "del suelo según el escenario. Es el argumento de que el mapa que se proyecta "
                   "está bien sostenido aunque la comparación entre escenarios a corto plazo no "
                   "lo esté."),

        dict(kind="figure",
             title="Por qué SSP3-7.0 pierde menos suelo que SSP2-4.5 en 2021-2040",
             image=f"{FIG}/fig38_model_vs_scenario_spread.png",
             caption="Cada fila es un modelo; los tres puntos son los tres escenarios dentro de "
                     "ese modelo. El orden de los colores cambia de una fila a otra.",
             source="§ 33_talk_figures.R · estaciones marginales, ventana 2021-2040",
             notes="La diapositiva de respaldo para la pregunta más probable de todo el turno. "
                   "No es un error del montaje ni del análisis: los km² del fotograma coinciden "
                   "al km² con talk_numbers_cropland.csv.\n\n"
                   f"El escenario más pobre en frío es SSP1-2.6 en "
                   f"{es(N['nearterm_coldest_is_ssp126'])} modelos, SSP2-4.5 en "
                   f"{es(N['nearterm_coldest_is_ssp245'])} y SSP3-7.0 en "
                   f"{es(N['nearterm_coldest_is_ssp370'])}. No hay orden estable, así que ningún "
                   "escenario es sistemáticamente el más cálido a este horizonte. Dentro de un "
                   f"mismo modelo los escenarios se separan {es(N['nearterm_within_model_range_CP'], 1)} CP, "
                   f"pero entre modelos el rango es de {es(N['nearterm_spread_models_CP'], 1)} CP, "
                   "más que los 13,8 CP que separan a los dos cultivares.\n\n"
                   "Si hace falta rematar: sobre esas mismas estaciones, tomar la mediana entre "
                   f"modelos primero da {es(N['nearterm_order_models_first_CP'], 2)} CP y tomarla "
                   f"entre estaciones primero da {es(N['nearterm_order_stations_first_CP'], 2)} CP. "
                   "Signos opuestos. Cuando el orden en que promedias decide el signo, no hay "
                   "señal que medir.\n\n"
                   "Lo que NO se puede afirmar es la causa física. Que tres modelos den bastante "
                   "más frío bajo SSP3-7.0 es compatible con el efecto de los aerosoles (ese "
                   "escenario asume poca política de calidad del aire, y más aerosoles enfrían a "
                   "corto plazo), pero con una realización por modelo y una ventana de 20 años no "
                   "hay forma de separarlo de la variabilidad interna."),

        dict(kind="figure",
             title="Las quince situaciones calculadas, en una sola imagen",
             image=f"{FIG}/fig22_viability_bars.png",
             source="§ 19_cropland_viability_national.R · talk_numbers_cropland.csv",
             notes="Incluye las líneas base observadas y simuladas, que permiten ver cuánto se "
                   "parece el modelo a la observación en el mismo periodo."),

        dict(kind="gallery",
             title="Los quince mapas de viabilidad, para ir a cualquiera de ellos",
             items=GALLERY_MAPS,
             source="§ 19_cropland_viability_national.R",
             notes="Hoja de contactos. Sirve para localizar de un vistazo el mapa que alguien "
                   "pida y luego abrir el fichero correspondiente si hace falta verlo grande."),

        dict(kind="figure",
             title="Las dos fuentes observacionales miden lo mismo donde importa",
             image=f"{FIG}/fig23_02_api_vs_archive_swc.png",
             caption="Safe Winter Chill calculado sobre las mismas temporadas desde el archivo y "
                     "desde la API: sesgo +0,13 CP y r = 0,9865.",
             source="§ 24_observed_api_vs_archive.R",
             notes="Es lo que justifica empalmar archivo hasta 2020 con API desde 2021. Por "
                   "temporada suelta la concordancia es peor (MAE 1,35 CP), pero el estadístico "
                   "que se usa es el P10 sobre muchas temporadas, y ahí las dos fuentes "
                   "coinciden."),

        dict(kind="figure",
             title="El bloque reciente mirado por quinquenios móviles",
             image=f"{FIG}/fig25_02_running5_blocks.png",
             source="§ 26_observed_long_record.R",
             notes="Ninguno de los 41 bloques de cinco años anteriores baja tanto como "
                   "2021-2025."),

        dict(kind="figure",
             title="Cuánto se ha movido ya el frío entre 1995-2020 y 1995-2025",
             image=f"{FIG}/fig24_01_swc_shift_1995_2025.png",
             source="§ 25_splice_observed_1995_2025.R",
             notes="Añadir cinco años recientes a la ventana de referencia mueve el frío 0,45 CP "
                   "en el observado, frente a los 0,1 CP que predice el modelo para el mismo "
                   "cambio de ventana. Es una de las cuatro respuestas pendientes para Egea."),
    ]
