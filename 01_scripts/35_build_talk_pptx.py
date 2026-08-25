#!/usr/bin/env python3
"""Build the talk deck from talk_content.py.

Assembly only: not a word of the narrative lives here. The design is deliberately plain, because
the figures already carry three colours with meaning (blue both cultivars, orange only the mutant,
red neither) and a template that adds a fourth would compete with them.

Type scale and layout follow the assertion-evidence checklist: a full-sentence title of at most two
lines, evidence rather than bullets underneath, and nothing on the slide the speaker is going to
read out loud. Scenario colours are the IPCC AR6 ones so anyone who has seen an AR6 figure
recognises them without a legend.

Every number reaching a slide comes from one of the six metric tables load_numbers() reads. Almost
none is typed into the content file, and the exceptions are marked in its own docstring, so a slide
cannot drift from the table that produced it.

Usage: python 35_build_talk_pptx.py [--out ../03_presentacion/charla_plinius.pptx]
Requires: python-pptx, Pillow. Run 31 to 34 and 36 to 43 first: the figures, the GIF and the metric
tables must all exist.
"""

import argparse
import csv
import re
import sys
from pathlib import Path

from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Inches, Pt

sys.path.insert(0, str(Path(__file__).resolve().parent))
import talk_content  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# --- design system ---------------------------------------------------------------------------
W, H = Inches(13.333), Inches(7.5)          # 16:9
MARGIN = Inches(0.62)
CONTENT_W = W - 2 * MARGIN

INK = RGBColor(0x16, 0x18, 0x1D)
MUTED = RGBColor(0x5F, 0x66, 0x72)
FAINT = RGBColor(0x8A, 0x90, 0x99)
RULE = RGBColor(0xDC, 0xDF, 0xE4)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

BLUE = RGBColor(0x2C, 0x7B, 0xB6)           # both cultivars viable
ORANGE = RGBColor(0xFD, 0xAE, 0x61)         # only the mutant
RED = RGBColor(0xD7, 0x19, 0x1C)            # neither

FONT = "Segoe UI"
TITLE_PT, SUB_PT, BODY_PT, CAP_PT, SRC_PT = 26, 15, 16, 13, 10


def txbox(slide, x, y, w, h, *, anchor=MSO_ANCHOR.TOP):
    """A text box with autofit off and no internal padding, which is never what a slide wants."""
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    return tf


def write(tf, text, *, size, colour=INK, bold=False, para=0, space_after=0, align=PP_ALIGN.LEFT,
          line=None):
    p = tf.paragraphs[para] if para < len(tf.paragraphs) else tf.add_paragraph()
    p.alignment = align
    p.space_after = Pt(space_after)
    if line:
        p.line_spacing = line
    r = p.add_run()
    r.text = text
    r.font.size = Pt(size)
    r.font.bold = bold
    r.font.name = FONT
    r.font.color.rgb = colour
    return p


def link_urls(p, *, size, colour=MUTED):
    """Rebuild a finished paragraph so that any https:// token becomes a real hyperlink.

    Splitting the text into runs is what makes the address clickable in the exported PDF, which is
    how the repository actually gets visited after a talk. The colour is deliberately left as the
    surrounding text: a blue underlined link would be the only one in the whole deck.
    """
    text = "".join(r.text for r in p.runs)
    if "https://" not in text:
        return
    for r in list(p.runs):
        r._r.getparent().remove(r._r)
    for token in re.split(r"(https://\S+)", text):
        if not token:
            continue
        run = p.add_run()
        run.text = token
        run.font.size = Pt(size)
        run.font.name = FONT
        run.font.color.rgb = colour
        if token.startswith("https://"):
            run.hyperlink.address = token


def para(tf, text, **kw):
    """Append a paragraph to an existing frame."""
    tf.add_paragraph()
    return write(tf, text, para=len(tf.paragraphs) - 1, **kw)


