"""Make the in-game loading mascot sheet from the chosen concept (A 카드 메이드).

  C:/Python314/python.exe tools/loading/build_loading_sheet.py

Source: docs/loading_concepts_v1/a_card_maid_sheet.png (1774x887, 4x2, uneven cells; areas from sheets.json).
The concept cells don't share a ground line or a horizontal centre, so each frame is re-placed on a uniform
448x448 cell (sheet 1792x896, opaque black like the source):
  - horizontal: the feet (bottom 40 px of the silhouette) are centred in the cell.
  - vertical: the standing frames (0, 1, 5, 6, 7) get their feet on one ground line; the airborne frames
    (2, 3, 4) keep their height above the ground by moving with the standing frames' mean shift.
Writes assets/textures/loading/card_maid_sheet.png (docs/* is excluded from the export).
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(ROOT, "docs", "loading_concepts_v1")
SRC = os.path.join(SRC_DIR, "a_card_maid_sheet.png")
OUT = os.path.join(ROOT, "assets", "textures", "loading", "card_maid_sheet.png")
CELL = 448
COLS, ROWS = 4, 2
GROUND = 424          # feet line inside the new cell
GROUNDED = {0, 1, 5, 6, 7}
THRESHOLD = 60        # luminance above this counts as the white figure
FEET_BAND = 40


def silhouette(cell):
    return cell.convert("L").point(lambda v: 255 if v > THRESHOLD else 0)


def main():
    frames = json.load(open(os.path.join(SRC_DIR, "sheets.json"), encoding="utf-8"))["frames"]
    src = Image.open(SRC).convert("RGB")
    cells, places = [], []
    for f in frames:
        cell = src.crop((f["x"], f["y"], f["x"] + f["width"], f["y"] + f["height"]))
        bb = silhouette(cell).getbbox()
        bottom = bb[3]
        feet = silhouette(cell).crop((0, bottom - FEET_BAND, cell.width, bottom)).getbbox()
        cells.append(cell)
        places.append({"feet_cx": (feet[0] + feet[2]) / 2.0, "bottom": bottom})
    grounded_dy = [GROUND - places[i]["bottom"] for i in GROUNDED]
    air_dy = round(sum(grounded_dy) / len(grounded_dy))
    sheet = Image.new("RGB", (CELL * COLS, CELL * ROWS), (0, 0, 0))
    for i, cell in enumerate(cells):
        dx = round(CELL / 2 - places[i]["feet_cx"])
        dy = GROUND - places[i]["bottom"] if i in GROUNDED else air_dy
        col, row = i % COLS, i // COLS
        tile = Image.new("RGB", (CELL, CELL), (0, 0, 0))
        tile.paste(cell, (dx, dy))
        sheet.paste(tile, (col * CELL, row * CELL))
        print("frame %d  dx %+d  dy %+d" % (i, dx, dy))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), sheet.size)


if __name__ == "__main__":
    main()
