#!/usr/bin/env python3
"""Assemble the animation frames written by 31_scenario_frames.R into looping GIFs.

Reads 02_outputs/gif_frames/frames_manifest.csv, which names every frame, the animation it
belongs to and how long it is held, and writes one GIF per animation into 02_outputs/gifs/.

The one thing worth doing carefully here is the palette. GIF is an indexed format, and Pillow
quantises each frame on its own unless told otherwise, so a colour that is stable in the source
PNGs gets assigned slightly different palette entries from frame to frame. On a loop that reads as
a shimmer across the whole map, and a viewer interprets shimmer as change. A single palette is
therefore derived from all the frames of an animation together and imposed on each of them, which
also happens to compress better because consecutive frames then share most of their pixels.

Usage: python 32_make_gifs.py [--scale 1.0] [--only sidebyside]
Requires: Pillow. No ffmpeg, no imageio.
"""

import argparse
import csv
import sys
from collections import OrderedDict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FRAME_DIR = ROOT / "02_outputs" / "gif_frames"
GIF_DIR = ROOT / "02_outputs" / "gifs"
MANIFEST = FRAME_DIR / "frames_manifest.csv"

# GIF stores frame delays in hundredths of a second, so anything not a multiple of 10 ms is
# silently rounded by the decoder. Rounding here instead keeps what is written equal to what plays.
CENTISECOND = 10


def read_manifest():
    """Group the manifest rows by animation, preserving step order."""
    if not MANIFEST.exists():
        sys.exit(f"no manifest at {MANIFEST}\n  run: Rscript 31_scenario_frames.R")
    anims = OrderedDict()
    with open(MANIFEST, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            anims.setdefault(row["anim"], []).append(
                (int(row["step"]), row["file"], int(row["duration_ms"]))
            )
    for name in anims:
        anims[name].sort(key=lambda r: r[0])
    return anims


def load_frames(rows, scale):
    """Open the frames of one animation, rejecting any set that is not geometrically consistent.

    Frames of different sizes would be silently stretched by the GIF writer, which is exactly the
    kind of distortion this pipeline exists to avoid.
    """
    frames, durations = [], []
    for _, fname, dur in rows:
        path = FRAME_DIR / fname
        if not path.exists():
            sys.exit(f"missing frame: {path}")
        im = Image.open(path).convert("RGB")
        if scale != 1.0:
            im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        frames.append(im)
        durations.append(round(dur / CENTISECOND) * CENTISECOND)
    sizes = {f.size for f in frames}
    if len(sizes) > 1:
        sys.exit(f"frames of differing size in one animation: {sorted(sizes)}")
    return frames, durations


def shared_palette(frames):
    """Derive one adaptive palette from every frame of the animation stacked together."""
    w, h = frames[0].size
    stack = Image.new("RGB", (w, h * len(frames)))
    for i, f in enumerate(frames):
        stack.paste(f, (0, i * h))
    # MEDIANCUT over the union of frames; dithering off, because dithered noise differs between
    # frames and defeats the point of a shared palette.
    return stack.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def write_gif(name, frames, durations):
    GIF_DIR.mkdir(parents=True, exist_ok=True)
    out = GIF_DIR / f"{name}.gif"
    pal = shared_palette(frames)
    indexed = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    # optimize=False is deliberate: the optimiser rewrites per-frame palettes and undoes the
    # stability the shared palette was built for. disposal=2 clears each frame before the next,
    # so nothing from a previous window survives underneath.
    indexed[0].save(
        out,
        save_all=True,
        append_images=indexed[1:],
        duration=durations,
        loop=0,
        optimize=False,
        disposal=2,
    )
    check = Image.open(out)
    if check.n_frames != len(frames):
        sys.exit(f"{out.name}: wrote {len(frames)} frames but the file reports {check.n_frames}")
    return out, check.size, out.stat().st_size


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scale", type=float, default=1.0, help="resize factor applied to every frame")
    ap.add_argument("--only", default=None, help="build a single animation by name")
    a = ap.parse_args()

    anims = read_manifest()
    if a.only:
        if a.only not in anims:
            sys.exit(f"unknown animation {a.only!r}; manifest has: {', '.join(anims)}")
        anims = {a.only: anims[a.only]}

    total = 0
    for name, rows in anims.items():
        frames, durations = load_frames(rows, a.scale)
        out, size, nbytes = write_gif(name, frames, durations)
        total += nbytes
        print(
            f"{out.name:<28} {len(frames)} frames  {size[0]}x{size[1]}  "
            f"{sum(durations)/1000:.1f}s  {nbytes/1e6:.2f} MB"
        )
    print(f"\n{len(anims)} animaciones, {total/1e6:.2f} MB en {GIF_DIR}")


if __name__ == "__main__":
    main()
