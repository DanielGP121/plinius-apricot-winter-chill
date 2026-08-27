---
title: "Assets visuales de la charla Plinius (v5)"
created: 2026-08-26
updated: 2026-08-26
tags: [plinius, egu, congreso, assets, figuras, licencias]
status: live
summary: "Inventario de los 12 assets visuales (logos, figuras de la historia, esquemas y fotografía) que consume la charla Plinius v5, con dimensiones, transparencia, ruta de origen exacta y estado de licencia de cada uno."
---

# Assets visuales de la charla Plinius (v5)

Inventario de lo que hay en esta carpeta. Todo procede del proyecto `Bulida_Precoz/`, salvo las dos
fotografías, que vienen de Wikimedia a través del material de la charla SECH.

## Inventario

| Fichero | Dimensiones (px) | Transparencia | Ruta de origen | Licencia / procedencia |
|---|---|---|---|---|
| `logo_eead_csic.png` | 1809 × 463 | Sí (alfa real) | `Bulida_Precoz/02_wiki/sech_2026/figures/icons/eead_1.png` | Logo institucional EEAD-CSIC. Sin fichero de créditos en la carpeta de origen: **procedencia por confirmar** |
| `logo_cebas_csic.jpg` | 208 × 117 | No | `Bulida_Precoz/02_wiki/sech_2026/figures/icons/cebas_2.jpg` | Logo institucional CEBAS-CSIC. Es la única variante que lleva el escudo del CSIC. **Procedencia por confirmar** |
| `logo_cebas_square.jpg` | 400 × 400 | No | `Bulida_Precoz/02_wiki/sech_2026/figures/icons/cebas_1.jpg` | Logo CEBAS-CSIC en formato cuadrado, más resolución que el anterior pero sin escudo CSIC. **Procedencia por confirmar** |
| `logo_ue_feder.png` | 1000 × 303 | Sí (alfa real) | `Bulida_Precoz/02_wiki/sech_2026/figures/icons/feder_1.png` | Emblema UE / FEDER. **Procedencia por confirmar** |
| `logo_miciu_aei.png` | 1144 × 211 | No | `Bulida_Precoz/02_wiki/sech_2026/poster_gwas/figuras/logos/Sin título.png` | Gobierno de España, Ministerio de Ciencia, Innovación y Universidades más Agencia Estatal de Investigación. **Procedencia por confirmar** |
| `diagram_budsport.png` | 2816 × 1536 | Sí (alfa real) | `Bulida_Precoz/02_wiki/sech_2026/figures/figuras_generadas/figura_budsport_explanation_nobg.png` | Ilustración conceptual de mutación de yema, no es fotografía ni figura de datos. El material de la charla SECH v8 la registra como imagen sintética de herramienta externa, así que la **licencia de difusión está por confirmar** antes de proyectarla en público |
| `figure1_composite_en.png` | 2400 × 1177 | No | `Bulida_Precoz/00_manuscript/figures/figuras_finales/Figure_1_composite_EN.png` | Figura propia del manuscrito (`@fig:phenotype`) |
| `figure2_phenotype.png` | 2034 × 625 | No | `Bulida_Precoz/00_manuscript/figures/figuras_finales/Figure_2_phenotype.png` | Figura propia. Copia de `figuras_preprint/figure_1.png` del preprint del TFM (2025) |
| `schema_dormancy_cycle.png` | 2750 × 896 | Sí (alfa real) | `Bulida_Precoz/02_wiki/sech_2026/figures/figuras_generadas/s_dormancy_cycle.png` | Esquema propio. SVG de autoría propia rasterizado con `render_figure.sh` del proyecto |
| `schema_chill_portions.png` | 2750 × 896 | Sí (alfa real) | `Bulida_Precoz/02_wiki/sech_2026/figures/figuras_generadas/s_chill_cp.png` | Esquema propio. Mismo origen y mismo procedimiento que el anterior |
| `photo_orchard_bloom.jpg` | 2268 × 1512 | No | `Bulida_Precoz/02_wiki/sech_2026/comunicacion_bulida_precoz/v5/figures_web/apricot_orchard_PD.jpg` | Dominio público, cortesía de Bautsch (Wikimedia), según la tabla de créditos §2.2 de `v5/_specs/build_v5_2_spec.md` |
| `photo_dormant_buds.jpg` | 2600 × 2070 | No | `Bulida_Precoz/02_wiki/sech_2026/comunicacion_bulida_precoz/v5/figures_web/apricot_buds_ccby.jpg` | CC BY 4.0, Anna.Massini (Wikimedia), según la misma tabla de créditos. **Exige crédito visible** en la diapositiva donde aparezca |

## Notas de proceso

Los dos esquemas se copiaron tal cual desde el `.png` que ya existía junto al `.svg` en
`figuras_generadas/`. Esos ficheros vienen a 2750 px de lado largo con fondo transparente, por encima
de los 2400 px que pedía el encargo, así que no hizo falta volver a rasterizar el SVG. Conviene saberlo
porque en este equipo no hay ningún renderizador de SVG instalado (ni Inkscape, ni `cairosvg`, ni
ImageMagick, ni `rsvg-convert`), de modo que regenerarlos aquí no sería posible sin instalar algo antes.

`photo_dormant_buds.jpg` es el único fichero reescalado: el original venía a 3352 × 2669 px y se bajó a
2600 × 2070 px, que es de sobra para una diapositiva de 13,33 pulgadas de ancho. El resto se copió
sin tocar un solo píxel. La foto del huerto ya entraba por debajo del límite y quedó intacta.

Los cinco logos se conservan en su formato original, sin reencodar, para no degradar los bordes.
De `logo_cebas_csic.jpg` y `logo_cebas_square.jpg` se guardan las dos variantes a propósito: la primera
es la que lleva el escudo del CSIC y la segunda tiene más resolución, así que la elección depende de si
la diapositiva necesita el escudo o el tamaño.

## Por qué estos ficheros están versionados aquí

Ninguno de estos assets se puede regenerar con los scripts de este repositorio. Son material externo
(logos institucionales, fotografía de Wikimedia) o salidas de otro proyecto del vault (`Bulida_Precoz/`),
y llegan aquí por copia. Esa es la razón de que vivan en `assets/`, bajo control de versiones, y no en
`02_outputs/`, que está reservado a lo que sí reproduce el pipeline a partir de los datos de entrada.
Si se borrasen, no habría forma de recuperarlos ejecutando nada de este repositorio.

## Pendiente

Queda por cerrar la procedencia de los cinco logos y la licencia de difusión de `diagram_budsport.png`.
Los logos institucionales suelen tener condiciones de uso propias de cada organismo y aquí se han
heredado del material de la charla SECH sin fichero de créditos que los acompañe.
