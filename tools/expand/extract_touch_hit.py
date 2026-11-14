"""터치 게임 데모(scenes/Touch_Game_demo.tscn)의 몬스터 피격 파티클을 떼어 VOID DEFENSE 용 씬으로 만든다.

  vfx_flash_strike_hit (노란 별 섬광 star_ab · star_add · glow_add + 데미지 숫자 Damages)
  vfx_Lightning        (번개 add · ab · down + glow · dust)

→ scenes/void_defense/vd_touch_hit.tscn  (루트 TouchHit = scripts/void_defense/vd_touch_hit.gd)
   flash 를 원점에 두고 lightning 은 데모와 같은 상대 위치. 데모의 절대 z(7~100)는 상대 z 로 바꿔
   VOID DEFENSE 의 fx_root 안에서 순서만 지키게 한다. 파티클 설정(config)은 데모 그대로 복사한다.

Touch_Game_demo.tscn 을 다시 생성했으면 이 스크립트도 다시 돌린다:
  python tools/expand/extract_touch_hit.py
"""
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "scenes", "Touch_Game_demo.tscn")
DST = os.path.join(ROOT, "scenes", "void_defense", "vd_touch_hit.tscn")
BODY = "battle_scene/Monster/Monster/body"
# 데모 노드 경로 → 새 씬 경로
RENAME = {BODY + "/vfx_flash_strike_hit": "flash", BODY + "/vfx_Lightning": "lightning"}
# 새 상대 z (부모 기준). 번개 < 섬광 < 숫자 순서는 데모와 같다
Z = {
    "flash": 1, "flash/star_ab": 2, "flash/star_ab/star_add": 1, "flash/star_ab/glow_add": 1, "flash/star_ab/Damages": 3,
    "lightning": 0, "lightning/vfx_Lightning_ab": 0, "lightning/vfx_Lightning_down": 0, "lightning/vfx_Lightning_add": 1,
    "lightning/vfx_Lightning_glow": 2, "lightning/vfx_Lightning_dust": 2,
}


def blocks(text):
    out, cur = [], []
    for line in text.split("\n"):
        if line.startswith("[") and cur:
            out.append(cur)
            cur = []
        cur.append(line)
    if cur:
        out.append(cur)
    return out


def node_path(head):
    name = re.search(r'name="([^"]+)"', head).group(1)
    m = re.search(r'parent="([^"]+)"', head)
    if not m:
        return None, name
    parent = m.group(1)
    return (name if parent == "." else parent + "/" + name), name


def main():
    text = open(SRC, encoding="utf-8").read()
    bl = blocks(text)
    ext = {}
    for b in bl:
        if b[0].startswith("[ext_resource"):
            ext[re.search(r'id="([^"]+)"', b[0]).group(1)] = b[0]
    flash_pos = None
    nodes = []
    for b in bl:
        if not b[0].startswith("[node"):
            continue
        path, name = node_path(b[0])
        if path is None:
            continue
        new = None
        for old, nn in RENAME.items():
            if path == old:
                new = nn
            elif path.startswith(old + "/"):
                new = nn + path[len(old):]
        if new is None:
            continue
        nodes.append((path, new, b))
        if new == "flash":
            flash_pos = re.search(r"position = Vector2\(([^)]+)\)", "\n".join(b)).group(1)
    fx, fy = [float(v) for v in flash_pos.split(",")]

    used = set()
    body = []
    for path, new, b in nodes:
        parent = new.rsplit("/", 1)[0] if "/" in new else "."
        name = new.rsplit("/", 1)[-1]
        head = re.sub(r'parent="[^"]+"', 'parent="%s"' % parent, b[0])
        head = re.sub(r'name="[^"]+"', 'name="%s"' % name, head)
        lines = [head]
        for l in b[1:]:
            if l.startswith("z_index ="):
                l = "z_index = %d" % Z[new]
            elif l.startswith("z_as_relative ="):
                l = "z_as_relative = true"
            elif l.startswith("position =") and new in ("flash", "lightning"):
                x, y = [float(v) for v in re.search(r"\(([^)]+)\)", l).group(1).split(",")]
                l = "position = Vector2(%r, %r)" % (x - fx, y - fy)
            lines.append(l)
        for rid in re.findall(r'ExtResource\("([^"]+)"\)', "\n".join(lines)):
            used.add(rid)
        while lines and lines[-1] == "":
            lines.pop()
        body.append("\n".join(lines))

    order = [rid for rid in ext if rid in used]
    out = ['[gd_scene load_steps=%d format=3]' % (len(order) + 2), ""]
    for rid in order:
        out.append(ext[rid])
    out.append('[ext_resource type="Script" path="res://scripts/void_defense/vd_touch_hit.gd" id="Script_root"]')
    out.append("")
    out.append('[node name="TouchHit" type="Node2D"]')
    out.append('script = ExtResource("Script_root")')
    out.append("")
    out.append("\n\n".join(body))
    out.append("")
    open(DST, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("wrote", DST, len(nodes), "nodes,", len(order), "resources")


if __name__ == "__main__":
    main()
