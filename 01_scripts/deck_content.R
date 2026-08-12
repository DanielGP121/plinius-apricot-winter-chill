# Narrative of the project deck, read by 29_build_deck.R.
#
# Kept apart from the builder so the text can be edited without touching the assembly code, and so
# the same content can feed both the HTML and the PowerPoint. Prose is in Spanish because this is a
# working document for the author and for the coauthor; the figures are already in English and the
# talk itself goes to English, so what gets projected on 8 October is a translation of a subset.
#
# Block kinds:
#   cover    title page
#   section  part divider, with a lead paragraph
#   slide    title + prose paragraphs + optional figures
#   gadget   an interactive panel built by the builder (id selects which)
#   gallery  a grid of figures with captions, for the supporting material

FIG <- function(...) c(...)

DECK <- list(

# ---------------------------------------------------------------------------------------------
list(kind = "cover",
  title = "¿Puede un mutante de albaricoquero comprar tiempo frente a la pérdida de frío invernal?",
  subtitle = "'Búlida Precoz' frente a 'Búlida' sobre la superficie cultivable de España, 1976-2100",
  meta = c("19th Plinius Conference on Mediterranean Risks · Sesión PL6 · Murcia",
           "Jueves 8 de octubre de 2026, 12:30-12:45",
           "Daniel González-Palazón · José A. Egea",
           "Documento de trabajo, generado el 2026-08-05")),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "1", title = "La pregunta",
  lead = "Un mutante somático con menos requerimiento de frío no resuelve el calentamiento, pero puede desplazar la fecha en que un cultivo deja de ser viable. La pregunta de este trabajo es dónde, y cuánto."),

list(kind = "slide", title = "Los frutales de hueso necesitan pasar frío, y cada vez lo pasan menos",
  body = c(
    "Un albaricoquero no florece porque llegue el calor. Florece porque antes ha acumulado suficiente frío invernal para salir de la dormición, y sólo entonces responde a las temperaturas cálidas. Si el invierno no entrega ese frío, la brotación se vuelve irregular, la floración se dispersa y el cuajado cae. No es un problema de rendimiento marginal: es la diferencia entre que una variedad sea cultivable en un sitio o no lo sea.",
    "La particularidad del sur peninsular es que ya se cultiva cerca del límite. En Murcia, que concentra la producción española de albaricoque, los inviernos entregan un frío que en muchos años apenas cubre el requerimiento de las variedades tradicionales. No hace falta un calentamiento espectacular para cruzar ese umbral.",
    "Y un albaricoquero vive entre 25 y 30 años. Quien planta hoy está apostando por el clima de 2050, no por el de ahora."),
  note = "Aquí no hace falta convencer a nadie del cambio climático. Lo que hay que dejar claro en 30 segundos es el mecanismo: frío primero, calor después, y si falta el primero el segundo no sirve."),

list(kind = "slide", title = "'Búlida Precoz': el mismo genotipo, catorce porciones menos de frío",
  body = c(
    "'Búlida' es la variedad histórica del albaricoque murciano. 'Búlida Precoz' es un mutante somático espontáneo suyo, es decir el mismo fondo genético con una mutación surgida en una yema, seleccionado porque florece antes.",
    "Ruiz et al. (2019) cuantificaron el requerimiento de frío de las dos durante tres años: 47,5 porciones de frío para 'Búlida' y 33,7 para el mutante, una diferencia de 13,8. Con un matiz que condiciona todo lo que viene después: los umbrales absolutos están mal determinados y la brecha está bien determinada. 'Búlida' osciló entre 40,9 y 51,1 según el año, con un error estándar de 3,3, mientras que la diferencia entre las dos se mantuvo entre 12,7 y 15,0, con un error estándar de 0,7, porque es una diferencia pareada dentro del mismo año.",
    "Esto significa que cualquier cifra basada en cruzar un umbral absoluto es frágil, y que cualquier cifra basada en la brecha entre variedades es sólida. La estrategia de la charla es apoyarse en lo segundo."),
  figs = FIG("fig3_case_study"),
  figcap = c("Case study del test-run de Murcia: las dos variedades frente al frío disponible."),
  note = "Este es el punto que hay que repetir si sale una pregunta sobre incertidumbre: los umbrales bailan, la brecha no."),

