"""The map towns' culture colours (2026-11-08): copies of KayKit's hexagons_medieval.png whose team-colour swatch
(row 3, column 0: the blue every KayKit building's roofs, flags and trims use; the sea uses another swatch) is
replaced by another swatch of the same atlas, so a town's buildings take its culture's colour and nothing else
changes. scripts/world/map_town.gd swaps them in.

    python tools/world/make_town_atlases.py

heartland  -> roof_red    (row 3, column 1)
southreach -> gold_straw  (row 1, column 3), ochre
northmark keeps KayKit's blue (no copy).
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "environment", "hexagons", "base", "hexagons_medieval.png")
OUT = os.path.join(ROOT, "assets", "environment", "custom", "map_towns")
W, H = 128, 256          # one swatch of the 8 x 4 atlas (1024 x 1024)
TEAM = (3, 0)            # (row, column)
VARIANTS = {"heartland": (3, 1), "southreach": (1, 3)}


def swatch_box(row, col):
    return (col * W, row * H, (col + 1) * W, (row + 1) * H)


def main():
    src = Image.open(SRC).convert("RGBA")
    assert src.size == (8 * W, 4 * H), src.size
    os.makedirs(OUT, exist_ok=True)
    for culture, (row, col) in VARIANTS.items():
        img = src.copy()
        img.paste(src.crop(swatch_box(row, col)), swatch_box(*TEAM)[:2])
        path = os.path.join(OUT, "hexagons_medieval_%s.png" % culture)
        img.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
