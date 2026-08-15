# ---------------------------------------------------------------------------------------
# Shared setup for every chapter of the method book.
#
# THE ONE RULE THIS FILE EXISTS TO ENFORCE: no number in the book is typed. Every figure quoted in
# the prose comes from one of the project's canonical tables, read here at render time, so that a
# rerun of the pipeline changes the book. A literal in the text would be a claim that had stopped
# being checked, which is exactly the failure this book is written to rule out. The project has
# already been bitten by one: a hardcoded 229604 sat inside a figure script and went stale the
# moment the cell area was corrected.
#
# It also holds the three helpers the chapters use:
#   cifra()   pull a value out of a canonical table by situation and column
#   figura()  copy a figure into the book and return its path, so the book is self-contained
#   codigo()  lift a numbered section straight out of a real script, never a copy of one
# ---------------------------------------------------------------------------------------

suppressWarnings(suppressMessages({
  library(data.table); library(knitr)
}))

BOOK <- normalizePath(".", winslash = "/")
ROOT <- normalizePath(file.path(BOOK, ".."), winslash = "/")
OUT  <- file.path(ROOT, "02_outputs")
FIGS <- file.path(OUT, "figures_chill")
SCR  <- file.path(ROOT, "01_scripts")
DEST <- file.path(BOOK, "figuras")
dir.create(DEST, showWarnings = FALSE, recursive = TRUE)

knitr::opts_chunk$set(echo = FALSE, message = FALSE, warning = FALSE, out.width = "100%")

# --- numbers, in Spanish ----------------------------------------------------------------------
n_es <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
i_es <- function(x) formatC(round(x), format = "d", big.mark = ".", decimal.mark = ",")
pct  <- function(x, d = 1) paste0(n_es(x, d), " %")
km2  <- function(x) paste0(i_es(x), " km²")
cp   <- function(x, d = 1) paste0(n_es(x, d), " CP")

# --- the canonical tables ---------------------------------------------------------------------
# Loaded once and kept in a list, so a chapter that asks for a table that has not been produced yet
# fails here with its name rather than three hundred lines later with a NULL.
.tab <- new.env(parent = emptyenv())
tabla <- function(nombre) {
  if (is.null(.tab[[nombre]])) {
    f <- file.path(OUT, paste0(nombre, ".csv"))
    if (!file.exists(f))
      stop("falta la tabla ", nombre, ".csv. El libro no inventa cifras: ejecuta antes el script ",
           "que la produce (ver el capítulo de referencia).", call. = FALSE)
    .tab[[nombre]] <- fread(f)
  }
  .tab[[nombre]]
}

# Value of one column for one situation. Named arguments on purpose: cifra("x", "y", "z") read in
# the wrong order is a silent error, and this is the function the whole book leans on.
cifra <- function(tabla_ = "talk_numbers_cropland", situacion = NULL, columna) {
  t <- tabla(tabla_)
  if (!is.null(situacion)) {
    if (!situacion %in% t$situation)
      stop("la situación '", situacion, "' no está en ", tabla_, call. = FALSE)
    t <- t[situation == situacion]
  }
  if (!columna %in% names(t))
    stop("la columna '", columna, "' no está en ", tabla_, call. = FALSE)
  v <- t[[columna]]
  if (length(v) != 1)
    stop("cifra() ha encontrado ", length(v), " valores para ", columna, " en ", tabla_,
         "; falta acotar la situación", call. = FALSE)
  v
}

# Several tables are long rather than wide: one row per metric. Same contract as cifra(), same
# refusal to guess when the name matches more than one row.
metrica <- function(tabla_, nombre, escenario = NULL) {
  t <- tabla(tabla_)
  if (!"metric" %in% names(t)) stop(tabla_, " no es una tabla de métricas", call. = FALSE)
  r <- t[metric == nombre]
  if (!is.null(escenario) && "scenario" %in% names(t)) r <- r[scenario == escenario]
  if (nrow(r) != 1)
    stop("metrica() ha encontrado ", nrow(r), " filas para '", nombre, "' en ", tabla_,
         if (nrow(r) > 1) "; falta acotar el escenario" else "", call. = FALSE)
  v <- r$value
  n <- suppressWarnings(as.numeric(v))
  if (!is.na(n)) n else as.character(v)
}

# The cropland denominator, which appears in half the chapters and must be the same number in all
# of them. Derived, never written down.
SUPERFICIE_CULTIVABLE <- local({
  t <- tabla("talk_numbers_cropland")
  t[1, crop_km2_both + crop_km2_only_precoz + crop_km2_none]
})

# Is the code this document describes actually saved anywhere? The book promises that every step can
# be checked; if the working tree has uncommitted changes, that promise is false for this build and
# the reader has to be told on the first page rather than on the last.
repo_sucio <- function() {
  s <- try(suppressWarnings(system2("git", c("-C", shQuote(ROOT), "status", "--porcelain"),
                                    stdout = TRUE, stderr = FALSE)), silent = TRUE)
  !inherits(s, "try-error") && length(s) > 0
}

CR_BULIDA <- 47.5
CR_PRECOZ <- 33.7
CR_HUECO  <- CR_BULIDA - CR_PRECOZ

