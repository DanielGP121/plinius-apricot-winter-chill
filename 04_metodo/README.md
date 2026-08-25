# 04_metodo — el libro de método

Memoria de método del estudio, en quince capítulos. Escrita para que un lector pueda seguir la
cadena entera sin haber visto el código.

## Salidas

| Fichero | Qué es |
| --- | --- |
| `_book/index.html` | El libro navegable, con barra lateral y buscador. Es el que lleva las figuras a tamaño completo. |
| `_book/metodo_bulida.pdf` | El mismo contenido en un solo fichero, para adjuntar a un correo o imprimir y anotar. |

Para mandarlo por correo, el PDF. Para consultarlo, la web: se abre con doble clic en
`_book/index.html`, no necesita servidor.

## Regenerar

```bash
cd 04_metodo
Rscript -e "bookdown::render_book('.', 'bookdown::bs4_book')"   # web
Rscript -e "bookdown::render_book('.', 'bookdown::pdf_book')"   # PDF
```

Necesita que el pipeline haya corrido antes: el libro lee las tablas de `02_outputs/` y se niega a
compilar si falta alguna, en vez de rellenar el hueco. Ese es el punto.

## Cómo está montado

`_common.R` es el corazón y conviene leerlo antes de tocar nada. Define tres cosas:

- **`cifra()` y `metrica()`** leen valores de las tablas canónicas. **Ninguna cifra del libro está
  escrita a mano**; todas se resuelven al compilar. Si el pipeline se reejecuta y una cambia, cambia
  en el texto sola.
- **`figura()`** copia la imagen desde `02_outputs/figures_chill/` a `figuras/`, de modo que la
  carpeta `_book/` es autocontenida y se puede comprimir y enviar.
- **`codigo()`** extrae un fragmento del script real, por marcador de sección (`# § N —`) o por
  nombre de función. No hay ni una línea de código copiada a mano en el libro.

Los capítulos van en `NN-nombre.Rmd` y su orden está en `_bookdown.yml`.

## Trampas

- **Los pies de figura no pasan por pandoc.** Bookdown los mete tal cual en `\caption{}`, así que un
  guión bajo o un `%` rompen el PDF. `pie()` ya escapa lo necesario según la salida; si escribes un
  pie a mano, no lo hará por ti.
- **`microtype` no está en la instalación de TeX de este equipo** y por eso no se carga en
  `preamble.tex`. Añadirlo requeriría actualizar TeX Live entero.
- **`babel` lo carga pandoc** desde `lang: es`. Declararlo otra vez en el preámbulo es un choque de
  opciones que tumba la compilación.
- Las advertencias de tipo `The label(s) X not found` al compilar significan que un capítulo
  referencia otro que aún no existe en `_bookdown.yml`. Con los quince capítulos no debe salir
  ninguna.
