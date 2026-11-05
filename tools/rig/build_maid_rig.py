"""Build the maid (spine_parts_maid_v2) bone rig + idle animation as a Godot scene.

  python tools/rig/build_maid_rig.py

Reads  spine_parts_maid_v2/layout.json (+ images/*.png)
Writes assets/textures/maid_rig/<part>.png   (copies; the v2 folder is .gdignore'd)
       scenes/characters/maid_rig.tscn       (Skeleton2D + Bone2D rig, Sprite2D parts,
                                              iris clip masks, AnimationPlayer: RESET / idle / rig_check)

Rig conventions (same as the Olivia rig): the scene origin is the floor centre of the 1325x1790
canvas, units are canvas pixels (y down), every bone has rotation 0 in the setup pose, so a part's
local position is simply (png centre - bone pivot). Draw order = layout drawOrder as a relative
z_index on each part. The two irises sit inside a Polygon2D that clips its children to the eye
aperture, so gaze can move without leaking over the lids. Do not hand-edit the tscn: change this
script (bone table / CURVES) and re-run it.
"""
import json
import math
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "spine_parts_maid_v2")
TEX_DIR = "assets/textures/maid_rig"
OUT_SCENE = "scenes/characters/maid_rig.tscn"

# ---------------------------------------------------------------- bones (canvas pivots, handoff doc)
# name, parent, pivot
BONES = [
    ("pelvis", None, (395, 979)),
    ("skirt", "pelvis", (395, 979)),
    ("thigh_l", "pelvis", (301, 1174)),
    ("shin_l", "thigh_l", (320, 1428)),
    ("foot_l", "shin_l", (372, 1682)),
    ("thigh_r", "pelvis", (519, 1173)),
    ("shin_r", "thigh_r", (638, 1406)),
    ("foot_r", "shin_r", (706, 1712)),
    ("torso", "pelvis", (413, 975)),
    ("apron", "torso", (390, 965)),
    ("upper_arm_l", "torso", (345, 836)),
    ("forearm_l", "upper_arm_l", (223, 903)),
    ("hand_l", "forearm_l", (129, 1060)),
    ("upper_arm_r", "torso", (638, 849)),
    ("forearm_r", "upper_arm_r", (700, 1001)),
    ("hand_r", "forearm_r", (839, 1312)),
    ("neck", "torso", (550, 757)),
    ("head", "neck", (550, 757)),
    ("ponytail", "head", (826, 190)),
    ("side_hair_l", "head", (222, 414)),
    ("side_hair_r", "head", (708, 409)),
    ("fringe", "head", (486, 274)),
    ("headpiece", "head", (488, 180)),
    ("eye_l", "head", (336, 543)),     # pivot on the lash line: scaling y squashes white + iris up into the lid
    ("eye_r", "head", (594, 491)),
    ("lid_l", "head", (336, 490)),     # pivot on the top edge of the lash stroke: scaling y pulls the lash down
    ("lid_r", "head", (594, 447)),
    ("brow_l", "head", (307, 448)),
    ("brow_r", "head", (600, 395)),
    ("mouth", "head", (506, 716)),
    ("heart_fx", None, (72, 370)),
]

# part -> bone
PART_BONE = {
    "hair_ponytail": "ponytail",
    "hand_screen_left": "hand_l",
    "upper_arm_screen_left": "upper_arm_l",
    "forearm_cuff_screen_left": "forearm_l",
    "shin_screen_left": "shin_l",
    "shoe_screen_left": "foot_l",
    "thigh_screen_left": "thigh_l",
    "shin_screen_right": "shin_r",
    "shoe_screen_right": "foot_r",
    "thigh_screen_right": "thigh_r",
    "dress_bodice": "torso",
    "dress_skirt": "skirt",
    "neck_collar": "neck",
    "apron": "apron",
    "hand_screen_right": "hand_r",
    "forearm_cuff_screen_right": "forearm_r",
    "upper_arm_screen_right": "upper_arm_r",
    "hair_side_screen_left": "side_hair_l",
    "face_base": "head",
    "eye_white_screen_left": "eye_l",
    "eye_white_screen_right": "eye_r",
    "iris_screen_left": "eye_l",      # inside the clip polygon under eye_l
    "iris_screen_right": "eye_r",
    "upper_lid_screen_left": "lid_l",   # the lash stroke: comes down over the squashed eye in a blink
    "upper_lid_screen_right": "lid_r",
    "brow_screen_left": "brow_l",
    "brow_screen_right": "brow_r",
    "mouth": "mouth",
    "hair_side_screen_right": "side_hair_r",
    "hair_fringe": "fringe",
    "headpiece": "headpiece",
    "fx_heart": "heart_fx",
}
CLIP_OF = {"iris_screen_left": ("clip_iris_l", "aperture-left", "eye_l"),
           "iris_screen_right": ("clip_iris_r", "aperture-right", "eye_r")}