list(kind = "slide", title = "La pregunta, en una frase",
  body = c(
    "¿En qué parte de la superficie agrícola de España 'Búlida' dejará de cumplir su requerimiento de frío mientras 'Búlida Precoz' todavía lo cumple, y cómo cambia esa franja a lo largo del siglo bajo distintos escenarios de emisiones?",
    "Esa franja es la superficie que el mutante rescata. Si es grande, sustituir variedad es una estrategia de adaptación con recorrido. Si es pequeña, o si se cierra pronto, hay que buscar otra cosa."),
  note = "Frase de anclaje. Si alguien se pierde durante la charla, se vuelve aquí."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "2", title = "Los datos",
  lead = "Cuatro conjuntos, cada uno con un límite que condiciona el diseño. Ninguno cubre por sí solo lo que hace falta."),

list(kind = "slide", title = "Proyecciones: PNACC AR6 regionalizado a estaciones",
  body = c(
    "El Plan Nacional de Adaptación al Cambio Climático publica proyecciones CMIP6 regionalizadas estadísticamente sobre estaciones meteorológicas, con el método ESD-RegBA. Se usan 11 modelos climáticos, el experimento histórico y tres escenarios (SSP1-2.6, SSP2-4.5 y SSP3-7.0), en temperatura máxima y mínima diaria. Son 88 ficheros NetCDF y unos 15 GB, sobre 3460 estaciones.",
    "Se descarga por el servidor THREDDS de AdapteCCa, con URL predecible y sin credencial, en vez de por el formulario del portal. La razón fue práctica: permite bajar directamente en el HPC y evita subir 22 GB desde un portátil.",
    "SSP5-8.5 se excluye deliberadamente. La bibliografía reciente no lo considera un escenario plausible, y el abstract aceptado menciona RCP8.5, así que en la charla hay que declarar el cambio."),
  note = "Si preguntan por qué no 8.5: decisión tomada con Egea el 9 de julio. Falta la referencia concreta que él tenía en mente."),

list(kind = "slide", title = "Un hallazgo incómodo: las dos vías del portal no dan lo mismo",
  body = c(
    "Al auditar el script de descarga apareció algo que no estaba previsto. THREDDS y el formulario web del portal entregan el mismo producto científico (los mismos 11 modelos, el mismo método de regionalización, valores que correlan 0,9999916 con diferencia máxima de 0,05 °C) pero sobre distinto número de estaciones: THREDDS sirve 3460 y el formulario 3044.",
    "Se comprobó por aritmética sobre el fichero recibido en julio: el miembro correspondiente ocupa 289.309.352 bytes, y con 23.741 días y float32 esa cifra sólo cabe con 3044 estaciones; con 3460 el dato por sí solo necesitaría 39 MB más de los que mide el fichero entero.",
    "Consecuencia práctica: en Methods hay que declarar la vía. Quien intente reproducir estas cifras bajando por el formulario obtendrá 3044 estaciones y no dará con los mismos kilómetros cuadrados, y sin esa frase parecerá un error nuestro."),
  note = "Esto es de las cosas que hacen quedar bien en un turno de preguntas: demuestra que se ha mirado el dato de verdad."),

list(kind = "slide", title = "Observado: dos fuentes, ninguna completa",
  body = c(
    "El archivo observacional del PNACC cubre 3044 estaciones desde 1975 hasta 2020. Es completo y está controlado, pero se corta en 2020, que es la añada del producto y no una limitación de acceso.",
    "La API OpenData de AEMET llega hasta hoy, pero sólo expone el subconjunto climatológico de la red: de nuestras 3044 estaciones coinciden 703, y de esas 666 siguen reportando. Y es delgada hacia atrás: sólo 131 llegan a 1995, con un salto brusco en 2008-2009 donde arrancan 293 de golpe.",
    "Ninguna de las dos sirve sola. La combinación de ambas, una vez comprobado que miden lo mismo, es lo que produce un registro observado que llega a 2025. Eso se cuenta en la parte 8."),
  note = "La descarga de la API costó 28 horas más 84 minutos en dos pasadas, con un bug de reintentos por medio."),

