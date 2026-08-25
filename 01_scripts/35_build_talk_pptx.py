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


# --- slide kinds for the methodological deck --------------------------------------------------
# These seven were added for the version a co-author reviews rather than the one that gets
# projected. That deck has to carry the chain, the parameters and the provenance, and doing that
# with the original kinds meant either a wall of text on a `figure` caption or an image of a table.
# Native shapes stay editable, reflow when a value changes, and print legibly.

ACCENTS = [BLUE, ORANGE, RGBColor(0x4D, 0x9A, 0x53), RGBColor(0x7B, 0x5E, 0xA7),
           RGBColor(0xC1, 0x62, 0x2E), RGBColor(0x3D, 0x6B, 0x7D)]
PANEL = RGBColor(0xF7, 0xF9, 0xFB)
ZEBRA = RGBColor(0xF2, 0xF5, 0xF8)


def est_lines(text, width, size_pt, factor=0.0072):
    """How many lines `text` will wrap to inside a box `width` EMU wide, set at `size_pt`.

    Segoe UI runs close to half an em per character over mixed-case English prose, so a character
    is roughly size_pt/144 inches. The factor is deliberately a shade generous: under-estimating
    clips text off the slide, over-estimating only leaves white space.
    """
    if not text:
        return 1
    per_line = max(8, int(width / Inches(factor * size_pt)))
    return sum(max(1, -(-len(ln) // per_line)) for ln in str(text).split("\n"))


def est_h(text, width, size_pt, line=1.24, pad=0.10):
    """Height an estimated block of text needs, with a little padding."""
    return Inches(est_lines(text, width, size_pt) * size_pt * line / 72 + pad)


def _body_lines(tf, lines, *, size, colour=MUTED, space_after=7, line=1.16):
    """Write a list of strings as consecutive paragraphs in one frame."""
    for j, ln in enumerate(lines):
        if j == 0:
            write(tf, ln, size=size, colour=colour, para=0, space_after=space_after, line=line)
        else:
            para(tf, ln, size=size, colour=colour, space_after=space_after, line=line)


def s_stepper(prs, d, page):
    """The chain as numbered steps across the page, each carrying its own parameters.

    The point of this kind is that a reader can see the order of operations and the value applied at
    each one without holding the previous slide in their head, which is exactly the complaint a
    method section usually earns.
    """
    slide = blank(prs)
    y = title_block(slide, d["title"])
    steps = d["steps"]
    n = len(steps)
    gap = Inches(0.30)
    col_w = int((CONTENT_W - gap * (n - 1)) / n)
    foot = d.get("foot")
    foot_h = (est_h(foot, CONTENT_W, BODY_PT - 1) + Inches(0.22)) if foot else Inches(0.1)
    card_h = H - y - Inches(0.72) - foot_h
    # A seven-step chain leaves each column about 1.5 in wide, and "Interpolate" set at 15.5 pt
    # breaks across two lines mid-word. The heading follows the column rather than the other way
    # round, because shortening the words would cost more than the point size does.
    inner = col_w - Inches(0.52)
    head_pt = 15.5 if inner >= Inches(1.65) else 14 if inner >= Inches(1.35) else \
        12.5 if inner >= Inches(1.05) else 11
    body_pt = 11.5 if inner >= Inches(1.35) else 10.5
    for i, st in enumerate(steps):
        x = MARGIN + i * (col_w + gap)
        accent = ACCENTS[i % len(ACCENTS)]
        rect(slide, x, y, col_w, card_h, PANEL)
        rect(slide, x, y, col_w, Inches(0.075), accent)
        # The step number sits in the corner rather than in the flow, so the eye reads the heading
        # first and uses the number only to keep its place.
        tf = txbox(slide, x + Inches(0.26), y + Inches(0.26), Inches(0.5), Inches(0.34))
        write(tf, str(i + 1), size=15, bold=True, colour=accent)
        tf = txbox(slide, x + Inches(0.26), y + Inches(0.66), inner, Inches(0.62))
        write(tf, st["head"], size=head_pt, bold=True, line=1.06)
        tf = txbox(slide, x + Inches(0.26), y + Inches(1.36), inner, card_h - Inches(2.15))
        _body_lines(tf, st["body"], size=body_pt)
        if st.get("param"):
            chip = rect(slide, x + Inches(0.26), y + card_h - Inches(0.62),
                        col_w - Inches(0.52), Inches(0.4), WHITE, line=RULE)
            ctf = chip.text_frame
            ctf.margin_left = ctf.margin_right = Inches(0.09)
            ctf.margin_top = ctf.margin_bottom = 0
            ctf.vertical_anchor = MSO_ANCHOR.MIDDLE
            write(ctf, st["param"], size=10, colour=INK, align=PP_ALIGN.CENTER)
        if i < n - 1:
            tf = txbox(slide, x + col_w, y + card_h / 2 - Inches(0.22), gap, Inches(0.44))
            write(tf, "›", size=22, colour=FAINT, align=PP_ALIGN.CENTER)
    if foot:
        tf = txbox(slide, MARGIN, y + card_h + Inches(0.22), CONTENT_W, foot_h)
        write(tf, foot, size=BODY_PT - 1, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_params(prs, d, page):
    """A parameter table with the file and line each value is set at.

    The provenance column is the reason this kind exists: a co-author asked to trust a number should
    be able to go and look at it, and a slide that says "IDW, 50 km" without saying where 50 km is
    written is asking to be taken on faith.
    """
    slide = blank(prs)
    y = title_block(slide, d["title"])
    rows = d["rows"]
    foot = d.get("foot")
    k_w = int(CONTENT_W * d.get("key_frac", 0.24))
    s_w = int(CONTENT_W * d.get("src_frac", 0.24))
    v_w = CONTENT_W - k_w - s_w
    foot_h = (est_h(foot, CONTENT_W, BODY_PT - 2) + Inches(0.18)) if foot else Inches(0)
    avail = H - y - Inches(0.72) - foot_h

    # Rows are measured, not assumed. A fixed row height clipped every value that wrapped, and on
    # the open-questions slide that was three rows out of nine. If the measured table overruns the
    # slide the type comes down rather than the text being cut.
    fs = d.get("size", 12)
    while True:
        heights = [max(Inches(0.30),
                       est_h(r[1], v_w - Inches(0.2), fs, line=1.22, pad=0.12)) for r in rows]
        if sum(heights) <= avail or fs <= 9:
            break
        fs -= 0.5

    ry = y
    for i, (r, row_h) in enumerate(zip(rows, heights)):
        if i % 2 == 0:
            rect(slide, MARGIN, ry, CONTENT_W, row_h, ZEBRA)
        pad = Inches(0.06)
        tf = txbox(slide, MARGIN + Inches(0.16), ry + pad, k_w - Inches(0.2), row_h)
        write(tf, r[0], size=fs, bold=True, colour=RGBColor(0x2C, 0x4A, 0x5E), line=1.22)
        tf = txbox(slide, MARGIN + k_w, ry + pad, v_w - Inches(0.2), row_h)
        write(tf, r[1], size=fs, line=1.22)
        if len(r) > 2 and r[2]:
            tf = txbox(slide, MARGIN + k_w + v_w, ry + pad, s_w, row_h)
            write(tf, r[2], size=fs - 3, colour=FAINT, align=PP_ALIGN.RIGHT)
        ry += row_h
    if foot:
        tf = txbox(slide, MARGIN, ry + Inches(0.18), CONTENT_W, foot_h)
        write(tf, foot, size=BODY_PT - 2, colour=MUTED, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_twocol(prs, d, page):
    """A figure beside headed blocks of explanation, rather than beside loose sentences.

    `figure_side` gives the reader a stack of equal-weight lines. When the explanation has structure
    (what it shows, how to read it, what it does not settle) the headings carry that structure and
    the reader can skip to the part they want.
    """
    slide = blank(prs)
    y = title_block(slide, d["title"])
    box_h = H - y - Inches(0.72)
    frac = d.get("image_frac", 0.52)
    img_w = int(CONTENT_W * frac)
    on_right = d.get("image_side", "left") == "right"
    img_x = (W - MARGIN - img_w) if on_right else MARGIN
    tx = MARGIN if on_right else (MARGIN + img_w + Inches(0.45))
    tw = CONTENT_W - img_w - Inches(0.45)
    place_image(slide, ROOT / d["image"], img_x, y, img_w, box_h)

    # The column is measured before anything is drawn. Blocks vary from one line to five, so a
    # fixed slot either clips the long ones or leaves holes under the short ones; and when the
    # whole column overruns the slide the type comes down rather than the last block falling off
    # the bottom, which is what happened as soon as a correction made one block longer.
    blocks = [dict(head=b["head"],
                   body=b["body"] if isinstance(b["body"], list) else [b["body"]])
              for b in d["blocks"]]
    head_pt, body_pt = 13.5, 12.0
    gap, lead = Inches(0.20), Inches(0.30)
    while True:
        heights = [sum(est_h(ln, tw, body_pt, line=1.18, pad=0.04) for ln in b["body"])
                   for b in blocks]
        total = sum(heights) + len(blocks) * (lead + gap)
        if total <= box_h or body_pt <= 9.5:
            break
        head_pt -= 0.5
        body_pt -= 0.5

    yy = y + Inches(0.06)
    for blk, h in zip(blocks, heights):
        tf = txbox(slide, tx, yy, tw, lead)
        write(tf, blk["head"], size=head_pt, bold=True, colour=RGBColor(0x2C, 0x4A, 0x5E))
        yy += lead
        tf = txbox(slide, tx, yy, tw, h)
        _body_lines(tf, blk["body"], size=body_pt, space_after=5, line=1.18)
        yy += h + gap
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_table(prs, d, page):
    """A real table in native shapes, with one row or column allowed to carry emphasis."""
    slide = blank(prs)
    y = title_block(slide, d["title"])
    head, rows = d["head"], d["rows"]
    widths = d.get("widths") or [1.0 / len(head)] * len(head)
    cols = [int(CONTENT_W * f) for f in widths]
    xs, acc = [], MARGIN
    for c in cols:
        xs.append(acc)
        acc += c
    foot = d.get("foot")
    foot_h = (est_h(foot, CONTENT_W, BODY_PT - 2) + Inches(0.30)) if foot else Inches(0)
    avail = H - y - Inches(0.72) - foot_h
    emph = d.get("emphasis")

    # A row is as tall as its tallest cell needs. A fixed height suits a table of short values and
    # clips the moment one column carries a sentence, which is what a "why" column always does.
    fs = d.get("size", 12)
    head_h = Inches(0.40)
    floor = min(Inches(0.34), int((avail - head_h) / max(len(rows), 1)))
    while True:
        heights = [max(floor,
                       Inches(max(est_lines(str(c), cols[j] - Inches(0.24), fs)
                                  for j, c in enumerate(r)) * fs * 1.24 / 72 + 0.14))
                   for r in rows]
        if sum(heights) + head_h <= avail or fs <= 9:
            break
        fs -= 0.5

    rect(slide, MARGIN, y, CONTENT_W, head_h, RGBColor(0x2C, 0x4A, 0x5E))
    for j, htxt in enumerate(head):
        al = PP_ALIGN.RIGHT if j and d.get("numeric", True) else PP_ALIGN.LEFT
        tf = txbox(slide, xs[j] + Inches(0.12), y + Inches(0.09), cols[j] - Inches(0.24), head_h)
        write(tf, htxt, size=fs - 1, bold=True, colour=WHITE, align=al)

    ry = y + head_h
    for i, (r, row_h) in enumerate(zip(rows, heights)):
        if emph is not None and i == emph:
            rect(slide, MARGIN, ry, CONTENT_W, row_h, RGBColor(0xE8, 0xF0, 0xF6))
        elif i % 2 == 0:
            rect(slide, MARGIN, ry, CONTENT_W, row_h, ZEBRA)
        for j, cell in enumerate(r):
            al = PP_ALIGN.RIGHT if j and d.get("numeric", True) else PP_ALIGN.LEFT
            bold = (emph is not None and i == emph) or (j == 0 and d.get("bold_first", True))
            tf = txbox(slide, xs[j] + Inches(0.12), ry + Inches(0.07), cols[j] - Inches(0.24),
                       row_h)
            write(tf, str(cell), size=fs, bold=bold, align=al, line=1.22)
        ry += row_h
    if foot:
        tf = txbox(slide, MARGIN, ry + Inches(0.18), CONTENT_W, foot_h)
        write(tf, foot, size=BODY_PT - 2, colour=MUTED, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_datacard(prs, d, page):
    """One card per data source, each with its real dimensions as key-value rows."""
    slide = blank(prs)
    y = title_block(slide, d["title"])
    items = d["items"]
    n = len(items)
    gap = Inches(0.30)
    col_w = int((CONTENT_W - gap * (n - 1)) / n)
    foot = d.get("foot")
    card_h = H - y - Inches(0.72) - (Inches(0.82) if foot else Inches(0.1))
    for i, it in enumerate(items):
        x = MARGIN + i * (col_w + gap)
        accent = ACCENTS[i % len(ACCENTS)]
        rect(slide, x, y, col_w, card_h, PANEL)
        rect(slide, x, y, col_w, Inches(0.075), accent)
        tf = txbox(slide, x + Inches(0.26), y + Inches(0.28), col_w - Inches(0.52), Inches(0.6))
        write(tf, it["head"], size=15, bold=True, line=1.06)
        inner = col_w - Inches(0.52)
        sub_h = est_h(it["sub"], inner, 10.5, line=1.12, pad=0.06)
        tf = txbox(slide, x + Inches(0.26), y + Inches(0.92), inner, sub_h)
        write(tf, it["sub"], size=10.5, colour=MUTED, line=1.1)
        note_h = (est_h(it["note"], inner - Inches(0.2), 9.5, line=1.14, pad=0.16)
                  if it.get("note") else Inches(0))
        ry = y + Inches(0.98) + sub_h
        room = (y + card_h - note_h - Inches(0.22)) - ry
        pitch = min(Inches(0.36), int(room / max(len(it["rows"]), 1)))
        for k, v in it["rows"]:
            rect(slide, x + Inches(0.26), ry, col_w - Inches(0.52), Emu(9525), RULE)
            tf = txbox(slide, x + Inches(0.26), ry + Inches(0.08), int((col_w - Inches(0.52)) * 0.38),
                       Inches(0.28))
            write(tf, k, size=10, colour=MUTED)
            tf = txbox(slide, x + Inches(0.26) + int((col_w - Inches(0.52)) * 0.38), ry + Inches(0.08),
                       int((col_w - Inches(0.52)) * 0.62), Inches(0.28))
            write(tf, v, size=10, bold=True, align=PP_ALIGN.RIGHT)
            ry += pitch
        if it.get("note"):
            nb = rect(slide, x + Inches(0.26), y + card_h - note_h - Inches(0.14), inner,
                      note_h, RGBColor(0xFD, 0xF3, 0xE3))
            ntf = nb.text_frame
            ntf.margin_left = ntf.margin_right = Inches(0.1)
            ntf.margin_top = ntf.margin_bottom = Inches(0.05)
            ntf.word_wrap = True
            write(ntf, it["note"], size=9.5, colour=RGBColor(0x6B, 0x4C, 0x17), line=1.12)
    if foot:
        tf = txbox(slide, MARGIN, y + card_h + Inches(0.2), CONTENT_W, Inches(0.66))
        write(tf, foot, size=BODY_PT - 1, line=1.2)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_bignum(prs, d, page):
    """A row of headline figures. Used where the argument is the size of a number, not its shape."""
    slide = blank(prs)
    y = title_block(slide, d["title"])
    items = d["items"]
    n = len(items)
    gap = Inches(0.28)
    col_w = int((CONTENT_W - gap * (n - 1)) / n)
    inner = col_w - Inches(0.5)
    lead = d.get("lead")
    if lead:
        lead_h = est_h(lead, CONTENT_W, BODY_PT, line=1.2)
        tf = txbox(slide, MARGIN, y, CONTENT_W, lead_h)
        write(tf, lead, size=BODY_PT, colour=MUTED, line=1.2)
        y += lead_h + Inches(0.18)

    # The headline is the size of the number, so the number must not wrap. "229,676 km2" set at
    # 34 pt needs 2.4 in and a four-column row gives it 2.3, which broke the unit onto a second
    # line and dropped it on top of the label. The type comes down until every value fits one line.
    val_pt = 34
    while val_pt > 17 and any(est_lines(it["value"], inner, val_pt) > 1 for it in items):
        val_pt -= 1.5
    val_h = Inches(val_pt * 1.06 / 72 + 0.08)
    lab_h = max(est_h(it["label"], inner, 11.5, line=1.16, pad=0.04) for it in items)
    box_h = Inches(0.24) + val_h + Inches(0.10) + lab_h + Inches(0.18)

    for i, it in enumerate(items):
        x = MARGIN + i * (col_w + gap)
        accent = it.get("accent") or ACCENTS[i % len(ACCENTS)]
        rect(slide, x, y, col_w, box_h, PANEL)
        rect(slide, x, y, Inches(0.075), box_h, accent)
        tf = txbox(slide, x + Inches(0.32), y + Inches(0.24), inner, val_h)
        write(tf, it["value"], size=val_pt, bold=True, colour=accent, line=0.98)
        tf = txbox(slide, x + Inches(0.32), y + Inches(0.34) + val_h, inner, lab_h)
        write(tf, it["label"], size=11.5, colour=MUTED, line=1.14)
    body = d.get("body") or []
    if body:
        tf = txbox(slide, MARGIN, y + box_h + Inches(0.34), CONTENT_W, H - y - box_h - Inches(1.1))
        _body_lines(tf, body, size=BODY_PT - 1, colour=INK, space_after=11, line=1.22)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


def s_annotated(prs, d, page):
    """A figure with numbered callouts pinned to it.

    Positions are given as fractions of the placed image, not as inches, so a figure that is
    regenerated at a different aspect ratio keeps its annotations on the right part of the picture.
    """
    slide = blank(prs)
    y = title_block(slide, d["title"])
    notes_w = int(CONTENT_W * d.get("notes_frac", 0.27))
    img_w = CONTENT_W - notes_w - Inches(0.4)
    box_h = H - y - Inches(0.72)
    left, top, w, h = place_image(slide, ROOT / d["image"], MARGIN, y, img_w, box_h)
    tx = MARGIN + img_w + Inches(0.4)
    yy = y + Inches(0.06)
    for i, c in enumerate(d["callouts"], start=1):
        accent = ACCENTS[(i - 1) % len(ACCENTS)]
        cx = left + int(w * c["at"][0])
        cy = top + int(h * c["at"][1])
        badge = rect(slide, cx - Inches(0.13), cy - Inches(0.13), Inches(0.26), Inches(0.26), accent)
        btf = badge.text_frame
        btf.margin_left = btf.margin_right = btf.margin_top = btf.margin_bottom = 0
        btf.vertical_anchor = MSO_ANCHOR.MIDDLE
        write(btf, str(i), size=10, bold=True, colour=WHITE, align=PP_ALIGN.CENTER)
        tf = txbox(slide, tx, yy, Inches(0.26), Inches(0.3))
        write(tf, str(i), size=12, bold=True, colour=accent)
        tf = txbox(slide, tx + Inches(0.3), yy, notes_w - Inches(0.3), Inches(1.0))
        write(tf, c["text"], size=11.5, colour=INK, line=1.16)
        est = 1 + len(c["text"]) // int((notes_w - Inches(0.3)) / Inches(0.075))
        yy += Inches(0.20) * est + Inches(0.22)
    footer(slide, d.get("source"), page)
    notes(slide, d.get("notes", ""))


FIG_DIR_NAME = "02_outputs/figures_chill"

KINDS = dict(cover=s_cover, section=s_section, figure=s_figure, figure_side=s_figure_side,
             compare=s_compare, ingredients=s_ingredients, close=s_close, gallery=s_gallery,
             stepper=s_stepper, params=s_params, twocol=s_twocol, table=s_table,
             datacard=s_datacard, bignum=s_bignum, annotated=s_annotated)


def load_numbers():
    """Every metric the slides quote, keyed by name, from the tables that computed them."""
    out = {}
    for name in ("talk_key_numbers.csv", "method_figure_numbers.csv", "model_spread_numbers.csv",
                 "method_chain_numbers.csv", "timeline_numbers.csv", "model_ranking_numbers.csv",
                 "cieza_numbers.csv", "v3_numbers.csv", "v3_gap_numbers.csv"):
        path = ROOT / "02_outputs" / name
        if not path.exists():
            sys.exit(f"missing {path}\n"
                     "  run scripts 27, 33, 34, 36, 37, 38, 42, 43, 45 and 47 before building the deck")
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
    ap.add_argument("--v3", action="store_true",
                    help="build the methodological deck a co-author reads, not the spoken talk")
    a = ap.parse_args()

    if a.v3 and (a.annex or a.short):
        sys.exit("--v3 is its own deck: it has no annex and no spoken subset")

    N = load_numbers()
    if a.v3:
        deck = talk_content.v3(N)
    elif a.annex:
        deck = talk_content.annex(N)
    else:
        deck = talk_content.slides(N)

    # Two decks come out of one narrative. The full one is what the coauthors review, and it has to
    # carry every check that was run; the short one is what fits a 15-minute slot. Marking the
    # spoken subset in the content file rather than keeping a second list means the two cannot
    # drift, which is the same reason the numbers come from CSVs instead of being typed.
    if a.short:
        deck = [d for d in deck if d.get("spoken")]
        if not deck:
            sys.exit("--short: no slide carries spoken=True in talk_content.py")

    if a.out is None:
        stem = ("charla_plinius_v3" if a.v3 else
                "anexo_plinius" if a.annex else
                "charla_plinius_15min" if a.short else "charla_plinius")
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
    # 35 once the results section showed the eleven models per scenario before their median. The v3
    # deck is read rather than delivered, so it answers to a different limit: past about 55 slides a
    # reviewer stops reading, which is the failure that matters there.
    cap = 55 if a.v3 else 35
    if not a.annex and len(deck) > cap:
        print(f"WARNING: {len(deck)} slides, above the cap of {cap}")


if __name__ == "__main__":
    main()