def rect(slide, x, y, w, h, fill, *, line=None):
    sh = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, y, w, h)
    sh.fill.solid()
    sh.fill.fore_color.rgb = fill
    if line is None:
        sh.line.fill.background()
    else:
        sh.line.color.rgb = line
        sh.line.width = Pt(0.75)
    sh.shadow.inherit = False
    sh.text_frame.word_wrap = True
    return sh


def fit(img_path, box_w, box_h):
    """Largest (w, h) fitting the box while preserving the image's aspect ratio."""
    with Image.open(img_path) as im:
        iw, ih = im.size
    scale = min(box_w / iw, box_h / ih)
    return int(iw * scale), int(ih * scale)


def place_image(slide, path, x, y, box_w, box_h):
    """Centre an image inside a box, scaled to fit. Returns its bounding box."""
    if not path.exists():
        sys.exit(f"missing figure: {path}\n  run scripts 31-34 before building the deck")
    w, h = fit(path, box_w, box_h)
    left = x + int((box_w - w) / 2)
    top = y + int((box_h - h) / 2)
    slide.shapes.add_picture(str(path), left, top, width=w, height=h)
    return left, top, w, h


P_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"


def fade(slide, ms=350):
    """Give the slide a short fade-in, written straight into the slide XML.

    python-pptx has no transition API, and applying transitions by hand in PowerPoint afterwards
    would mean losing them every time this script regenerates the file. Writing the element here
    keeps the deck reproducible from source, which is the whole point of building it with a script.

    Schema order inside <p:sld> is cSld, clrMapOvr, transition, timing, so the element is appended
    after clrMapOvr rather than at the end.
    """
    from lxml import etree
    sld = slide._element
    tr = etree.SubElement(sld, f"{{{P_NS}}}transition")
    tr.set("spd", "fast")
    tr.set("advClick", "1")
    etree.SubElement(tr, f"{{{P_NS}}}fade")
    timing = sld.find(f"{{{P_NS}}}timing")
    if timing is not None:                      # keep timing last if python-pptx already made one
        sld.remove(timing)
        sld.append(timing)
    return tr