list(kind = "slide", title = "Suelo: CORINE Land Cover 2018",
  body = c(
    "Para expresar los resultados en superficie y no en número de estaciones hace falta saber dónde hay cultivo. Se usa CORINE 2018 a 100 m, con las clases 211 a 244 excluyendo pastizal, lo que da 229.604 km² de suelo agrícola, el 46% de España y el 52,9% de Murcia.",
    "La decisión de reportar sobre superficie cultivable en vez de sobre porcentaje de estaciones no es cosmética. Las estaciones se agolpan en valles, aeropuertos y núcleos urbanos, y hay 151 localizaciones con dos estaciones distintas. Un recuento de puntos no estima territorio."),
  figs = FIG("fig16_spain_cropland_binary_100m", "fig1_contexto_suelo"),
  figcap = c("Suelo cultivable nacional según CORINE, resolución nativa de 100 m.",
             "Contexto de suelo del test-run de Murcia."),
  note = NULL),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "3", title = "El método",
  lead = "El modelo dinámico de Fishman no es un índice de temperatura, y esa confusión es la fuente de la mitad de los malentendidos sobre acumulación de frío."),

list(kind = "gadget", id = "response", title = "El modelo dinámico tiene un óptimo, y no está en el cero",
  body = c(
    "La acumulación de frío no es monótona en la temperatura. El modelo dinámico describe un proceso de dos pasos donde se forma un precursor termolábil que puede destruirse si sube la temperatura, y sólo al acumularse suficiente se convierte irreversiblemente en una porción de frío.",
    "El resultado es una curva con un óptimo alrededor de 8 °C. Por encima de 14 °C no se acumula nada, cosa que todo el mundo espera. Pero por debajo de -4 °C tampoco, y eso sorprende a casi todos.",
    "Mueve el deslizador para verlo. La consecuencia práctica es que una ola de frío extrema no aporta frío fisiológico: la borrasca Filomena de enero de 2021, que AEMET describió como la segunda ola de frío más importante del siglo, no contribuyó a la acumulación de ese invierno."),
  note = "Esto responde de antemano a la objeción más probable del público: 'pero si el invierno de Filomena fue frío'."),

list(kind = "slide", title = "La parametrización de 1987 no es un detalle técnico",
  body = c(
    "El modelo dinámico tiene dos parametrizaciones publicadas, la de Fishman et al. 1987 y una revisión de 1988. El paquete chillR implementa la de 1988 por defecto en su función Dynamic_Model. El código que usa este proyecto, escrito por J.A. Egea, implementa la de 1987.",
    "La diferencia no es pequeña. Medida sobre la serie de Cieza, las dos parametrizaciones sobre exactamente los mismos datos se llevan 6,94 porciones de media, y el desfase varía entre 1,4 y 13,6 según la temporada. Son la mitad de los 13,8 que separan a las dos variedades.",
    "Lo decisivo es que los requerimientos también hay que medirlos con la misma escala. Si la oferta se calculara con 1987 y la demanda con 1988, se estarían comparando dos reglas distintas. La sección de métodos de Ruiz et al. 2019 cita la parametrización de 1987, que es lo que sostiene la elección actual. Pero hay una contradicción abierta que se cuenta en la parte 9."),
  figs = FIG("fig26_02_parametrisation_gap"),
  figcap = c("Las dos parametrizaciones sobre los mismos datos de Cieza. El desfase crece en los inviernos suaves, que son justamente los que deciden la viabilidad."),
  note = NULL),

