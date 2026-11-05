"""Second scene patch (run after apply_expansion.py): standing art per character.

  - `BG_all/stand_character` (StandingCharacter) shows the selected character's standing image;
    it gets a copy of the avatar's entrance track and its own shadow. The rigged Olivia avatar and
    the "Olivia" name image are hidden (no panel of the strip is Olivia).
  - the two empty panels get the portraits built by make_portraits.py; the half-cut last panel
    becomes Olivia's (portrait rendered from the rig by capture_olivia.gd) and selecting it shows
    the rigged avatar plus the "Olivia" name image.
  - characters_list.character_selected -> stand_character.show_character

Idempotent (marker line). Run from the project root: python tools/expand/apply_standing.py
"""
import json
import re
import sys

SCENE = sys.argv[1] if len(sys.argv) > 1 else "scenes/Touch_Game_demo_anim.tscn"
MARKER = "; standing characters by tools/expand/apply_standing.py"
# panel index -> standing texture (reading order of the strip; None = locked / no art)
STANDING = ["char_01.png", "char_02.png", "char_03.png", "char_07.png", "char_06.png", "char_04.png", "char_05.png", None]
# panel index -> source px -> world px scale (0 = StandingCharacter.pixel_scale, 0.32, for the ~1600-1800 px art).
# char_02.png was replaced 2026-11-04 by the user's 406x555 render: 0.941 keeps the old 522 px display height.
STANDING_SCALE = [0, 0.941, 0, 0, 0, 0, 0, 0]
# panel index -> idle sprite sheet (png + json next to it in assets/textures/standing/, made by
# tools/expand/make_idle_sheet.py). The json's scale overrides STANDING_SCALE for that panel.
STANDING_SHEET = {1: "char_02_idle", 3: "char_07_idle"}  # panel 4 = char_07 (blonde maid), from assets/textures/gif/maid-idle-transparent.gif
NEW_PANELS = {"Panel_04": "new_panel_04.png", "Panel_05": "new_panel_05.png", "Panel_08": "new_panel_08.png"}
LOCKED = []
RIGGED_INDEX = 7  # Panel_08 = Olivia: shown with the rigged avatar instead of a still image
# panel index -> (node name, rig scene, scale): a rigged character scene instanced under stand_character
# (feet at its origin, its own AnimationPlayer idle), shown instead of the still image / sheet.
# Panel 6 (index 5, char_04 = black-haired maid) -> the maid v2 bone rig built by tools/rig/build_maid_rig.py;
# 0.32 = StandingCharacter.pixel_scale (the rig is in 1325x1790 canvas px).
RIGS = {5: ("rig_maid", "res://scenes/characters/maid_rig.tscn", 0.32)}

src = open(SCENE, encoding="utf-8").read()
scales = list(STANDING_SCALE)
sheet_meta = {}
for idx, name in STANDING_SHEET.items():
    with open("assets/textures/standing/%s.json" % name, encoding="utf-8") as fp:
        sheet_meta[idx] = json.load(fp)
    scales[idx] = sheet_meta[idx]["scale"]
SCALES_LINE = "texture_scales = Array[float]([%s])\n" % ", ".join("%g" % v for v in scales)
N = len(STANDING)


def ensure_ext(src, rtype, path, prefix):
    """id of the ext_resource of type `rtype` for `path`, adding one after the last ext_resource if missing."""
    m = re.search(r'\[ext_resource type="%s" path="%s" id="([^"]+)"\]' % (rtype, re.escape(path)), src)
    if m:
        return src, m.group(1)
    ids = re.findall(r'id="(?:Texture|Script|Shader|Animation|AnimationLibrary|PackedScene)_(\d+)"', src)
    tid = "%s_%d" % (prefix, max(int(i) for i in ids) + 1)
    last = list(re.finditer(r'\[ext_resource [^\]]*\]\n', src))[-1]
    src = src[:last.end()] + '[ext_resource type="%s" path="%s" id="%s"]\n' % (rtype, path, tid) + src[last.end():]
    return src, tid


def ensure_ext_texture(src, path):
    return ensure_ext(src, "Texture2D", path, "Texture")