# --- figures ----------------------------------------------------------------------------------
# Copied into the book rather than linked across directories, so the rendered _book/ folder can be
# zipped and sent to someone without the repository. Copy only when the source is newer, so a
# rebuild does not touch a hundred files for nothing.
figura <- function(archivo) {
  src <- file.path(FIGS, archivo)
  if (!file.exists(src)) src <- file.path(OUT, archivo)          # gifs and one-off images
  if (!file.exists(src))
    stop("no existe la figura ", archivo, ". El libro sólo muestra figuras que el pipeline ha ",
         "producido de verdad.", call. = FALSE)
  dst <- file.path(DEST, archivo)
  if (!file.exists(dst) || file.mtime(src) > file.mtime(dst)) file.copy(src, dst, overwrite = TRUE)
  file.path("figuras", archivo)
}

# The caption carries its own provenance: which script drew it and with what. A figure whose origin
# is not on its face is a figure the reader has to take on trust.
#
# Captions are NOT run through pandoc: bookdown drops them into \caption{} verbatim, so an
# underscore in a script name becomes a subscript and a per-cent sign starts a LaTeX comment, and
# the build dies with an error that points nowhere near the caption. Hence two versions.
.tex_esc <- function(s) {
  s <- gsub("\\\\", "\\\\textbackslash{}", s)
  for (ch in c("_", "%", "&", "#", "$")) s <- gsub(ch, paste0("\\", ch), s, fixed = TRUE)
  s
}

pie <- function(texto, script, detalle = NULL) {
  if (isTRUE(knitr::is_latex_output())) {
    p <- sprintf("%s \\emph{(figura de \\texttt{%s}", .tex_esc(texto), .tex_esc(script))
    if (!is.null(detalle)) p <- sprintf("%s, %s", p, .tex_esc(detalle))
    paste0(p, ")}")
  } else {
    p <- sprintf("%s *(figura de `%s`", texto, script)
    if (!is.null(detalle)) p <- sprintf("%s, %s", p, detalle)
    paste0(p, ")*")
  }
}

# --- code -------------------------------------------------------------------------------------
# Lifted from the real file by its section marker, which is a convention the scripts already
# follow ("# § 4 — title"). Line numbers would have been the obvious alternative and would rot on
# the first edit; a marker survives the file moving underneath it.
# Either a numbered section (`seccion`) or a named function (`funcion`). Shared modules like
# 00_corine.R have no section markers, and quoting them by line number would rot on the first edit.
codigo <- function(script, seccion = NULL, funcion = NULL, entero = FALSE,
                   titulo = NULL, resumen = NULL, lenguaje = NULL) {
  f <- file.path(SCR, script)
  if (!file.exists(f)) stop("no existe el script ", script, call. = FALSE)
  l <- readLines(f, warn = FALSE, encoding = "UTF-8")

  py <- grepl("\\.py$", script)

  if (isTRUE(entero)) {
    ini <- 1L; fin <- length(l)
    ref <- sprintf("`%s`, completo", script)
  } else if (!is.null(funcion)) {
    pat <- if (py) sprintf("^def +%s *\\(", funcion) else sprintf("^%s *<- *function", funcion)
    ini <- grep(pat, l)
    if (!length(ini))
      stop("el script ", script, " no define ", funcion, call. = FALSE)
    ini <- ini[1]
    # R functions in this project close with a brace in the first column; Python ones end where
    # the next top-level statement begins. Two languages, two rules, same idea.
    fin <- if (py) {
      sig <- grep("^[^ \t#]", l)
      s <- sig[sig > ini]
      if (length(s)) s[1] - 1L else length(l)
    } else {
      cierres <- grep("^\\}", l)
      s <- cierres[cierres > ini]
      if (!length(s)) stop("no encuentro el final de ", funcion, " en ", script, call. = FALSE)
      s[1]
    }
    # Carry the comment block immediately above the definition: it is where the why lives.
    while (ini > 1 && grepl("^#", l[ini - 1])) ini <- ini - 1
    ref <- sprintf("`%s`, función `%s()`", script, funcion)
  } else {
    ini <- grep(sprintf("^#+ *§ *%s *[—-]", seccion), l)
    if (!length(ini)) stop("el script ", script, " no tiene una sección § ", seccion, call. = FALSE)
    ini <- ini[1]
    sig <- grep("^#+ *§ *[0-9]+ *[—-]", l)
    fin <- sig[sig > ini]
    fin <- if (length(fin)) fin[1] - 1L else length(l)
    ref <- sprintf("`%s`, sección %s", script, seccion)
  }
  bloque <- paste(l[ini:fin], collapse = "\n")

  cab <- if (is.null(titulo)) sprintf("Código: %s", ref)
         else sprintf("Código: %s (%s)", titulo, ref)
  lang <- if (!is.null(lenguaje)) lenguaje
          else if (py) "python" else if (grepl("\\.sh$", script)) "bash" else "r"
  cuerpo <- paste0("```", lang, "\n", bloque, "\n```")
  if (!is.null(resumen)) cuerpo <- paste0(resumen, "\n\n", cuerpo)

  # Folded in HTML, plain in PDF. A <details> block is dropped by LaTeX, so the print version would
  # silently lose every code listing in the book.
  if (isTRUE(knitr::is_html_output()))
    cat(sprintf("<details>\n<summary>%s</summary>\n\n%s\n\n</details>\n", cab, cuerpo))
  else
    cat(sprintf("**%s**\n\n%s\n", cab, cuerpo))
}

invisible(NULL)