list(kind = "slide", title = "Safe Winter Chill: el frío que se supera nueve de cada diez inviernos",
  body = c(
    "La acumulación se calcula sobre la temporada que va del 1 de noviembre al 28 de febrero, descartando temporadas con menos del 85% de datos. Eso da una porción de frío por invierno y por estación.",
    "El indicador que se reporta no es la media sino el percentil 10 entre temporadas, el llamado Safe Winter Chill. La razón es agronómica: a un fruticultor no le sirve saber que en un año medio hay frío suficiente, porque el año malo le arruina la cosecha igual. El P10 es el frío con el que puede contar nueve de cada diez inviernos.",
    "La contrapartida es que el P10 necesita bastantes temporadas para ser un decil de verdad. Con 12 temporadas el P10 cae prácticamente sobre el invierno más frío de la muestra, y eso obliga a tener cuidado al comparar series de distinta longitud. Es la razón de que la comparación entre las dos fuentes observadas se haga temporada a temporada y no sobre el agregado."),
  note = NULL),

list(kind = "slide", title = "De estaciones a superficie: interpolación IDW y máscara de 50 km",
  body = c(
    "El frío se calcula en estaciones, pero la pregunta es sobre territorio. La interpolación replica el método publicado por Egea et al. 2022: distancia inversa ponderada con potencia 2 y máscara a 50 km de la estación más cercana, sobre rejilla de 1 km.",
    "Elegir el método del coautor no es sólo diplomacia. Es un método publicado y revisado para este mismo problema, y aquí está mejor sostenido: aquel trabajo interpolaba desde 270 estaciones y este desde 3460.",
    "La superficie resultante se cruza con CORINE y cada celda se clasifica según qué variedades puede sostener. Cada celda contribuye con su fracción de suelo cultivable, no como celda entera, que es lo que convierte una clasificación por celda en una estadística de superficie."),
  figs = FIG("fig21_02_swc_surface_presente_present"),
  figcap = c("Superficie de Safe Winter Chill interpolada para la línea base del modelo, 1995-2020."),
  note = NULL),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "4", title = "Las ventanas temporales",
  lead = "Elegir mal los periodos de comparación puede cancelar por construcción una parte del cambio que se quiere medir. Aquí se explica por qué son estos y no otros."),

list(kind = "gadget", id = "timeline", title = "Cuatro ventanas que teselan el siglo sin solaparse",
  body = c(
    "El diseño original analizaba el histórico 1985-2014 y saltaba a 2041-2070. Eso dejaba 26 años descargados y sin analizar, de 2015 a 2040, justo el horizonte que le importa a quien planta hoy. La rejilla actual lo cierra.",
    "La línea base es 1995-2020 y no 1995-2025, aunque los datos llegan hasta 2100 y calcularla hasta 2025 no costaría nada. La razón es el solape: si la base fuera 1995-2025 y el primer futuro 2021-2040, compartirían cinco años, y al diferenciar uno de otro una cuarta parte del cambio se cancelaría sola, haciendo que el futuro próximo pareciera artificialmente plano.",
    "Hay además una costura obligatoria en 2014/2015. El experimento histórico de CMIP6 termina el 31 de diciembre de 2014 por diseño y los escenarios arrancan el 1 de enero de 2015, así que cualquier ventana que cruce esa frontera no existe en un solo fichero y hay que ensamblarla."),
  note = "El gadget muestra qué fuente cubre cada tramo y dónde están las costuras."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "5", title = "El flujo de trabajo",
  lead = "Veintidós scripts, dos máquinas y una regla: ninguna cifra que se proyecte puede vivir fuera de una tabla."),

list(kind = "gadget", id = "workflow", title = "Qué alimenta a qué",
  body = c(
    "El cómputo pesado corre en el HPC Ladon: la descarga de los 88 NetCDF y el motor nacional de frío, que lee los ficheros directamente, recorta a la ventana pedida y paraleliza por estación. La corrida nacional completa fueron unas 23 horas.",
    "Todo lo demás corre en local: la fusión de tablas, la interpolación y el cruce con CORINE, las figuras, y toda la rama del observado reciente.",
    "El motor nacional lleva protecciones que nacieron de fallos reales. Escribe un checkpoint por combinación de escenario y modelo en cuanto termina, con escritura atómica, así que un corte cuesta como mucho lo que estuviera en vuelo. Y lleva un centinela por estación: si un worker muere, la función de paralelización rellena su tramo con nulos sin dar error, y sin el centinela el resultado se guardaría truncado y el reintento lo daría por bueno para siempre."),
  note = "Aquí es donde se explica que esto no es un notebook improvisado."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "6", title = "Resultado principal: la superficie que el mutante rescata",
  lead = "De los 229.604 km² de suelo agrícola de España, cuánto pierde 'Búlida' y cuánto de esa pérdida recupera el mutante."),