def apply_rigs(src):
    """Rig instance nodes under stand_character (after its Sprite, before characters_list) and the
    `rigs` property line of stand_character. Idempotent: existing rig nodes / line are rewritten."""
    paths = ['NodePath("")'] * N
    for idx, (name, scene, scale) in RIGS.items():
        src, sid = ensure_ext(src, "PackedScene", scene, "PackedScene")
        block = ('[node name="%s" parent="BG_all/stand_character" instance=ExtResource("%s")]\n'
                 "visible = false\nprocess_mode = 4\nscale = Vector2(%g, %g)\n\n") % (name, sid, scale, scale)
        old = re.search(r'\[node name="%s" parent="BG_all/stand_character" instance=[^\]]*\]\n(?:.+\n)*\n' % name, src)
        if old:
            src = src.replace(old.group(0), block, 1)
        else:
            cl = src.index('[node name="characters_list" type="Node2D" parent="BG_all"]')
            src = src[:cl] + block + src[cl:]
        paths[idx] = 'NodePath("%s")' % name
    rigs_line = "rigs = Array[NodePath]([%s])\n" % ", ".join(paths)
    node = re.search(r'\[node name="stand_character" type="Node2D" parent="BG_all"\]\n(?:.+\n)+', src)
    block = node.group(0)
    nb = re.sub(r'^rigs = .*\n', "", block, flags=re.M)
    nb = nb.replace("rigged_avatar = ", rigs_line + "rigged_avatar = ", 1)
    return src.replace(block, nb, 1)


def sheet_lines(src):
    """(src with ext_resources, the four sheet property lines)"""
    tex, grids, counts, fps = [], [], [], []
    for i in range(N):
        m = sheet_meta.get(i)
        if m:
            src, tid = ensure_ext_texture(src, "res://assets/textures/standing/%s.png" % STANDING_SHEET[i])
            tex.append('ExtResource("%s")' % tid)
            grids.append("Vector2i(%d, %d)" % (m["hframes"], m["vframes"]))
            counts.append(str(m["count"]))
            fps.append("%g" % m["fps"])
        else:
            tex.append("null"); grids.append("Vector2i(1, 1)"); counts.append("0"); fps.append("0")
    lines = (
        "sheets = Array[Texture2D]([%s])\n" % ", ".join(tex)
        + "sheet_grids = Array[Vector2i]([%s])\n" % ", ".join(grids)
        + "sheet_counts = Array[int]([%s])\n" % ", ".join(counts)
        + "sheet_fps = Array[float]([%s])\n" % ", ".join(fps)
    )
    return src, lines


if MARKER in src:
    # already patched: only re-sync the per-panel scale / sheet lines of the stand_character node
    src, SHEET_LINES = sheet_lines(src)
    node = re.search(r'\[node name="stand_character" type="Node2D" parent="BG_all"\]\n(?:.+\n)+', src)
    block = node.group(0)
    nb = re.sub(r'^(texture_scales|sheets|sheet_grids|sheet_counts|sheet_fps) = .*\n', "", block, flags=re.M)
    nb = nb.replace("rigged_avatar = ", SCALES_LINE + SHEET_LINES + "rigged_avatar = ", 1)
    new_src = src.replace(block, nb, 1)
    new_src = apply_rigs(new_src)
    steps = len(re.findall(r'\[ext_resource ', new_src)) + len(re.findall(r'\[sub_resource ', new_src)) + 1
    new_src = re.sub(r'^\[gd_scene load_steps=\d+ format=3\]', "[gd_scene load_steps=%d format=3]" % steps, new_src, count=1, flags=re.M)
    if new_src != open(SCENE, encoding="utf-8").read():
        open(SCENE, "w", encoding="utf-8", newline="\n").write(new_src)
        print("already applied; refreshed texture_scales / sheets / rigs:", SCENE)
    else:
        print("already applied:", SCENE)
    sys.exit(0)
assert "; expanded by tools/expand/apply_expansion.py" in src, "run apply_expansion.py first"

ids = re.findall(r'id="(?:Texture|Script|Shader|Animation|AnimationLibrary)_(\d+)"', src)
next_id = max(int(i) for i in ids) + 1
ext_lines = []


def add_ext(rtype, path):
    global next_id
    i = "%s_%d" % ({"Texture2D": "Texture", "Script": "Script"}[rtype], next_id)
    next_id += 1
    ext_lines.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, i))
    return i


stand_script = add_ext("Script", "res://scripts/standing_character.gd")
stand_tex = [add_ext("Texture2D", "res://assets/textures/standing/" + f) if f else None for f in STANDING]
panel_tex = {name: add_ext("Texture2D", "res://assets/textures/char_panels/" + f) for name, f in NEW_PANELS.items()}
last_ext = list(re.finditer(r'\[ext_resource [^\]]*\]\n', src))[-1]
src = src[:last_ext.end()] + "\n".join(ext_lines) + "\n" + src[last_ext.end():]

# ---- entrance animation: duplicate the avatar track for stand_character
m = re.search(r'\[sub_resource type="Animation" id="(\w+)"\]\nresource_name = "entrance"\n(.*?)(?=\n\[sub_resource|\n\[node)', src, re.S)
assert m, "entrance animation not found"
body = m.group(2)
idx = [int(i) for i in re.findall(r'^tracks/(\d+)/type', body, re.M)]
avatar_i = int(re.search(r'tracks/(\d+)/path = NodePath\("avatar:position"\)', body).group(1))
chunk = re.search(r'(tracks/%d/type = .*?\n\}\n)' % avatar_i, body, re.S).group(1)
new_i = max(idx) + 1
copy = re.sub(r'tracks/%d/' % avatar_i, "tracks/%d/" % new_i, chunk).replace('NodePath("avatar:position")', 'NodePath("stand_character:position")')
body_new = body.rstrip("\n") + "\n" + copy.rstrip("\n")
src = src[:m.start(2)] + body_new + src[m.end(2):]