def blank(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    fade(slide)
    return slide


def notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


def title_block(slide, text, y=None):
    """Assertion title plus the hairline under it. Returns the y where content may start."""
    y = MARGIN if y is None else y
    lines = 2 if len(text) > 62 else 1
    h = Inches(0.52 * lines)
    tf = txbox(slide, MARGIN, y, CONTENT_W, h)
    write(tf, text, size=TITLE_PT, bold=True, line=0.92)
    ry = y + h + Inches(0.12)
    rect(slide, MARGIN, ry, CONTENT_W, Emu(9525), RULE)
    return ry + Inches(0.22)


def footer(slide, source, page):
    if source:
        tf = txbox(slide, MARGIN, H - Inches(0.5), CONTENT_W - Inches(0.6), Inches(0.3))
        write(tf, source, size=SRC_PT, colour=FAINT)
    tf = txbox(slide, W - MARGIN - Inches(0.6), H - Inches(0.5), Inches(0.6), Inches(0.3))
    write(tf, str(page), size=SRC_PT, colour=FAINT, align=PP_ALIGN.RIGHT)


# --- slide kinds -----------------------------------------------------------------------------
def s_cover(prs, d, page):
    # No accent bar and a 32 pt title: the working title is a full descriptive sentence rather
    # than a short phrase, so it needs three lines and the whole upper band of the page.
    slide = blank(prs)
    tf = txbox(slide, MARGIN, Inches(0.68), CONTENT_W - Inches(1.2), Inches(2.05))
    write(tf, d["title"], size=32, bold=True, line=0.95)
    tf = txbox(slide, MARGIN, Inches(3.25), CONTENT_W - Inches(2.0), Inches(1.1))
    write(tf, d["subtitle"], size=17, colour=MUTED, line=1.15)
    tf = txbox(slide, MARGIN, Inches(4.85), CONTENT_W, Inches(1.0))
    write(tf, d["authors"], size=16, bold=True)
    para(tf, d["affil"], size=11.5, colour=MUTED, space_after=0)
    rect(slide, MARGIN, Inches(6.15), Inches(1.4), Emu(19050), BLUE)
    tf = txbox(slide, MARGIN, Inches(6.42), CONTENT_W, Inches(0.4))
    write(tf, d["venue"], size=12, colour=MUTED)
    notes(slide, d["notes"])


def s_section(prs, d, page):
    slide = blank(prs)
    rect(slide, Emu(0), Emu(0), W, H, RGBColor(0xF4, 0xF6, 0xF8))
    rect(slide, Emu(0), Emu(0), Inches(0.22), H, BLUE)
    tf = txbox(slide, Inches(1.1), Inches(2.5), Inches(1.2), Inches(1.4))
    write(tf, d["n"], size=76, bold=True, colour=RGBColor(0xC9, 0xD3, 0xDC))
    tf = txbox(slide, Inches(2.35), Inches(2.62), Inches(9.4), Inches(1.0))
    write(tf, d["title"], size=34, bold=True)
    lead = d.get("lead", "")
    if lead:
        tf = txbox(slide, Inches(2.35), Inches(3.72), Inches(8.6), Inches(1.2))
        write(tf, lead, size=16, colour=MUTED, line=1.2)
    notes(slide, d.get("notes", ""))


def s_figure(prs, d, page):
    slide = blank(prs)
    y = title_block(slide, d["title"])
    cap = d.get("caption")
    cap_h = Inches(0.62) if cap else Inches(0)
    box_h = H - y - Inches(0.72) - cap_h
    left, top, w, h = place_image(slide, ROOT / d["image"], MARGIN, y, CONTENT_W, box_h)
    if cap:
        tf = txbox(slide, MARGIN, y + box_h + Inches(0.06), CONTENT_W, cap_h)
        write(tf, cap, size=CAP_PT, colour=MUTED, line=1.15)
    if d.get("gif"):
        # PowerPoint only animates a GIF in slideshow mode; in the editing view it shows frame one.
        badge = rect(slide, left + w - Inches(1.65), top + Inches(0.08), Inches(1.55),
                     Inches(0.28), RGBColor(0x16, 0x18, 0x1D))
        tf = badge.text_frame
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        write(tf, "animated · press F5", size=9, colour=WHITE, align=PP_ALIGN.CENTER)
    footer(slide, d.get("source"), page)
    notes(slide, d["notes"])


def s_figure_side(prs, d, page):
    slide = blank(prs)
    y = title_block(slide, d["title"])
    box_h = H - y - Inches(0.72)
    img_w = int(CONTENT_W * 0.56)
    place_image(slide, ROOT / d["image"], MARGIN, y, img_w, box_h)
    tx = MARGIN + img_w + Inches(0.45)
    tw = W - MARGIN - tx
    tf = txbox(slide, tx, y + Inches(0.1), tw, box_h, anchor=MSO_ANCHOR.TOP)
    for i, pt in enumerate(d["points"]):
        write(tf, pt, size=BODY_PT - 2, colour=INK if i == 0 else MUTED, para=i,
              space_after=13, line=1.18) if i == 0 else para(
                  tf, pt, size=BODY_PT - 2, colour=MUTED, space_after=13, line=1.18)
    footer(slide, d.get("source"), page)
    notes(slide, d["notes"])


def s_compare(prs, d, page):
    slide = blank(prs)
    y = title_block(slide, d["title"])
    col_w = int((CONTENT_W - Inches(0.5)) / 2)
    # The card is sized from its longest column rather than fixed. A fixed 3.55 in held three
    # short lines and clipped the fourth as soon as one of them wrapped.
    n_lines = max(len(d["left"]["lines"]), len(d["right"]["lines"]))
    card_h = Inches(2.15 + 0.42 * n_lines)
    for i, (side, accent) in enumerate([(d["left"], RED), (d["right"], ORANGE)]):
        x = MARGIN + i * (col_w + Inches(0.5))
        card = rect(slide, x, y, col_w, card_h, RGBColor(0xF7, 0xF9, 0xFB))
        card.text_frame.text = ""
        rect(slide, x, y, col_w, Inches(0.09), accent)
        tf = txbox(slide, x + Inches(0.38), y + Inches(0.4), col_w - Inches(0.76), Inches(0.5))
        write(tf, side["head"], size=21, bold=True)
        tf = txbox(slide, x + Inches(0.38), y + Inches(0.94), col_w - Inches(0.76), Inches(0.85))
        write(tf, side["big"], size=46, bold=True, colour=accent)
        tf = txbox(slide, x + Inches(0.38), y + Inches(1.95),
                   col_w - Inches(0.76), card_h - Inches(2.1))
        for j, ln in enumerate(side["lines"]):
            (write if j == 0 else para)(tf, ln, size=12.5, colour=MUTED, space_after=6, line=1.12,
                                        **({"para": 0} if j == 0 else {}))
    tf = txbox(slide, MARGIN, y + card_h + Inches(0.24), CONTENT_W, Inches(0.8))
    write(tf, d["foot"], size=BODY_PT, colour=INK, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d["notes"])


def s_ingredients(prs, d, page):
    slide = blank(prs)
    y = title_block(slide, d["title"])
    n = len(d["items"])
    gap = Inches(0.36)
    col_w = int((CONTENT_W - gap * (n - 1)) / n)
    accents = [BLUE, ORANGE, RGBColor(0x4D, 0x9A, 0x53), RGBColor(0x7B, 0x5E, 0xA7)]
    for i, item in enumerate(d["items"]):
        x = MARGIN + i * (col_w + gap)
        rect(slide, x, y, col_w, Inches(3.3), RGBColor(0xF7, 0xF9, 0xFB))
        rect(slide, x, y, col_w, Inches(0.09), accents[i % len(accents)])
        tf = txbox(slide, x + Inches(0.32), y + Inches(0.44), col_w - Inches(0.64), Inches(0.5))
        write(tf, item["head"], size=20, bold=True)
        tf = txbox(slide, x + Inches(0.32), y + Inches(1.12), col_w - Inches(0.64), Inches(2.0))
        for j, ln in enumerate(item["body"].split("\n")):
            (write if j == 0 else para)(tf, ln, size=13.5, colour=MUTED, space_after=8, line=1.15,
                                        **({"para": 0} if j == 0 else {}))
    tf = txbox(slide, MARGIN, y + Inches(3.7), CONTENT_W, Inches(0.8))
    write(tf, d["foot"], size=BODY_PT, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d["notes"])


def s_close(prs, d, page):
    slide = blank(prs)
    rect(slide, Emu(0), Emu(0), W, Inches(0.14), BLUE)
    tf = txbox(slide, MARGIN, Inches(0.85), CONTENT_W, Inches(0.9))
    write(tf, d["title"], size=38, bold=True)
    y = Inches(2.15)
    for pt in d["points"]:
        rect(slide, MARGIN, y + Inches(0.09), Inches(0.075), Inches(0.5), BLUE)
        tf = txbox(slide, MARGIN + Inches(0.34), y, CONTENT_W - Inches(0.34), Inches(0.95))
        write(tf, pt, size=17, line=1.18)
        y += Inches(1.06)
    tf = txbox(slide, MARGIN, H - Inches(0.95), CONTENT_W, Inches(0.4))
    p = write(tf, d["foot"], size=12.5, colour=MUTED)
    link_urls(p, size=12.5)
    notes(slide, d["notes"])


def s_gallery(prs, d, page):
    """Contact sheet: every map at thumbnail size, so one can be pointed at during questions."""
    slide = blank(prs)
    y = title_block(slide, d["title"])
    items = d["items"]
    cols, rows = 5, 3
    gap = Inches(0.14)
    cell_w = int((CONTENT_W - gap * (cols - 1)) / cols)
    avail_h = H - y - Inches(0.72)
    cell_h = int((avail_h - gap * (rows - 1)) / rows)
    lab_h = Inches(0.23)
    for i, (fname, label) in enumerate(items[:cols * rows]):
        r, c = divmod(i, cols)
        x = MARGIN + c * (cell_w + gap)
        yy = y + r * (cell_h + gap)
        place_image(slide, ROOT / FIG_DIR_NAME / fname, x, yy, cell_w, cell_h - lab_h)
        tf = txbox(slide, x, yy + cell_h - lab_h, cell_w, lab_h)
        write(tf, label, size=8.5, colour=MUTED, align=PP_ALIGN.CENTER)
    footer(slide, d.get("source"), page)
    notes(slide, d["notes"])


FIG_DIR_NAME = "02_outputs/figures_chill"

KINDS = dict(cover=s_cover, section=s_section, figure=s_figure, figure_side=s_figure_side,
             compare=s_compare, ingredients=s_ingredients, close=s_close, gallery=s_gallery)


def load_numbers():
    """Every metric the slides quote, keyed by name, from the tables that computed them."""
    out = {}
    for name in ("talk_key_numbers.csv", "method_figure_numbers.csv", "model_spread_numbers.csv",
                 "method_chain_numbers.csv", "timeline_numbers.csv", "model_ranking_numbers.csv",
                 "cieza_numbers.csv"):
        path = ROOT / "02_outputs" / name
        if not path.exists():
            sys.exit(f"missing {path}\n"
                     "  run scripts 27, 33, 34, 36, 37, 38, 42 and 43 before building the deck")
        with open(path, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                try:
                    out[row["metric"]] = float(row["value"])
                except ValueError:
                    out[row["metric"]] = row["value"]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=None)
    ap.add_argument("--annex", action="store_true",
                    help="build the backup deck instead of the talk")
    ap.add_argument("--short", action="store_true",
                    help="build only the slides marked spoken=True, for the 15-minute slot")
    a = ap.parse_args()

    N = load_numbers()
    deck = talk_content.annex(N) if a.annex else talk_content.slides(N)

    # Two decks come out of one narrative. The full one is what the coauthors review, and it has to
    # carry every check that was run; the short one is what fits a 15-minute slot. Marking the
    # spoken subset in the content file rather than keeping a second list means the two cannot
    # drift, which is the same reason the numbers come from CSVs instead of being typed.
    if a.short:
        deck = [d for d in deck if d.get("spoken")]
        if not deck:
            sys.exit("--short: no slide carries spoken=True in talk_content.py")

    if a.out is None:
        stem = "anexo_plinius" if a.annex else ("charla_plinius_15min" if a.short
                                               else "charla_plinius")
        a.out = str(ROOT / "03_presentacion" / f"{stem}.pptx")

    prs = Presentation()
    prs.slide_width, prs.slide_height = W, H
    for i, d in enumerate(deck, start=1):
        kind = d["kind"]
        if kind not in KINDS:
            sys.exit(f"unknown slide kind {kind!r} on slide {i}")
        KINDS[kind](prs, d, i)

    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    prs.save(out)

    n_notes = sum(1 for s in prs.slides if s.has_notes_slide
                  and s.notes_slide.notes_text_frame.text.strip())
    print(f"{out}")
    print(f"{len(deck)} slides, {n_notes} with speaker notes, "
          f"{out.stat().st_size/1e6:.2f} MB")
    # The cap was 20 while the deck argued a result, 30 once it also had to explain the method, and
    # 35 once the results section showed the eleven models per scenario before their median.
    if not a.annex and len(deck) > 35:
        print(f"WARNING: {len(deck)} slides, above the cap of 35")


if __name__ == "__main__":
    main()