list(kind = "slide", title = "El titular",
  body = c(
    "Bajo SSP3-7.0 a fin de siglo, 'Búlida' deja de ser viable en 45.089 km² de suelo agrícola. De esa pérdida, 'Búlida Precoz' rescata 23.302 km², es decir el 51,7%.",
    "Según el modelo climático que se mire, la fracción rescatada va del 32,6% al 66,1%, y ninguno de los once baja de un tercio. Esa es la cifra más robusta del trabajo: no depende del denominador que se elija ni del valor exacto de los umbrales, porque descansa en la brecha entre variedades, que es lo que está bien determinado.",
    "Bajo escenarios suaves el mutante rescata casi toda la pérdida, un 89,3% en SSP1-2.6. Bajo el severo sólo la mitad, porque a fin de siglo el frío cae por debajo incluso de las 33,7 porciones que necesita el mutante. Compra tiempo, no inmunidad."),
  figs = FIG("fig22_viability_bars"),
  figcap = c("Las quince situaciones analizadas, en porcentaje de superficie cultivable."),
  note = "Si sólo queda tiempo para una diapositiva de resultados, es esta."),

list(kind = "slide", title = "Cómo evoluciona, situación a situación",
  body = c(
    "Hasta mediados de siglo la pérdida total es marginal, por debajo del 1,3% de la superficie, y lo que crece es la franja del mutante. Es decir, durante décadas el problema tiene solución varietal.",
    "En el peor caso a fin de siglo la tierra que no sirve para ninguna de las dos salta al 9,5%, y ahí el mutante deja de compensar. El mensaje agronómico es que la sustitución varietal es una estrategia con fecha de caducidad, no una solución."),
  table = "viability",
  note = NULL),

list(kind = "gallery", title = "Los quince mapas de viabilidad",
  body = c("Un mapa por situación, en orden cronológico. Azul donde las dos variedades siguen siendo viables, naranja donde sólo lo es el mutante, rojo donde ninguna. Sólo se pinta suelo cultivable."),
  figs = FIG("fig20_01_viability_observaciones_present", "fig20_02_viability_presente_present",
             "fig20_03_viability_presente_current", "fig20_04_viability_observaciones_obsref",
             "fig20_05_viability_historical_ref", "fig20_06_viability_pooled_nearterm",
             "fig20_07_viability_ssp126_nearterm", "fig20_08_viability_ssp245_nearterm",
             "fig20_09_viability_ssp370_nearterm", "fig20_10_viability_ssp126_near",
             "fig20_11_viability_ssp245_near", "fig20_12_viability_ssp370_near",
             "fig20_13_viability_ssp126_far", "fig20_14_viability_ssp245_far",
             "fig20_15_viability_ssp370_far")),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "7", title = "Las próximas dos décadas ya están decididas",
  lead = "Un resultado que no se buscaba y que tiene fuerza propia."),

