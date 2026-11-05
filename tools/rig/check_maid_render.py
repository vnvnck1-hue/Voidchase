"""Compare the Godot render of the maid rig's setup pose with the reference, and build the idle previews.

  python tools/rig/check_maid_render.py

Reads  docs/maid_rig/setup_render.png (from tools/rig/capture_maid.gd), spine_parts_maid_v2/setup-pose.png,
       docs/maid_rig/idle/frame_*.png
Writes docs/maid_rig/setup_diff.png   (pixels whose channel difference > 8, in red, over a faded reference)
       docs/maid_rig/idle_sheet.png   (contact sheet of the idle frames)
       docs/maid_rig/idle_preview.gif (the idle loop)
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "maid_rig")


def main():
    ref = np.asarray(Image.open(os.path.join(ROOT, "spine_parts_maid_v2", "setup-pose.png")).convert("RGBA")).astype(int)
    got = np.asarray(Image.open(os.path.join(OUT, "setup_render.png")).convert("RGBA")).astype(int)
    assert ref.shape == got.shape, (ref.shape, got.shape)
    # compare premultiplied colour so fully transparent pixels with junk rgb do not count
    def pre(a):
        al = a[..., 3:4] / 255.0
        return np.concatenate([a[..., :3] * al, a[..., 3:4]], -1)
    diff = np.abs(pre(ref) - pre(got)).max(-1)
    bad = diff > 8
    total = bad.size
    print("setup pose vs reference: %d / %d pixels differ by more than 8 (%.3f%%), max diff %d" % (
        bad.sum(), total, 100.0 * bad.sum() / total, diff.max()))
    vis = (ref[..., :3] * 0.35 + 255 * 0.65).astype(np.uint8)
    vis[bad] = (255, 0, 0)
    Image.fromarray(vis).save(os.path.join(OUT, "setup_diff.png"))

    frames = [Image.open(p).convert("RGBA") for p in sorted(glob.glob(os.path.join(OUT, "idle", "frame_*.png")))]
    if not frames:
        print("no idle frames")
        return
    w, h = frames[0].size
    pick = frames[:: max(1, len(frames) // 12)][:12]
    cols = 6
    rows = (len(pick) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * w, rows * h), (255, 255, 255, 255))
    for i, f in enumerate(pick):
        sheet.paste(f, ((i % cols) * w, (i // cols) * h), f)
    sheet.save(os.path.join(OUT, "idle_sheet.png"))
    small = []
    for f in frames:
        bg = Image.new("RGBA", f.size, (255, 255, 255, 255))
        bg.paste(f, (0, 0), f)
        small.append(bg.convert("RGB").resize((w // 2, h // 2), Image.LANCZOS).convert("P", palette=Image.ADAPTIVE, colors=128))
    small[0].save(os.path.join(OUT, "idle_preview.gif"), save_all=True, append_images=small[1:],
                  duration=int(1000 / 15), loop=0, optimize=False)
    print("wrote idle_sheet.png (%d frames) and idle_preview.gif (%d frames)" % (len(pick), len(frames)))

    # face close-up: gif at the capture rate (60 fps -> 30 fps gif, every other frame) + a strip of the first blink
    face = sorted(glob.glob(os.path.join(OUT, "face", "frame_*.png")))
    if not face:
        return
    fr = [Image.open(p).convert("RGBA") for p in face]
    def on_white(f):
        bg = Image.new("RGBA", f.size, (255, 255, 255, 255))
        bg.paste(f, (0, 0), f)
        return bg.convert("RGB")
    gif = [on_white(f).convert("P", palette=Image.ADAPTIVE, colors=128) for f in fr[::2]]
    gif[0].save(os.path.join(OUT, "face_preview.gif"), save_all=True, append_images=gif[1:], duration=33, loop=0, optimize=False)
    # strip: 12 frames from the first blink (every 2nd frame from its start) and 8 from the glance
    import json, re
    fps = len(fr) / 5.0666667
    def strip(indices, name):
        w, h = fr[0].size
        cols = len(indices)
        s = Image.new("RGB", (cols * (w // 2 + 4), h // 2 + 18), (255, 255, 255))
        from PIL import ImageDraw
        d = ImageDraw.Draw(s)
        for j, i in enumerate(indices):
            im = on_white(fr[i]).resize((w // 2, h // 2), Image.LANCZOS)
            s.paste(im, (j * (w // 2 + 4), 18))
            d.text((j * (w // 2 + 4) + 2, 2), "t=%.3f" % (i / fps), fill=(0, 0, 0))
        s.save(os.path.join(OUT, name))
    b0 = int(round(0.50 * fps))
    strip([b0 + 2 * k for k in range(12)], "face_blink_strip.png")
    g0 = int(round(1.90 * fps))
    strip([g0 + 4 * k for k in range(12)], "face_glance_strip.png")
    r0 = int(round(3.30 * fps))
    strip([r0 + 3 * k for k in range(12)], "face_return_strip.png")
    print("wrote face_preview.gif (%d frames) and face strips" % len(gif))


if __name__ == "__main__":
    main()