# ---- hide the rigged avatar and the Olivia name
av = re.search(r'\[node name="avatar" type="Node2D" parent="BG_all"\]\n', src)
src = src[:av.end()] + "visible = false\nprocess_mode = 4\n" + src[av.end():]
nm = re.search(r'\[node name="olivia_2" type="Sprite2D" parent="BG_all"\]\n(?:.+\n)+', src)
block = nm.group(0)
src = src.replace(block, block.rstrip("\n") + "\nvisible = false\n\n", 1)

# ---- stand_character node (before characters_list so it is ready first and draws under the strip)
av_pos = re.search(r'\[node name="avatar" type="Node2D" parent="BG_all"\]\n(?:.*\n)*?position = Vector2\(([^)]*)\)', src).group(1)
av_scale = float(re.search(r'\[node name="avatar" type="Node2D" parent="BG_all"\]\n(?:.*\n)*?scale = Vector2\(([-\d.e]+),', src).group(1))
shadow = re.search(r'\[node name="Shadow" type="Sprite2D" parent="BG_all/avatar"\]\n(?:.+\n)+', src).group(0)
sh_pos = [float(v) for v in re.search(r'position = Vector2\(([^)]*)\)', shadow).group(1).split(",")]
sh_scale = [float(v) for v in re.search(r'scale = Vector2\(([^)]*)\)', shadow).group(1).split(",")]
shadow_new = shadow.replace('parent="BG_all/avatar"', 'parent="BG_all/stand_character"')
shadow_new = re.sub(r'position = Vector2\([^)]*\)', "position = Vector2(%r, %r)" % (sh_pos[0] * av_scale, sh_pos[1] * av_scale), shadow_new)
shadow_new = re.sub(r'scale = Vector2\([^)]*\)', "scale = Vector2(%r, %r)" % (sh_scale[0] * av_scale, sh_scale[1] * av_scale), shadow_new)
tex_arr = ", ".join('ExtResource("%s")' % t if t else "null" for t in stand_tex)
src, SHEET_LINES = sheet_lines(src)
stand_nodes = (
    '[node name="stand_character" type="Node2D" parent="BG_all"]\n'
    "position = Vector2(%s)\n"
    'script = ExtResource("%s")\n'
    "textures = Array[Texture2D]([%s])\n"
    "%s%s"
    'rigged_avatar = NodePath("../avatar")\n'
    'name_sprite = NodePath("../olivia_2")\n'
    "rigged_index = %d\n\n"
    "%s\n"
    '[node name="Sprite" type="Sprite2D" parent="BG_all/stand_character"]\n'
    "centered = false\n\n"
) % (av_pos, stand_script, tex_arr, SCALES_LINE, SHEET_LINES, RIGGED_INDEX, shadow_new.rstrip("\n") + "\n")
cl = src.index('[node name="characters_list" type="Node2D" parent="BG_all"]')
src = src[:cl] + stand_nodes + src[cl:]
src = apply_rigs(src)

# ---- panels: new portraits + locked flag
for name, tid in panel_tex.items():
    pm = re.search(r'\[node name="%s" type="Sprite2D" parent="BG_all/characters_list"\]\n(?:.+\n)+' % name, src)
    block = pm.group(0)
    nb = re.sub(r'texture = ExtResource\("[^"]+"\)', 'texture = ExtResource("%s")' % tid, block)
    nb = nb.replace("metadata/empty = true", "metadata/empty = false")
    src = src.replace(block, nb, 1)
for name in LOCKED:
    pm = re.search(r'\[node name="%s" type="Sprite2D" parent="BG_all/characters_list"\]\n(?:.+\n)+' % name, src)
    block = pm.group(0)
    src = src.replace(block, block.rstrip("\n") + "\nmetadata/locked = true\n\n", 1)

# ---- signal connection
src = src.rstrip("\n") + '\n\n[connection signal="character_selected" from="BG_all/characters_list" to="BG_all/stand_character" method="show_character"]\n'

steps = len(re.findall(r'\[ext_resource ', src)) + len(re.findall(r'\[sub_resource ', src)) + 1
src = re.sub(r'^\[gd_scene load_steps=\d+ format=3\]\n', "[gd_scene load_steps=%d format=3]\n%s\n" % (steps, MARKER), src, count=1, flags=re.M)
open(SCENE, "w", encoding="utf-8", newline="\n").write(src)
print("patched", SCENE)