list(kind = "slide", title = "Antes de 2040 los escenarios son indistinguibles",
  body = c(
    "En la ventana 2021-2040 la diferencia entre el escenario optimista y el pesimista es de 0,62 porciones de frío, mientras que la dispersión entre los once modelos climáticos es de 8,91. La incertidumbre de modelo es catorce veces mayor que la señal de escenario.",
    "Y hay un detalle que lo remata: en el 62% de las estaciones el escenario pesimista devuelve más frío que el optimista. Eso no es una señal débil, es ruido.",
    "Por eso ese horizonte se presenta en un panel único agregado y no en tres. Tres paneles invitarían a leer que SSP3-7.0 es mejor, que sería falso. A fin de siglo sí se separan, con 8,61 porciones entre extremos, y ahí se muestran por separado.",
    "La lectura para el público es directa: lo que ocurra en el frío invernal español en las próximas dos décadas ya está comprometido, elijas el escenario que elijas. Las decisiones de mitigación de hoy se notan a partir de 2050."),
  figs = FIG("fig20_06_viability_pooled_nearterm"),
  figcap = c("Panel agregado 2021-2040, los tres escenarios juntos."),
  note = "Este resultado gusta mucho en congresos de riesgo climático. Merece su minuto."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "8", title = "El registro observado, y una sorpresa",
  lead = "Lo que empezó como una comprobación de consistencia acabó destapando el quinquenio más pobre en frío de todo el registro."),

list(kind = "slide", title = "Primero había que demostrar que las dos fuentes miden lo mismo",
  body = c(
    "El archivo llega a 2020 y la API llega a 2025, así que para tener un observado hasta hoy hay que empalmarlos, y para empalmarlos hay que demostrar que son intercambiables.",
    "La comparación se hace pareada, temporada a temporada, sobre los 8.979 inviernos que ambas fuentes reportan, con el mismo filtro de completitud aplicado a la vez a las dos. Comparar directamente el Safe Winter Chill no habría valido, porque el P10 de una estación con 12 temporadas está casi en su invierno más frío mientras que el de una con 26 es un decil de verdad: la diferencia mediría longitud de serie tanto como clima.",
    "El resultado: en temporadas individuales el sesgo mediano es exactamente cero, aunque hay dispersión. Y en Safe Winter Chill sobre las temporadas comunes, el sesgo es de 0,13 porciones con una correlación espacial de 0,987. Donde importa, son el mismo instrumento."),
  figs = FIG("fig23_02_api_vs_archive_swc", "fig23_01_api_vs_archive_seasons"),
  figcap = c("Safe Winter Chill sobre las temporadas que comparten las dos fuentes.",
             "Las 8.979 temporadas pareadas, una a una."),
  note = NULL),

list(kind = "slide", title = "Cincuenta inviernos sin tendencia, y luego cinco que se salen",
  body = c(
    "Con la línea base larga, de 1976 a 2020, el frío invernal español no tiene tendencia: la pendiente es de -0,003 porciones por año con p = 0,90 y R² prácticamente cero. Cuarenta y cinco años planos.",
    "Los inviernos de 2021 a 2025 promedian 70,3 porciones frente a 74,0 de esa línea base. Son 3,65 porciones menos, es decir 1,95 desviaciones típicas. El invierno de 2024 es el de menos frío de los cincuenta del registro, y cuatro de los cinco últimos están entre los seis más suaves.",
    "Cada temporada se expresa como desviación respecto a la media de su propia estación, porque no todas reportan los cinco inviernos recientes y una media simple mezclaría cambio de red con cambio de clima. Las tres formas de calcularlo (media simple, panel equilibrado y anomalía por estación) coinciden dentro de una décima de porción, así que el reparto de estaciones nunca estuvo moviendo el resultado.",
    "La prueba que más convence es la de bloques. Dentro de la línea base caben 41 tramos de cinco años consecutivos, y ninguno baja hasta donde está el reciente: el peor histórico es 1982-1986 con 72,73 porciones, y 2021-2025 está 2,4 por debajo de eso."),
  figs = FIG("fig25_01_observed_chill_series_1976_2025", "fig25_02_running5_blocks"),
  figcap = c("La serie completa en anomalías respecto a la media 1976-2020.",
             "Los 41 bloques quinquenales de la línea base, contra el de 2021-2025."),
  note = "Esta es la diapositiva nueva respecto al abstract aceptado. Vale un minuto largo."),

