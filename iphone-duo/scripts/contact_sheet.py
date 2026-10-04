#!/usr/bin/env python3
"""Lay out the frames of an animation whose watched region changes, one per row, so direction, path and
cross-fades can be judged in a single image.

Usage: contact_sheet.py <dir-with-f_###.png> [--crop x,y,w,h] [--max 16]
Writes <dir>/sheet.png and prints the frame numbers used. Needs Pillow.
"""
import argparse, glob, os
from PIL import Image, ImageChops

def changed_frames(frames, box):
    out = []
    for i in range(1, len(frames)):
        a = frames[i - 1].crop(box).convert("L")
        b = frames[i].crop(box).convert("L")
        if ImageChops.difference(a, b).getbbox():
            out.append(i)
    return out

def main():
    p = argparse.ArgumentParser()
    p.add_argument("dir")
    p.add_argument("--crop", help="x,y,w,h in frame pixels")
    p.add_argument("--max", type=int, default=16)
    a = p.parse_args()
    paths = sorted(glob.glob(os.path.join(a.dir, "f_*.png")))
    if not paths:
        raise SystemExit("no frames in " + a.dir)
    frames = [Image.open(f) for f in paths]
    w, h = frames[0].size
    if a.crop:
        x, y, cw, ch = (int(v) for v in a.crop.split(","))
        box = (x, y, x + cw, y + ch)
    else:
        box = (0, 0, w, h)
    idx = changed_frames(frames, box)
    if not idx:
        print("watched region never changed")
        return
    # keep evenly spaced frames if there are too many
    if len(idx) > a.max:
        step = len(idx) / a.max
        idx = [idx[int(k * step)] for k in range(a.max)]
    bw, bh = box[2] - box[0], box[3] - box[1]
    sheet = Image.new("RGB", (bw, bh * len(idx)), "white")
    for row, i in enumerate(idx):
        sheet.paste(frames[i].crop(box), (0, row * bh))
    sheet.save(os.path.join(a.dir, "sheet.png"))
    print("frames:", idx, "->", os.path.join(a.dir, "sheet.png"))

if __name__ == "__main__":
    main()