# ---------------------------------------------------------------- idle motion
BREATH = 2.5333333  # s, same period as the Olivia idle / procedural idle
LENGTH = 2 * BREATH  # one sway per two breaths
FPS = 60             # Olivia's idle is 60 fps too; a 0.15 s blink needs the resolution
W = 2 * math.pi / BREATH   # breath
S = W / 2                  # sway
D2R = math.pi / 180.0


def _ease_io(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


def _ease_out(u):
    u = min(max(u, 0.0), 1.0)
    return 1.0 - (1.0 - u) ** 2


# ---- eyes, modelled on the Olivia idle (main_character_idle_2, eyes_1 / eyes_2 / eyes_3 tracks):
#  * sclera bone (eyes_2) squashes along its axis 1 -> 0.60 in 0.15 s (S-curve), holds one frame, opens in 0.10 s (ease-out);
#  * lid piece (eyes_1) creeps +3 % before the squash starts, then grows x1.45 in 0.08 s lagging the sclera, overshoots
#    slightly below rest on the way back and relaxes to +3 % over 0.3 s; between blinks it drifts slowly -6 %..+3 %;
#  * blinks come in pairs ~1.2-1.35 s apart, the second one hiding a gaze snap;
#  * pupil (eyes_3) glides 37 units sideways in 0.52 s (S-curve), holds with a 3-unit relax and a slow perpendicular
#    wobble, widens 20 % over the hold, snaps back in 3 frames while the eye is shut, overshoots past centre and settles
#    with one damped swing; the width springs back with a bounce.
# The maid's lid is only a lash stroke (no skin patch), so instead of growing it like Olivia's lid piece the stroke
# travels down LID_DROP px (thickening a little, x LID_PEAK) while the white + iris squash to EYE_CLOSED toward the
# lash line; at the shut frame the stroke's lower edge sits on the squashed eye, leaving the same pale sliver Olivia keeps.
BLINKS = [0.55, 3.35, 4.35]       # blink starts (s); gaps 2.8 / 1.0 / 1.27 (loop)
EYE_CLOSED = 0.22
LID_DROP = 22.0
LID_PEAK = 1.15
EYE_R_DELAY = 0.015               # the far eye trails by one frame
GLANCE = {"start": 1.95, "move": 0.52, "dx": -42.0, "dy": 2.0, "return_blink": 1,  # dx < 0 = screen left
          "relax": 3.0, "widen": 0.10}


def _wrap(t):
    return (t, t - LENGTH, t + LENGTH)


def blink_eye(t):
    """scale.y of the eye bone (white + clipped iris)."""
    v = 1.0
    for T in BLINKS:
        for tt in _wrap(t):
            u = tt - T
            if 0.0 <= u < 0.15:
                k = _ease_io(u / 0.15)
            elif 0.15 <= u < 0.167:
                k = 1.0
            elif 0.167 <= u < 0.267:
                k = 1.0 - _ease_out((u - 0.167) / 0.10)
            else:
                continue
            v = min(v, 1.0 + (EYE_CLOSED - 1.0) * k)
    return v


def lid_shape(t):
    """Lid travel as a fraction of the blink peak (Olivia eyes_1 profile): +0.055 anticipation creep, 1.0 at the
    shut frame (lagging the eye squash), -0.027 overshoot on the way up, relaxing to +0.055; +0.055 between blinks."""
    for T in BLINKS:
        for tt in _wrap(t):
            u = tt - T
            if -0.10 <= u < 0.067:
                return 0.055 * (u + 0.10) / 0.167
            if 0.067 <= u < 0.15:
                return 0.055 + 0.945 * _ease_io((u - 0.067) / 0.083)
            if 0.15 <= u < 0.233:
                return 1.0 + (-0.027 - 1.0) * _ease_out((u - 0.15) / 0.083)
            if 0.233 <= u < 0.52:
                return -0.027 + 0.082 * _ease_io((u - 0.233) / 0.287)
    return 0.055


def lid_drift(t):
    """slow droop between blinks, as a fraction of the peak (Olivia: -6 %..+3 % of the lid)."""
    return -0.03 + 0.055 * math.sin(2 * math.pi * t / LENGTH + 2.6)


def blink_lid(t):
    """scale.y of the lid bone."""
    return 1.0 + (LID_PEAK - 1.0) * (lid_shape(t) + lid_drift(t))


def lid_pos(t):
    """position of the lid bone: the lash stroke travels down LID_DROP px at the shut frame."""
    return (0.0, LID_DROP * (lid_shape(t) + lid_drift(t)))


def blink_amount(t):
    """0..1 how far the lash is down (for the brows)."""
    return max(0.0, min(1.0, lid_shape(t)))


def _glance_phase(t):
    """(dx, dy, widen) of the iris for the look-left moment, 0 outside it."""
    s = GLANCE["start"]
    mv = GLANCE["move"]
    T_ret = BLINKS[GLANCE["return_blink"]] + 0.15  # the shut frame of the return blink
    dx, dy, rl = GLANCE["dx"], GLANCE["dy"], GLANCE["relax"]
    sgn = -1.0 if dx < 0 else 1.0
    for tt in _wrap(t):
        if s <= tt < s + mv:
            k = _ease_io((tt - s) / mv)
            return dx * k, dy * k, 0.0
        if s + mv <= tt < T_ret:
            h = tt - (s + mv)
            relax = rl * _ease_io(h / 0.5)                                      # drifts 3 px back toward centre
            wob = 2.5 * math.sin(2 * math.pi * h / 1.2)                         # slow perpendicular wobble
            widen = GLANCE["widen"] * min(1.0, max(0.0, (h - 0.3) / (T_ret - s - mv - 0.3)))
            return dx - sgn * relax, dy + wob, widen
        if T_ret <= tt < T_ret + 0.05:                                          # snap back while shut (3 frames)
            k = (tt - T_ret) / 0.05
            x0 = dx - sgn * rl
            return x0 + (-sgn * 2.5 - x0) * k, dy * (1 - k), GLANCE["widen"] * (1 - k)
        if T_ret + 0.05 <= tt < T_ret + 0.5:                                    # overshoot -> undershoot
            k = _ease_io((tt - T_ret - 0.05) / 0.45)
            b = (tt - T_ret - 0.05)
            bounce = GLANCE["widen"] * 0.65 * math.sin(math.pi * min(1.0, b / 0.1)) if b < 0.1 else GLANCE["widen"] * 0.65 * max(0.0, 1 - (b - 0.1) / 0.5)
            return -sgn * 2.5 + (sgn * 3.5 + sgn * 2.5) * k, 0.0, bounce
        if T_ret + 0.5 <= tt < T_ret + 0.8:                                     # settles
            k = _ease_io((tt - T_ret - 0.5) / 0.3)
            return sgn * 3.5 * (1 - k), 0.0, 0.0
    return 0.0, 0.0, 0.0


def gaze(t):
    """iris position offset: micro drift (always) + the glance."""
    gx, gy, _ = _glance_phase(t)
    return (2.0 * math.sin(2 * math.pi * t / LENGTH + 1.0) + gx, 1.5 * math.sin(W * t + 0.6) + gy)


def iris_scale(t):
    return (1.0 + _glance_phase(t)[2], 1.0)


# bone -> property -> f(t): rotation in degrees, position in px offsets from setup, scale absolute
CURVES = {
    "torso": {
        "position": lambda t: (0.8 * math.sin(S * t + 0.8), -4.0 * math.sin(W * t)),
        "rotation": lambda t: 0.55 * math.sin(S * t + 0.8),
    },
    "skirt": {"rotation": lambda t: 0.30 * math.sin(S * t + 0.5)},
    "apron": {"rotation": lambda t: 0.40 * math.sin(S * t + 1.3) + 0.15 * math.sin(W * t - 0.4)},
    "neck": {"rotation": lambda t: 0.6 * math.sin(S * t + 0.35)},
    "head": {
        "rotation": lambda t: 1.3 * math.sin(S * t + 0.1) + 0.35 * math.sin(W * t - 0.7),
        "position": lambda t: (0.0, -1.5 * math.sin(W * t - 0.3)),
    },
    "ponytail": {"rotation": lambda t: 3.0 * math.sin(S * t - 0.55) + 1.1 * math.sin(W * t - 1.4)},
    "side_hair_l": {"rotation": lambda t: 1.1 * math.sin(S * t - 0.7) + 0.4 * math.sin(W * t - 1.2)},
    "side_hair_r": {"rotation": lambda t: 1.1 * math.sin(S * t - 0.7) + 0.4 * math.sin(W * t - 1.0)},
    "fringe": {"rotation": lambda t: 0.45 * math.sin(S * t - 0.5) + 0.2 * math.sin(W * t - 1.1)},
    "headpiece": {"rotation": lambda t: 0.25 * math.sin(S * t - 0.3)},
    "upper_arm_l": {"rotation": lambda t: 1.2 * math.sin(W * t + 0.4) + 0.5 * math.sin(S * t + 0.8)},
    "forearm_l": {"rotation": lambda t: 1.4 * math.sin(W * t - 0.3)},
    "hand_l": {"rotation": lambda t: 1.8 * math.sin(W * t - 0.9)},
    "upper_arm_r": {"rotation": lambda t: -1.0 * math.sin(W * t + 0.5) + 0.4 * math.sin(S * t + 0.8)},
    "forearm_r": {"rotation": lambda t: -1.2 * math.sin(W * t - 0.2)},
    "hand_r": {"rotation": lambda t: -1.6 * math.sin(W * t - 0.8)},
    "brow_l": {"position": lambda t: (0.0, -0.6 * math.sin(W * t - 0.3) + 2.5 * blink_amount(t))},
    "brow_r": {"position": lambda t: (0.0, -0.6 * math.sin(W * t - 0.3) + 2.5 * blink_amount(t - EYE_R_DELAY))},
    "eye_l": {"scale": lambda t: (1.0, blink_eye(t))},
    "eye_r": {"scale": lambda t: (1.0, blink_eye(t - EYE_R_DELAY))},
    "lid_l": {"scale": lambda t: (1.0, blink_lid(t)), "position": lid_pos},
    "lid_r": {"scale": lambda t: (1.0, blink_lid(t - EYE_R_DELAY)), "position": lambda t: lid_pos(t - EYE_R_DELAY)},
    "heart_fx": {
        "position": lambda t: (1.5 * math.sin(S * t + 2.0), -6.0 * math.sin(W * t + 1.5)),
        "rotation": lambda t: 6.0 * math.sin(S * t + 1.0),
        "scale": lambda t: (1.0 + 0.07 * math.sin(W * t + 1.5),) * 2,
    },
}
IRIS_CURVES = {"iris_screen_left": {"position": gaze, "scale": iris_scale},
               "iris_screen_right": {"position": lambda t: gaze(t - EYE_R_DELAY), "scale": lambda t: iris_scale(t - EYE_R_DELAY)}}

# rig_check pose (handoff doc section 3): head 3 deg, ponytail 8 deg, iris -9,+4 px, elbow_r 17 deg, knees 9 deg
RIG_CHECK = {
    "head": {"rotation": 3.0},
    "ponytail": {"rotation": 8.0},
    "forearm_r": {"rotation": 17.0},
    "shin_l": {"rotation": 9.0},
    "shin_r": {"rotation": -9.0},
}
RIG_CHECK_IRIS = (-9.0, 4.0)


# ---------------------------------------------------------------- helpers
def fmt(v):
    # always a float literal: an int key ("0") makes the AnimationMixer blend the whole track as int
    s = "%.6f" % v
    s = s.rstrip("0")
    if s.endswith("."):
        s += "0"
    return "0.0" if s == "-0.0" else s


def v2(x, y):
    return "Vector2(%s, %s)" % (fmt(x), fmt(y))


def bone_path(name, bones):
    chain = []
    while name:
        chain.append(name)
        name = bones[name]["parent"]
    return "/".join(reversed(chain))


def main():
    with open(os.path.join(SRC, "layout.json"), encoding="utf-8") as fp:
        layout = json.load(fp)
    canvas = layout["canvas"]
    origin = (canvas["width"] / 2.0, float(canvas["height"]))
    sprites = sorted(layout["sprites"], key=lambda s: s["drawOrder"])

    bones = {}
    for name, parent, pivot in BONES:
        bones[name] = {"parent": parent, "pivot": pivot, "children": []}
        if parent:
            bones[parent]["children"].append(name)

    os.makedirs(os.path.join(ROOT, TEX_DIR), exist_ok=True)
    for s in sprites:
        shutil.copyfile(os.path.join(SRC, "images", s["name"] + ".png"),
                        os.path.join(ROOT, TEX_DIR, s["name"] + ".png"))

    ext = []   # (id, path)
    nodes = []  # (name, type, parent, [prop lines])

    def ext_tex(name):
        ext.append(("tex_%s" % name, "res://%s/%s.png" % (TEX_DIR, name)))
        return 'ExtResource("tex_%s")' % name

    # --- bones
    nodes.append(("Skeleton", "Skeleton2D", ".", []))
    for name, parent, pivot in BONES:
        ppiv = bones[parent]["pivot"] if parent else origin
        lx, ly = pivot[0] - ppiv[0], pivot[1] - ppiv[1]
        kids = bones[name]["children"]
        if kids:
            cp = bones[kids[0]]["pivot"]
            dx, dy = cp[0] - pivot[0], cp[1] - pivot[1]
            length = math.hypot(dx, dy)
            angle = math.atan2(dy, dx)
        else:
            length, angle = 60.0, -math.pi / 2
        parent_path = "Skeleton" if not parent else "Skeleton/" + bone_path(parent, bones)
        props = [
            "position = " + v2(lx, ly),
            "rest = Transform2D(1, 0, 0, 1, %s, %s)" % (fmt(lx), fmt(ly)),
            "auto_calculate_length_and_angle = false",
            "length = " + fmt(max(length, 1.0)),
            "bone_angle = " + fmt(angle),
        ]
        nodes.append((name, "Bone2D", parent_path, props))

    # --- parts
    for s in sprites:
        name = s["name"]
        bone = PART_BONE[name]
        bpiv = bones[bone]["pivot"]
        cx, cy = s["x"] + s["width"] / 2.0, s["y"] + s["height"] / 2.0
        parent_path = "Skeleton/" + bone_path(bone, bones)
        z = s["drawOrder"]
        if name in CLIP_OF:
            clip_name, poly_key, _eye_bone = CLIP_OF[name]
            pts = []
            for px, py in layout["clipping"][poly_key]:
                pts += [fmt(px - bpiv[0]), fmt(py - bpiv[1])]
            nodes.append((clip_name, "Polygon2D", parent_path, [
                "z_index = %d" % z,
                "clip_children = 1",
                "polygon = PackedVector2Array(%s)" % ", ".join(pts),
            ]))
            parent_path = parent_path + "/" + clip_name
            z = 0
        props = [
            "position = " + v2(cx - bpiv[0], cy - bpiv[1]),
            "texture = " + ext_tex(name),
        ]
        if z:
            props.append("z_index = %d" % z)
        nodes.append((name, "Sprite2D", parent_path, props))

    # --- animations
    def track(path, prop, times, values, interp=1):
        vals = [v2(*v) if isinstance(v, tuple) else fmt(v) for v in values]
        return (path, prop, times, vals, interp)

    def setup_value(bone, prop):
        if prop == "rotation":
            return 0.0
        if prop == "scale":
            return (1.0, 1.0)
        pv = bones[bone]["pivot"]
        pp = bones[bones[bone]["parent"]]["pivot"] if bones[bone]["parent"] else origin
        return (pv[0] - pp[0], pv[1] - pp[1])

    def iris_setup(name):
        s = next(x for x in sprites if x["name"] == name)
        bpiv = bones[PART_BONE[name]]["pivot"]
        return (s["x"] + s["width"] / 2.0 - bpiv[0], s["y"] + s["height"] / 2.0 - bpiv[1])

    def iris_path(name):
        clip_name, _, eye_bone = CLIP_OF[name]
        return "Skeleton/%s/%s/%s" % (bone_path(eye_bone, bones), clip_name, name)

    def add(a, b):
        if isinstance(a, tuple):
            return (a[0] + b[0], a[1] + b[1])
        return a + b

    def apply(prop, base, v):
        if prop == "rotation":
            return base + v * D2R
        if prop == "scale":
            return v
        return add(base, v)

    anims = {}
    # RESET: every animated property at its setup value
    reset = []
    seen = set()
    for bone, props in list(CURVES.items()) + list(RIG_CHECK.items()):
        for prop in props:
            if (bone, prop) in seen:
                continue
            seen.add((bone, prop))
            reset.append(track("Skeleton/" + bone_path(bone, bones), prop, [0.0], [setup_value(bone, prop)]))
    for name in IRIS_CURVES:
        reset.append(track(iris_path(name), "position", [0.0], [iris_setup(name)]))
        reset.append(track(iris_path(name), "scale", [0.0], [(1.0, 1.0)]))
    anims["RESET"] = (0.001, 0, reset)

    # idle
    n = int(round(LENGTH * FPS))
    times = [i / FPS for i in range(n + 1)]
    idle = []
    for bone, props in CURVES.items():
        for prop, f in props.items():
            base = setup_value(bone, prop)
            idle.append(track("Skeleton/" + bone_path(bone, bones), prop, times, [apply(prop, base, f(t)) for t in times]))
    for name, props in IRIS_CURVES.items():
        base = iris_setup(name)
        idle.append(track(iris_path(name), "position", times, [add(base, props["position"](t)) for t in times]))
        idle.append(track(iris_path(name), "scale", times, [props["scale"](t) for t in times]))
    anims["idle"] = (LENGTH, 1, idle)

    # rig_check: 0.6 s ease into the check pose, hold
    ct = [0.0, 0.6, 1.2]
    check = []
    for bone, props in RIG_CHECK.items():
        for prop, v in props.items():
            base = setup_value(bone, prop)
            posed = apply(prop, base, v)
            check.append(track("Skeleton/" + bone_path(bone, bones), prop, ct, [base, posed, posed]))
    for name in IRIS_CURVES:
        base = iris_setup(name)
        posed = add(base, RIG_CHECK_IRIS)
        check.append(track(iris_path(name), "position", ct, [base, posed, posed]))
    anims["rig_check"] = (1.2, 0, check)

    # --- write tscn
    sub = []
    for aname, (length, loop, tracks) in anims.items():
        s = ['[sub_resource type="Animation" id="anim_%s"]' % aname,
             'resource_name = "%s"' % aname,
             "length = " + fmt(length),
             "loop_mode = %d" % loop,
             "step = " + fmt(1.0 / FPS)]
        for i, (path, prop, tt, vals, interp) in enumerate(tracks):
            s += ['tracks/%d/type = "value"' % i,
                  'tracks/%d/imported = false' % i,
                  'tracks/%d/enabled = true' % i,
                  'tracks/%d/path = NodePath("%s:%s")' % (i, path, prop),
                  'tracks/%d/interp = %d' % (i, interp),
                  'tracks/%d/loop_wrap = true' % i,
                  'tracks/%d/keys = {' % i,
                  '"times": PackedFloat32Array(%s),' % ", ".join(fmt(t) for t in tt),
                  '"transitions": PackedFloat32Array(%s),' % ", ".join("1" for _ in tt),
                  '"update": 0,',
                  '"values": [%s]' % ", ".join(vals),
                  '}']
        sub.append("\n".join(s))
    sub.append('[sub_resource type="AnimationLibrary" id="lib_maid"]\n_data = {\n%s\n}' % ",\n".join(
        '"%s": SubResource("anim_%s")' % (a, a) for a in anims))

    load_steps = len(ext) + len(sub) + 1
    out = ["[gd_scene load_steps=%d format=3]" % load_steps, "",
           "; generated by tools/rig/build_maid_rig.py from spine_parts_maid_v2/layout.json - do not hand-edit", ""]
    for rid, path in ext:
        out.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (path, rid))
    out.append("")
    out += [s + "\n" for s in sub]
    out.append('[node name="MaidRig" type="Node2D"]')
    out.append("")
    for name, ntype, parent, props in nodes:
        out.append('[node name="%s" type="%s" parent="%s"]' % (name, ntype, parent))
        out += props
        out.append("")
    out.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]')
    out.append('libraries = {\n"": SubResource("lib_maid")\n}')
    out.append('autoplay = "idle"')
    out.append("")
    os.makedirs(os.path.dirname(os.path.join(ROOT, OUT_SCENE)), exist_ok=True)
    with open(os.path.join(ROOT, OUT_SCENE), "w", encoding="utf-8", newline="\n") as fp:
        fp.write("\n".join(out))
    print("wrote", OUT_SCENE, "bones", len(BONES), "parts", len(sprites), "idle tracks", len(idle),
          "length %.3fs @ %d fps" % (LENGTH, FPS))


if __name__ == "__main__":
    main()