list(kind = "slide", title = "Las objeciones, una a una",
  body = c(
    "¿Es una racha casual? La autocorrelación de la serie anual es prácticamente nula, así que tratar los inviernos como intercambiables es defendible, y bajo ese supuesto la probabilidad de que cuatro de los cinco últimos caigan entre los diez más suaves de cincuenta es de 0,004.",
    "¿Es un artefacto de cambiar de fuente en 2021? La API lee 0,13 porciones por encima del archivo en las temporadas que comparten, así que el cambio de fuente empuja hacia arriba y lo que se observa es una caída. El sesgo trabaja en contra del hallazgo.",
    "¿Es que las 665 estaciones con dato reciente son raras? Su serie anual correla 0,98 con la de las 3044 del archivo completo y tiene variabilidad parecida.",
    "Y un matiz honesto que conviene decir antes de que lo digan: la media móvil de cinco años viene bajando desde 2005, de 75,5 a 72,9. La tendencia lineal de 45 años sale plana porque el tramo anterior subía. El bloque reciente acentúa un declive que ya venía, no aparece de la nada."),
  note = "Si sólo hay tiempo para una objeción, la del cambio de fuente, porque es la que un revisor plantearía."),

list(kind = "slide", title = "La comprobación que lo cierra: un instrumento que no es de AEMET",
  body = c(
    "Todo lo anterior sale de una sola red. Si AEMET hubiera cambiado algo en su procesado hacia 2021, se vería exactamente así.",
    "El repositorio de Muñoz-Morales et al. (2025) publica la serie diaria del huerto experimental del CEBAS en Cieza, de 2011 a 2025, 5.214 días sin un solo hueco, medida con instrumentación propia. Calculando su frío con el mismo método, la anomalía reciente es de 1,66 desviaciones típicas. Dos estaciones AEMET cercanas con serie estable dan 1,75 y 2,37. La media nacional da 1,95.",
    "En valor absoluto las anomalías locales son mucho mayores, porque Murcia es zona de frío bajo donde el modelo es más sensible y una estación sola tiene más varianza. Pero en desviaciones típicas las cuatro coinciden, y una de ellas no es de AEMET."),
  figs = FIG("fig26_01_independent_records"),
  figcap = c("Cuatro registros de dos redes distintas, estandarizados contra su propia línea base."),
  note = "Las cuatro series se mueven juntas invierno a invierno, incluido el bache de 2016 y el repunte de 2022. Eso es lo que hay que señalar."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "9", title = "Lo que podría estar mal",
  lead = "La incertidumbre dominante no está en el clima ni en la interpolación. Está en dos números medidos por otros."),

list(kind = "gadget", id = "threshold", title = "Mueve los umbrales y mira qué pasa",
  body = c(
    "Todo el resultado descansa en dos requerimientos de frío: 47,5 y 33,7 porciones. Cada uno con un error estándar de 3,3, que es grande.",
    "Y hay una segunda fuente de duda. El código publicado junto a Muñoz-Morales et al. (2025) calcula el frío con la función por defecto de chillR, que lleva los parámetros de 1988, mientras el texto cita la parametrización de 1987. Conviene por tanto confirmar con los autores qué parametrización se usó al cuantificar los requerimientos, en vez de inferirla de la cita. Si estuvieran en la escala de 1988, habría que subirlos unas 7 porciones para compararlos con nuestra oferta.",
    "Los deslizadores recorren el barrido completo calculado sobre las superficies reales. Con los umbrales 7 porciones más altos y SSP3-7.0 a fin de siglo, la banda del mutante pasa de 23.302 a 37.009 km², un 59% más, y la superficie perdida del todo crece un 41%.",
    "La conclusión importante es la dirección: el desplazamiento no destruye el mensaje, lo amplifica por los dos lados. Menos superficie donde valen las dos, más banda de rescate y más tierra perdida. La incertidumbre mueve mucho las cifras y no cambia la conclusión cualitativa."),
  note = "Si Egea pregunta por la parametrización, esta es la respuesta: medida, cuantificada en km², y con la dirección del efecto explicada."),

