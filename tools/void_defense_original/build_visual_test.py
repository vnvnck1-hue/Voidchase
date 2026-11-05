"""Build the VOID DEFENSE original-art visual test scene from docs/void_defense_original/assembly.json.

  C:/Python314/python.exe tools/void_defense_original/build_visual_test.py

Reads  docs/void_defense_original/assembly.json  (layer order, PNG top-lefts, pivots, hero rigs)
Writes scenes/void_defense/VoidDefenseVisualTest.tscn

Layout (back to front, same order as assembly.json `layers`):
  VoidDefenseVisualTest (Node2D, scripts/void_defense/vd_visual_test.gd)
    Canvas (Node2D, 1672x941 source px; the script scales it to the 1920x1080 viewport)
      Background  far_background + main_platform (top-left anchored), 17 props (pivot anchored)
      Floor       tile_tint_* (reference_only) + selection_* tiles + ambient_cast_light (reference_only)
      Heroes      one Node2D per hero at rigs.root_px, parts at offset_from_root_px with offset=-pivot, z_index
                  Effects: muzzle flash / heal plus (pivot anchored)
      Monsters    boss + 3 voidlings: a Node2D wrapper at the feet pivot (hit punch / death tween target)
                  with the Sprite2D `sprite` inside (idle animation target)
      UI          HUD PNGs, top-left anchored
Also writes scenes/void_defense/vd_hit_vfx.tscn: the touch demo's monster hit particle systems
(`vfx_flash_strike_hit` star burst + `vfx_Lightning` strike, UnityParticles2D configs) extracted from
scenes/Touch_Game_demo.tscn under a plain Node2D root, so the hit controller can instance them.
reference_only layers are in the "vd_reference_only" group so the script can toggle them (key R).
Hero parts are generated from `rigs`, not from the flat layers; the script asserts both give the same
top-left so the rig reproduces the still image. Do not hand-edit the tscn: change this script and re-run.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSEMBLY = os.path.join(ROOT, "docs", "void_defense_original", "assembly.json")
OUT_SCENE = os.path.join(ROOT, "scenes", "void_defense", "VoidDefenseVisualTest.tscn")
SCRIPT = "res://scripts/void_defense/vd_visual_test.gd"
REF_GROUP = "vd_reference_only"

with open(ASSEMBLY, encoding="utf-8") as fp:
    A = json.load(fp)
ASSET_ROOT = A["asset_root"]
CANVAS = A["canvas_px"]
layers = A["layers"]
rigs = A["rigs"]

# ---------------------------------------------------------------- classify layers into groups (contiguous runs)
def group_of(path):
    if path.startswith("background/"):
        return "Background"
    if path.startswith("characters/effects/tile_tint_") or path.startswith("ui/selection_") or path == "characters/effects/ambient_cast_light.png":
        return "Floor"
    if path.startswith("characters/monsters/"):
        return "Monsters"
    if path.startswith("characters/"):
        return "Heroes"
    if path.startswith("ui/"):
        return "UI"
    raise ValueError(path)


def hero_of(path):
    """rig id for a hero part path (characters/<hero>/...), None for effects."""
    parts = path.split("/")
    if parts[0] == "characters" and parts[1] in rigs:
        return parts[1]
    return None


# the groups must be contiguous runs in layer order, otherwise splitting them into parent nodes changes draw order
seen = []
for l in layers:
    g = group_of(l["path"])
    if not seen or seen[-1] != g:
        assert g not in seen, "group %s is not a contiguous run in layer order (%s)" % (g, l["path"])
        seen.append(g)
GROUPS = seen

# the hero rigs must reproduce the flat layer top-lefts exactly
by_path = {l["path"]: l for l in layers}
for hero, rig in rigs.items():
    for p in rig["parts"]:
        l = by_path[p["path"]]
        tl = [rig["root_px"][i] + p["offset_from_root_px"][i] - p["pivot_px"][i] for i in range(2)]
        assert tl == l["position_px"], "rig %s part %s: %s != layer %s" % (hero, p["path"], tl, l["position_px"])
        assert p["pivot_px"] == l["pivot_px"]

# ---------------------------------------------------------------- tscn text
ext = []          # (id, path)
ext_ids = {}


def tex(path):
    if path not in ext_ids:
        ext_ids[path] = "Texture_%d" % (len(ext) + 1)
        ext.append((ext_ids[path], ASSET_ROOT + path))
    return ext_ids[path]


def node_name(path):
    return os.path.splitext(os.path.basename(path))[0]


def sprite(name, parent, path, pos, offset=None, z=None, groups=None, extra=""):
    head = '[node name="%s" type="Sprite2D" parent="%s"' % (name, parent)
    if groups:
        head += ' groups=["%s"]' % '", "'.join(groups)
    head += "]\n"
    body = ""
    if z:
        body += "z_index = %d\n" % z
    body += "position = Vector2(%d, %d)\n" % tuple(pos)
    body += 'texture = ExtResource("%s")\ncentered = false\n' % tex(path)
    if offset and (offset[0] or offset[1]):
        body += "offset = Vector2(%d, %d)\n" % tuple(offset)
    body += extra
    return head + body + "\n"


nodes = []
nodes.append('[node name="VoidDefenseVisualTest" type="Node2D"]\nscript = ExtResource("Script_1")\n\n')
nodes.append('[node name="Canvas" type="Node2D" parent="."]\n\n')
for g in GROUPS:
    nodes.append('[node name="%s" type="Node2D" parent="Canvas"]\n\n' % g)

hero_nodes_done = set()
effects_parent_done = False
for l in layers:
    path = l["path"]
    g = group_of(path)
    parent = "Canvas/%s" % g
    groups = [REF_GROUP] if l["reference_only"] else None
    pos = l["position_px"]
    piv = l["pivot_px"]
    name = node_name(path)
    if g == "Heroes":
        hero = hero_of(path)
        if hero is not None:
            if hero in hero_nodes_done:
                continue  # all parts of this hero were emitted from its rig
            hero_nodes_done.add(hero)
            rig = rigs[hero]
            nodes.append('[node name="%s" type="Node2D" parent="%s"]\nposition = Vector2(%d, %d)\n\n' % (hero, parent, rig["root_px"][0], rig["root_px"][1]))
            for p in rig["parts"]:
                nodes.append(sprite(node_name(p["path"]), "%s/%s" % (parent, hero), p["path"], p["offset_from_root_px"],
                                    offset=[-p["pivot_px"][0], -p["pivot_px"][1]], z=p["z_index"]))
            continue
        if not effects_parent_done:
            effects_parent_done = True
            nodes.append('[node name="Effects" type="Node2D" parent="%s"]\n\n' % parent)
        parent += "/Effects"
    if g == "Monsters":
        # wrapper at the feet pivot; the sprite inside keeps the same render (offset = -pivot)
        nodes.append('[node name="%s" type="Node2D" parent="%s"]\nposition = Vector2(%d, %d)\n\n' % (name, parent, pos[0] + piv[0], pos[1] + piv[1]))
        nodes.append(sprite("sprite", "%s/%s" % (parent, name), path, [0, 0], offset=[-piv[0], -piv[1]], groups=groups))
    elif g == "UI" or path in ("background/far_background.png", "background/main_platform.png", "background/reference_edge_matte.png"):
        # screen-anchored: PNG top-left at position, no pivot
        nodes.append(sprite(name, parent, path, pos, groups=groups))
    else:
        # pivot-anchored: node origin at the pivot (props ~centre, monsters feet, effects centre)
        nodes.append(sprite(name, parent, path, [pos[0] + piv[0], pos[1] + piv[1]], offset=[-piv[0], -piv[1]], groups=groups))

header = "[gd_scene load_steps=%d format=3]\n\n" % (len(ext) + 2)
header += '[ext_resource type="Script" path="%s" id="Script_1"]\n' % SCRIPT
for eid, epath in ext:
    header += '[ext_resource type="Texture2D" path="%s" id="%s"]\n' % (epath, eid)
header += "\n"
out = header + "".join(nodes)
out = "; generated by tools/void_defense_original/build_visual_test.py from docs/void_defense_original/assembly.json (canvas %dx%d) - do not hand-edit\n" % tuple(CANVAS) + out
os.makedirs(os.path.dirname(OUT_SCENE), exist_ok=True)
with open(OUT_SCENE, "w", encoding="utf-8", newline="\n") as fp:
    fp.write(out)
n_sprites = sum(1 for n in nodes if 'type="Sprite2D"' in n)
print("wrote %s: %d textures, %d sprites, groups %s, heroes %s" % (os.path.relpath(OUT_SCENE, ROOT), len(ext), n_sprites, GROUPS, list(hero_nodes_done)))

# ---------------------------------------------------------------- hit VFX sub-scene from the touch demo
import re

DEMO_SCENE = os.path.join(ROOT, "scenes", "Touch_Game_demo.tscn")
VFX_SCENE = os.path.join(ROOT, "scenes", "void_defense", "vd_hit_vfx.tscn")
DEMO_BODY = "battle_scene/Monster/Monster/body"
VFX_ROOTS = ("vfx_flash_strike_hit", "vfx_Lightning")

demo = open(DEMO_SCENE, encoding="utf-8").read()
demo_ext = {m.group(3): m.group(0) for m in re.finditer(r'\[ext_resource type="([^"]+)" path="([^"]+)" id="([^"]+)"\]', demo)}
blocks = re.findall(r'(\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"[^\]]*\]\n(?:.+\n)*)', demo)
vfx_blocks = []
for block, nname, ntype, nparent in blocks:
    rel = None
    if nparent == DEMO_BODY and nname in VFX_ROOTS:
        rel = "."
    elif nparent.startswith(DEMO_BODY + "/") and nparent[len(DEMO_BODY) + 1:].split("/")[0] in VFX_ROOTS:
        rel = nparent[len(DEMO_BODY) + 1:]
    if rel is None or nname == "Damages":
        continue  # "Damages" is the demo's fake damage-number particle; the hit controller draws real numbers
    assert "SubResource(" not in block, "hit vfx block %s uses a SubResource" % nname
    block = block.replace('parent="%s"' % nparent, 'parent="%s"' % rel, 1)
    if rel == ".":
        # the two systems sit at the sub-scene origin; the hit controller places the root at the hit point
        block = re.sub(r"\nposition = Vector2\([^)]*\)", "", block, count=1)
    vfx_blocks.append(block.rstrip("\n") + "\n\n")
used = []
for b in vfx_blocks:
    for eid in re.findall(r'ExtResource\("([^"]+)"\)', b):
        if eid not in used:
            used.append(eid)
assert len(vfx_blocks) >= 2, "hit vfx nodes not found in %s" % DEMO_SCENE
vfx = "; generated by tools/void_defense_original/build_visual_test.py from scenes/Touch_Game_demo.tscn (monster hit particle systems) - do not hand-edit\n"
vfx += "[gd_scene load_steps=%d format=3]\n\n" % (len(used) + 1)
for eid in used:
    vfx += demo_ext[eid] + "\n"
vfx += '\n[node name="HitVfx" type="Node2D"]\n\n' + "".join(vfx_blocks)
with open(VFX_SCENE, "w", encoding="utf-8", newline="\n") as fp:
    fp.write(vfx)
print("wrote %s: %d particle nodes, %d resources" % (os.path.relpath(VFX_SCENE, ROOT), len(vfx_blocks), len(used)))