list(kind = "slide", title = "Las otras limitaciones, dichas antes de que las digan",
  body = c(
    "La validación del modelo contra el observado da un sesgo de 0,45 porciones y una correlación de 0,984, lo que justifica no aplicar corrección de sesgo. Pero ESD-RegBA se calibró contra estas mismas estaciones, así que no es validación independiente y hay que declararlo.",
    "El ensemble se resume con la mediana de los once modelos para poder dibujar mapas, y eso esconde una dispersión enorme: 24,8 porciones entre modelos en una estación típica, casi el doble de la brecha entre variedades. En la ventana del mutante sólo el 0,43% de las estaciones tienen ocho de once modelos de acuerdo, y ninguna tiene unanimidad. La mediana fabrica un mapa nítido que los modelos no firman.",
    "El registro extendido hasta 2025 descansa en 666 estaciones y no en 3044, y el desfase medido entre las dos fuentes observadas sólo pudo comprobarse donde se solapan, no en el tramo reciente."),
  note = "Decir esto en la charla desarma preguntas y da credibilidad. No es autoflagelación, es control del relato."),

# ---------------------------------------------------------------------------------------------
list(kind = "section", n = "10", title = "Qué queda",
  lead = "Estado a 5 de agosto de 2026, a dos meses de la charla."),

list(kind = "slide", title = "Pendiente",
  body = c(
    "Resolver la pregunta de la parametrización con David Ruiz. Es la incertidumbre mayor y ahora se le puede preguntar señalando un artefacto concreto.",
    "Contestar a Egea, pendiente desde el 15 de julio, con cuatro de sus preguntas ya resueltas con números: criterio de suelo, corrección de sesgo, tratamiento del ensemble y peso de los años recientes.",
    "Una prueba de sensibilidad de los kilómetros cuadrados restringida a las 3044 estaciones comunes, para cerrar el asunto de las dos vías de descarga.",
    "Congelar la versión de los NetCDF con sus checksums, que hoy no está registrada.",
    "Y montar la charla propiamente dicha: doce minutos obligan a dejar fuera la mayor parte de este material."),
  note = NULL),

list(kind = "gallery", title = "Material de apoyo: superficies de frío interpoladas",
  body = c("La superficie que hay detrás de cada mapa de viabilidad, en porciones de frío."),
  figs = FIG("fig21_01_swc_surface_observaciones_present", "fig21_02_swc_surface_presente_present",
             "fig21_03_swc_surface_presente_current", "fig21_04_swc_surface_observaciones_obsref",
             "fig21_05_swc_surface_historical_ref", "fig21_06_swc_surface_pooled_nearterm",
             "fig21_07_swc_surface_ssp126_nearterm", "fig21_08_swc_surface_ssp245_nearterm",
             "fig21_09_swc_surface_ssp370_nearterm", "fig21_10_swc_surface_ssp126_near",
             "fig21_11_swc_surface_ssp245_near", "fig21_12_swc_surface_ssp370_near",
             "fig21_13_swc_surface_ssp126_far", "fig21_14_swc_surface_ssp245_far",
             "fig21_15_swc_surface_ssp370_far")),

list(kind = "gallery", title = "Material de apoyo: suelo cultivable y test-run de Murcia",
  body = c("Figuras del trabajo previo sobre criterio de suelo y del test-run regional que precedió al análisis nacional."),
  figs = FIG("fig2_swc_ensemble", "fig4_distribucion_swc", "fig6_soil_criteria_compare",
             "fig8_spain_cropland_density_stations", "fig9_murcia_cropland_density_stations",
             "fig10_spain_cropland_density_500m", "fig11_murcia_cropland_density_500m",
             "fig12_spain_cropland_binary_500m", "fig13_spain_cropland_binary_500m_stations",
             "fig14_murcia_cropland_binary_500m", "fig15_murcia_cropland_binary_500m_stations",
             "fig17_spain_cropland_binary_100m_stations", "fig18_murcia_cropland_binary_100m",
             "fig19_murcia_cropland_binary_100m_stations",
             "fig23_03_bias_vs_completeness", "fig24_01_swc_shift_1995_2025"))
)
