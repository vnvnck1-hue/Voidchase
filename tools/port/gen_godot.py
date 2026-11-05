"""
Unity -> Godot scene generator for the KSC Touch_Game_demo / Touch_Game_demo_anim port.

Input : JSON + PNG export produced by tools/port/GodotExport.cs (run inside the Unity project
        in batch mode).  See tools/port/README.md.
Output: res://scenes/*.tscn, res://assets/textures/*.png

Coordinate mapping: 1 Unity unit = 100 px, y flipped, rotation negated (Unity CCW, Godot CW).
"""
import json, math, os, re, shutil, sys

PX = 100.0
HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, '..', '..'))
EXPORT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'unity_export')
TEX_DST_DIR = os.path.join(PROJ, 'assets', 'textures')
SCENE_DIR = os.path.join(PROJ, 'scenes')
SCREEN_W, SCREEN_H = 1920, 1080

NODE_REF_PROPS = {'health_bar', 'target_transform', 'fill_image', 'damage_effect_image', 'effector', 'target'}
# [HideInInspector] fields are not visible to SerializedObject iteration in the exporter; values
# taken from the scene YAML (Touch_Game_demo.unity, AdvancedSpring2D on horn_1 / horn_2).
HIDDEN_SPRING_FIELDS = {
    'battle_scene/Monster/Monster/body/horn_pivot/horn_1': {'savedLocalPivotPos': [0.9116, 1.6878], 'savedLocalRotationZ': 57.759895, 'isInitialized': True},
    'battle_scene/Monster/Monster/body/horn_2_pivot/horn_2': {'savedLocalPivotPos': [-0.9682, 1.161], 'savedLocalRotationZ': 55.598534, 'isInitialized': True},
}
KOREAN_MAP = {'레이어': 'layer', '그룹': 'group', '타원': 'ellipse', '복사': 'copy', '배경': 'background'}


def fnum(v):
    """Format a float for tscn."""
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    if v is None:
        return '0.0'
    if math.isnan(v):
        return '0.0'
    if math.isinf(v):
        return '1e30' if v > 0 else '-1e30'
    s = repr(float(v))
    if 'e' in s or 'E' in s:
        s = '%.10g' % v
        if '.' not in s and 'e' not in s:
            s += '.0'
    return s


def vec2(x, y):
    return 'Vector2(%s, %s)' % (fnum(x), fnum(y))


def col(c):
    return 'Color(%s, %s, %s, %s)' % tuple(fnum(x) for x in c)


def gstr(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def gd_literal(v):
    """Python value -> GDScript/tscn literal (for Dictionary configs)."""
    if v is None:
        return 'null'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return fnum(v)
    if isinstance(v, str):
        return gstr(v)
    if isinstance(v, list):
        return '[' + ', '.join(gd_literal(x) for x in v) + ']'
    if isinstance(v, dict):
        return '{' + ', '.join('%s: %s' % (gstr(str(k)), gd_literal(x)) for k, x in v.items()) + '}'
    return gstr(str(v))


def safe_node_name(name):
    name = re.sub(r'[./:@"%]', '_', name)
    return name.strip() or 'Node'


def safe_file_name(name):
    base = os.path.splitext(name)[0]
    for k, v in KOREAN_MAP.items():
        base = base.replace(k, v)
    base = re.sub(r'[^A-Za-z0-9_\-]', '_', base)
    return base


def unity_z_angle(q):
    x, y, z, w = q
    return math.degrees(2.0 * math.atan2(z, w))


def q_to_godot_rot(q):
    """Unity local rotation quaternion -> Godot rotation (radians, CW positive)."""
    return -math.radians(unity_z_angle(q))


def inv_mat(m):
    # column-major 4x4 (unity m[row + col*4]) -> 2D affine (a,b,c,d,tx,ty) with rows [[a,c,tx],[b,d,ty]]
    a, b = m[0], m[1]       # column 0
    c, d = m[4], m[5]       # column 1
    tx, ty = m[12], m[13]   # column 3
    return (a, b, c, d, tx, ty)


def aff_inv(t):
    a, b, c, d, tx, ty = t
    det = a * d - b * c
    ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
    itx = -(ia * tx + ic * ty)
    ity = -(ib * tx + id_ * ty)
    return (ia, ib, ic, id_, itx, ity)


def aff_mul(p, q):
    """p * q (apply q first then p). Affines as (a,b,c,d,tx,ty) with x' = a*x + c*y + tx, y' = b*x + d*y + ty."""
    a1, b1, c1, d1, tx1, ty1 = p
    a2, b2, c2, d2, tx2, ty2 = q
    return (a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
            a1 * tx2 + c1 * ty2 + tx1, b1 * tx2 + d1 * ty2 + ty1)


def aff_from_trs(pos, rot_rad, scale):
    cs, sn = math.cos(rot_rad), math.sin(rot_rad)
    return (cs * scale[0], sn * scale[0], -sn * scale[1], cs * scale[1], pos[0], pos[1])


def aff_decompose(t):
    a, b, c, d, tx, ty = t
    rot = math.atan2(b, a)
    sx = math.hypot(a, b)
    sy = (a * d - b * c) / sx if sx else 0.0
    return (tx, ty), rot, (sx, sy)


class Tscn:
    def __init__(self):
        self.ext = []        # (type, path, id)
        self.ext_ids = {}
        self.sub = []        # (type, id, props dict / text)
        self.nodes = []      # (name, type, parent, props(list of (k, v text)), instance)
        self.counter = 0

    def ext_res(self, rtype, path):
        key = (rtype, path)
        if key in self.ext_ids:
            return self.ext_ids[key]
        self.counter += 1
        rid = '%s_%d' % (rtype.replace('2D', ''), self.counter)
        self.ext.append((rtype, path, rid))
        self.ext_ids[key] = 'ExtResource("%s")' % rid
        return self.ext_ids[key]

    def sub_res(self, rtype, props, name_hint=None):
        self.counter += 1
        rid = '%s_%d' % (name_hint or rtype, self.counter)
        self.sub.append((rtype, rid, props))
        return 'SubResource("%s")' % rid

    def node(self, name, ntype, parent, props=None, groups=None):
        self.nodes.append((name, ntype, parent, props or []))

    def text(self):
        out = ['[gd_scene load_steps=%d format=3]' % (len(self.ext) + len(self.sub) + 1), '']
        for rtype, path, rid in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, path, rid))
        out.append('')
        for rtype, rid, props in self.sub:
            out.append('[sub_resource type="%s" id="%s"]' % (rtype, rid))
            if isinstance(props, str):
                out.append(props)
            else:
                for k, v in props:
                    out.append('%s = %s' % (k, v))
            out.append('')
        root_name = self.nodes[0][0] if self.nodes else ''
        for name, ntype, parent, props in self.nodes:
            if parent is None:
                out.append('[node name=%s type="%s"]' % (gstr(name), ntype))
            else:
                rel = '.' if parent == root_name else (parent[len(root_name) + 1:] if parent.startswith(root_name + '/') else parent)
                node_ref_props = [k for k, v in props if k in NODE_REF_PROPS and str(v).startswith('NodePath(')]
                extra = ''
                if node_ref_props:
                    extra = ' node_paths=PackedStringArray(%s)' % ', '.join(gstr(k) for k in node_ref_props)
                out.append('[node name=%s type="%s" parent=%s%s]' % (gstr(name), ntype, gstr(rel), extra))
            for k, v in props:
                out.append('%s = %s' % (k, v))
            out.append('')
        return '\n'.join(out)


# ----------------------------------------------------------------------------------------------
class Generator:
    def __init__(self, export_dir):
        self.export_dir = export_dir
        self.materials = {m['instanceID']: m for m in json.load(open(os.path.join(export_dir, 'materials.json'), encoding='utf-8'))}
        self.materials_by_name = {m['name']: m for m in self.materials.values()}
        self.textures = {t['file']: t for t in json.load(open(os.path.join(export_dir, 'textures.json'), encoding='utf-8'))}
        self.tex_res_path = {}
        os.makedirs(TEX_DST_DIR, exist_ok=True)
        os.makedirs(SCENE_DIR, exist_ok=True)
        self.copy_textures()

    # ---------------- textures
    def copy_textures(self):
        used = set()
        for t in self.textures.values():
            base = safe_file_name(t['file'])
            name = base
            k = 1
            while name in used:
                k += 1
                name = '%s_%d' % (base, k)
            used.add(name)
            src = os.path.join(self.export_dir, 'textures', t['file'])
            dst = os.path.join(TEX_DST_DIR, name + '.png')
            if os.path.exists(src):
                shutil.copyfile(src, dst)
            self.tex_res_path[t['file']] = 'res://assets/textures/%s.png' % name

    def tex_path(self, texref):
        if not texref:
            return None
        return self.tex_res_path.get(texref['file'])

    # ---------------- helpers
    @staticmethod
    def comps(go, tname):
        return [c for c in go['components'] if c['type'].endswith(tname)]

    @staticmethod
    def comp(go, tname):
        cs = Generator.comps(go, tname)
        return cs[0] if cs else None

    def transform_props(self, go, bone_rest=None):
        p = go['localPosition']
        s = go['localScale']
        props = []
        pos = (p[0] * PX, -p[1] * PX)
        rot = q_to_godot_rot(go['localRotation'])
        if abs(pos[0]) > 1e-9 or abs(pos[1]) > 1e-9:
            props.append(('position', vec2(*pos)))
        if abs(rot) > 1e-9:
            props.append(('rotation', fnum(rot)))
        if abs(s[0] - 1) > 1e-9 or abs(s[1] - 1) > 1e-9:
            props.append(('scale', vec2(s[0], s[1])))
        return props

    # ---------------- animation
    def build_animation_player(self, tscn, animator_go, godot_parent_path, scene, path_map):
        """Create an AnimationPlayer child under the animator node."""
        clips = [sc for sc in scene['sampledClips'] if sc['root'] == animator_go['path']]
        if not clips:
            return
        anim_info = next((a for a in scene['animators'] if a['animatorPath'] == animator_go['path']), None)
        default_clip = None
        if anim_info:
            for st in anim_info['states']:
                if st['isDefault']:
                    default_clip = st['clipName']
        lib_entries = []
        for sc in clips:
            anim_text = self.animation_resource(sc, animator_go, path_map)
            res = tscn.sub_res('Animation', anim_text, 'Animation')
            lib_entries.append('%s: %s' % (gstr(sc['clipName']), res))
        lib = tscn.sub_res('AnimationLibrary', [('_data', '{\n' + ',\n'.join(lib_entries) + '\n}')], 'AnimationLibrary')
        props = [('libraries', '{\n"": %s\n}' % lib)]
        if default_clip:
            props.append(('autoplay', gstr(default_clip)))
        tscn.node('AnimationPlayer', 'AnimationPlayer', godot_parent_path, props)

    def find_go(self, scene, path):
        def walk(n):
            if n['path'] == path:
                return n
            for c in n['children']:
                r = walk(c)
                if r:
                    return r
        for r in scene['roots']:
            r2 = walk(r)
            if r2:
                return r2
        return None

    def animation_resource(self, sc, animator_go, path_map):
        """Return tscn text for an Animation sub-resource from sampled Unity data."""
        length = sc['length']
        times = sc['sampleTimes']
        bindings = sc['bindings']
        samples = sc['samples']
        # group bindings
        groups = {}
        for i, b in enumerate(bindings):
            prop = b['property']
            if prop.startswith('m_LocalPosition.'):
                g, comp = 'position', prop[-1]
            elif prop.startswith('localEulerAnglesRaw.'):
                g, comp = 'rotation', prop[-1]
            elif prop.startswith('m_LocalScale.'):
                g, comp = 'scale', prop[-1]
            elif prop.startswith('m_Color.'):
                g, comp = 'color', prop[-1]
            elif prop == 'm_IsActive':
                g, comp = 'active', 'v'
            else:
                print('  ! unsupported binding', b['type'], prop)
                continue
            groups.setdefault((b['path'], g), {})[comp] = i
        lines = []
        lines.append('resource_name = %s' % gstr(sc['clipName']))
        lines.append('length = %s' % fnum(length))
        lines.append('loop_mode = %d' % (1 if sc['isLooping'] else 0))
        lines.append('step = %s' % fnum(1.0 / 60.0))
        ti = 0
        root_unity = animator_go['path']
        for (upath, g), comps in groups.items():
            target_unity = root_unity if upath == '' else root_unity + '/' + upath
            target_go = self.scene_go_by_path.get(target_unity)
            if target_go is None or target_unity not in path_map:
                print('  ! animation target not found:', target_unity)
                continue
            # relative godot path from animator node
            rel = self.rel_path(path_map[root_unity], path_map[target_unity])
            if g == 'position':
                prop = 'position'
                base = target_go['localPosition']
                def val(row):
                    x = row[comps['x']] if 'x' in comps and row[comps['x']] is not None else base[0]
                    y = row[comps['y']] if 'y' in comps and row[comps['y']] is not None else base[1]
                    return vec2(x * PX, -y * PX)
            elif g == 'scale':
                prop = 'scale'
                base = target_go['localScale']
                def val(row):
                    x = row[comps['x']] if 'x' in comps and row[comps['x']] is not None else base[0]
                    y = row[comps['y']] if 'y' in comps and row[comps['y']] is not None else base[1]
                    return vec2(x, y)
            elif g == 'rotation':
                prop = 'rotation'
                if 'z' not in comps:
                    continue
                def val(row):
                    z = row[comps['z']]
                    return fnum(-math.radians(z))
            elif g == 'color':
                prop = 'modulate'
                sr = self.comp(target_go, 'SpriteRenderer')
                base = sr['color'] if sr else [1, 1, 1, 1]
                def val(row):
                    c = [row[comps[k]] if k in comps and row[comps[k]] is not None else base[j] for j, k in enumerate('rgba')]
                    return col(c)
            elif g == 'active':
                prop = 'visible'
                def val(row):
                    return 'true' if row[comps['v']] and row[comps['v']] > 0.5 else 'false'
            else:
                continue
            discrete = g == 'active'
            vals = [val(r) for r in samples]
            # compress constant runs for discrete tracks
            if discrete:
                tk, vk = [], []
                for t, v in zip(times, vals):
                    if not vk or vk[-1] != v:
                        tk.append(t)
                        vk.append(v)
                times_used, vals_used = tk, vk
            else:
                # drop frames where the value is identical to both neighbours (keeps linear result)
                times_used, vals_used = [], []
                n = len(vals)
                for k in range(n):
                    if 0 < k < n - 1 and vals[k] == vals[k - 1] and vals[k] == vals[k + 1]:
                        continue
                    times_used.append(times[k])
                    vals_used.append(vals[k])
            lines.append('tracks/%d/type = "value"' % ti)
            lines.append('tracks/%d/imported = false' % ti)
            lines.append('tracks/%d/enabled = true' % ti)
            lines.append('tracks/%d/path = NodePath(%s)' % (ti, gstr(rel + ':' + prop)))
            lines.append('tracks/%d/interp = %d' % (ti, 0 if discrete else 1))
            lines.append('tracks/%d/loop_wrap = true' % ti)
            lines.append('tracks/%d/keys = {' % ti)
            lines.append('"times": PackedFloat32Array(%s),' % ', '.join(fnum(t) for t in times_used))
            lines.append('"transitions": PackedFloat32Array(%s),' % ', '.join('1' for _ in times_used))
            lines.append('"update": %d,' % (1 if discrete else 0))
            lines.append('"values": [%s]' % ', '.join(vals_used))
            lines.append('}')
            ti += 1
        return '\n'.join(lines)

    @staticmethod
    def rel_path(from_path, to_path):
        """Godot-style relative node path between two absolute scene paths ('Root/A/B')."""
        f = from_path.split('/')
        t = to_path.split('/')
        i = 0
        while i < len(f) and i < len(t) and f[i] == t[i]:
            i += 1
        ups = ['..'] * (len(f) - i)
        rest = t[i:]
        parts = ups + rest
        return '/'.join(parts) if parts else '.'

    # ---------------- particle config
    def particle_config(self, ps, psr, go):
        keys = ['main', 'emission', 'shape', 'velocityOverLifetime', 'limitVelocityOverLifetime', 'forceOverLifetime',
                'colorOverLifetime', 'sizeOverLifetime', 'rotationOverLifetime', 'noise', 'textureSheetAnimation', 'trails']
        cfg = {}
        for k in keys:
            cfg[k] = self.strip(ps.get(k, {}))
        cfg['main']['_activeInHierarchy'] = go['activeInHierarchy']
        mats = psr.get('materials') or []
        mat0 = self.materials.get(mats[0]['instanceID']) if mats and mats[0] else None
        trail_mat = None
        if psr.get('trailMaterial'):
            trail_mat = self.materials.get(psr['trailMaterial']['instanceID'])
        elif len(mats) > 1 and mats[1]:
            trail_mat = self.materials.get(mats[1]['instanceID'])
        rend = {
            'renderMode': psr.get('renderMode', 'Billboard'),
            'lengthScale': psr.get('lengthScale', 2.0),
            'velocityScale': psr.get('velocityScale', 0.0),
            'pivot': psr.get('pivot', [0, 0, 0]),
            'blend': self.blend_of(mat0),
            'trailBlend': self.blend_of(trail_mat) if trail_mat else self.blend_of(mat0),
        }
        tex = self.mat_texture(mat0)
        if tex:
            rend['texture'] = tex
        ttex = self.mat_texture(trail_mat) if trail_mat else None
        if ttex:
            rend['trailTexture'] = ttex
        cfg['renderer'] = rend
        return cfg

    def strip(self, v):
        """Remove sampled arrays / huge garbage values to keep configs small & tscn-safe."""
        if isinstance(v, dict):
            out = {}
            for k, x in v.items():
                if k in ('sampled0to1',):
                    continue
                out[k] = self.strip(x)
            return out
        if isinstance(v, list):
            return [self.strip(x) for x in v]
        if isinstance(v, float):
            if math.isnan(v):
                return 0.0
            if math.isinf(v):
                return 1e30 if v > 0 else -1e30
            if abs(v) > 1e25:
                return 1e30 if v > 0 else -1e30
        return v

    @staticmethod
    def blend_of(mat):
        if not mat:
            return 'mix'
        sh = mat.get('shader') or ''
        if 'Additive' in sh:
            return 'add'
        if 'Standard Unlit' in sh:
            mode = mat['props'].get('_Mode', 2)
            if mode == 4:
                return 'add'
            if mode == 3:
                return 'premul'
        return 'mix'

    def mat_texture(self, mat):
        if not mat:
            return None
        t = mat['props'].get('_MainTex')
        if not t:
            return None
        return self.tex_path(t)

    # ---------------- scene conversion
    def convert_scene(self, scene_json, out_name, root_name):
        scene = json.load(open(os.path.join(self.export_dir, scene_json), encoding='utf-8'))
        self.scene = scene
        self.scene_go_by_path = {}
        def index(n):
            self.scene_go_by_path[n['path']] = n
            for c in n['children']:
                index(c)
        for r in scene['roots']:
            index(r)
        tscn = Tscn()
        self.tscn = tscn
        self.path_map = {}      # unity path -> godot absolute path (root name included)
        self.pending_anim = []  # (animator_go, godot_path)
        self.skin_sprites = []  # list of (go, godot_path, sprite_renderer_comp)
        self.bone_paths = set()
        self.bone_rest_global = {}  # unity bone path -> affine in skeleton (avatar) space, godot px
        tscn.node(root_name, 'Node2D', None)
        # camera & roots
        for r in scene['roots']:
            self.convert_go(r, root_name, root_name)
        # animation players (after all nodes exist)
        for animator_go, gpath in self.pending_anim:
            self.build_animation_player(tscn, animator_go, gpath, scene, self.path_map)
        text = tscn.text()
        out_path = os.path.join(SCENE_DIR, out_name)
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(text)
        print('wrote', out_path, '(%d nodes)' % len(tscn.nodes))

    def unique_child_name(self, parent_path, name):
        used = self.used_names.setdefault(parent_path, set())
        base = safe_node_name(name)
        n = base
        k = 1
        while n in used:
            k += 1
            n = '%s_%d' % (base, k)
        used.add(n)
        return n

    def convert_go(self, go, godot_parent, root_name):
        if not hasattr(self, 'used_names'):
            self.used_names = {}
        name = go['name']
        # --- special roots
        if self.comp(go, 'UnityEngine.Canvas'):
            self.convert_canvas(go, godot_parent)
            return
        if self.comp(go, 'UnityEngine.Camera'):
            nname = self.unique_child_name(godot_parent, name)
            cam = self.comp(go, 'UnityEngine.Camera')
            zoom = (SCREEN_H / 2.0) / (cam['orthographicSize'] * PX)
            props = [('position', vec2(go['localPosition'][0] * PX, -go['localPosition'][1] * PX)), ('zoom', vec2(zoom, zoom))]
            self.tscn.node(nname, 'Camera2D', godot_parent, props)
            self.path_map[go['path']] = godot_parent + '/' + nname
            return
        if self.comp(go, 'UnityEngine.EventSystem') or self.comp(go, 'EventSystem'):
            return  # input handled by scripts
        if self.comp(go, 'UnityEngine.MeshRenderer'):
            self.convert_cube(go, godot_parent)
            return

        nname = self.unique_child_name(godot_parent, name)
        gpath = godot_parent + '/' + nname
        self.path_map[go['path']] = gpath
        props = []
        ntype = 'Node2D'
        sr = self.comp(go, 'UnityEngine.SpriteRenderer')
        ps = self.comp(go, 'UnityEngine.ParticleSystem')
        psr = self.comp(go, 'UnityEngine.ParticleSystemRenderer')
        skin = self.comp(go, 'SpriteSkin')
        is_bone = go['path'] in self.bone_paths or self.is_bone_candidate(go)
        children_parent = gpath

        if is_bone:
            ntype = 'Bone2D'
        if ps:
            ntype = 'Node2D'
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/unity_particles_2d.gd')))
            cfg = self.particle_config(ps, psr or {}, go)
            props.append(('config', gd_literal(cfg)))
            if cfg['renderer'].get('texture'):
                props.append(('texture', self.tscn.ext_res('Texture2D', cfg['renderer']['texture'])))
            if cfg['renderer'].get('trailTexture'):
                props.append(('trail_texture', self.tscn.ext_res('Texture2D', cfg['renderer']['trailTexture'])))
            props.append(('renderer_enabled', 'true' if (psr and psr.get('enabled', True)) else 'false'))
            if psr:
                props.append(('z_index', str(psr.get('sortingOrder', 0))))
                props.append(('z_as_relative', 'false'))
        elif sr and skin:
            ntype = 'Polygon2D'
            self.skin_sprites.append((go, gpath, sr))
        elif sr:
            if sr.get('drawMode') == 'Sliced':
                # world-space 9-slice -> NinePatchRect
                self.convert_nine_patch_world(go, godot_parent, nname, sr)
                return
            ntype = 'Sprite2D'
            props += self.sprite_props(sr)

        # scripts on the node itself
        mb = self.comp(go, 'MonsterBehavior')
        spring = self.comp(go, 'AdvancedSpring2D')
        limb = self.comp(go, 'LimbSolver2D')
        ikm = self.comp(go, 'IKManager2D')
        if mb:
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/monster_behavior.gd')))
            props += self.monster_props(mb, gpath)
        elif spring:
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/advanced_spring_2d.gd')))
            props += self.spring_props(spring, gpath, go['path'])
        elif limb:
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/limb_solver_2d.gd')))
            self.pending_limbs = getattr(self, 'pending_limbs', [])
            self.pending_limbs.append((limb, gpath, len(self.tscn.nodes)))
        elif ikm:
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/ik_manager_2d.gd')))
            self.pending_ikm = (ikm, gpath, len(self.tscn.nodes))

        props = self.transform_props(go) + props
        if not go['active']:
            props.append(('visible', 'false'))
            props.append(('process_mode', '4'))
        node_index = len(self.tscn.nodes)
        self.tscn.node(nname, ntype, godot_parent, props)

        # child helper components
        box = self.comp(go, 'UnityEngine.BoxCollider2D')
        if box:
            area = self.unique_child_name(gpath, 'BoxCollider2D')
            self.tscn.node(area, 'Area2D', gpath, [])
            shape = self.tscn.sub_res('RectangleShape2D', [('size', vec2(box['size'][0] * PX, box['size'][1] * PX))])
            self.tscn.node('CollisionShape2D', 'CollisionShape2D', gpath + '/' + area,
                           [('position', vec2(box['offset'][0] * PX, -box['offset'][1] * PX)), ('shape', shape)])
        scl = self.comp(go, 'SpriteColorLerp')
        if scl:
            p = scl['props']
            cprops = [('script', self.tscn.ext_res('Script', 'res://scripts/sprite_color_lerp.gd')),
                      ('target_color', col(p.get('targetColor', [1, 0, 0, 1]))),
                      ('lerp_value', fnum(p.get('lerpValue', 0.0))),
                      ('always_update', 'true' if p.get('alwaysUpdate') else 'false'),
                      ('update_threshold', fnum(p.get('updateThreshold', 0.001)))]
            self.tscn.node('SpriteColorLerp', 'Node', gpath, cprops)
            # shader material on the sprite itself so it is in place before _ready
            mat = self.tscn.sub_res('ShaderMaterial', [('shader', self.tscn.ext_res('Shader', 'res://shaders/sprite_color_lerp.gdshader')),
                                                      ('shader_parameter/target_color', col(p.get('targetColor', [1, 0, 0, 1]))),
                                                      ('shader_parameter/lerp_value', fnum(p.get('lerpValue', 0.0)))])
            self.tscn.nodes[node_index][3].append(('material', mat))

        # Skeleton2D wrapper for the character root bone chain
        if self.comp(go, 'IKManager2D'):
            # children: sprites + Spine_1 bone root. Insert Skeleton2D for bones.
            skel_name = self.unique_child_name(gpath, 'Skeleton')
            self.skeleton_path = gpath + '/' + skel_name
            self.tscn.node(skel_name, 'Skeleton2D', gpath, [])
            self.collect_bone_paths(go)
            self.compute_bone_rests(go)
            # IK manager / animator
            self.pending_anim_root = gpath
        anim = self.comp(go, 'UnityEngine.Animator')
        if anim:
            self.pending_anim.append((go, gpath))

        for ch in go['children']:
            parent_for_child = gpath
            if ch['path'] in self.bone_paths and getattr(self, 'skeleton_path', None) and self.comp(go, 'IKManager2D'):
                parent_for_child = self.skeleton_path
            self.convert_go(ch, parent_for_child, root_name)

        # after children: finalize skinned sprites & IK for the avatar root
        if self.comp(go, 'IKManager2D'):
            self.finalize_skins()
            self.finalize_ik(ikm, gpath)
        if is_bone:
            self.apply_bone_rest(go, node_index)

    # ---------------- sprites
    def sprite_props(self, sr):
        props = []
        sp = sr.get('sprite')
        if sp:
            tpath = self.tex_path(sp['texture'])
            tex = self.textures.get(sp['texture']['file'])
            props.append(('texture', self.tscn.ext_res('Texture2D', tpath)))
            props.append(('centered', 'false'))
            r = sp['rect']
            th = tex['height'] if tex else sp['texture']['height']
            tw = tex['width'] if tex else sp['texture']['width']
            pivot = sp['pivot']
            props.append(('offset', vec2(-pivot[0], -(r['h'] - pivot[1]))))
            if r['w'] != tw or r['h'] != th or r['x'] != 0 or r['y'] != 0:
                props.append(('region_enabled', 'true'))
                props.append(('region_rect', 'Rect2(%s, %s, %s, %s)' % (fnum(r['x']), fnum(th - r['y'] - r['h']), fnum(r['w']), fnum(r['h']))))
        c = sr.get('color', [1, 1, 1, 1])
        if c != [1, 1, 1, 1]:
            props.append(('modulate', col(c)))
        if sr.get('flipX'):
            props.append(('flip_h', 'true'))
        if sr.get('flipY'):
            props.append(('flip_v', 'true'))
        props.append(('z_index', str(sr.get('sortingOrder', 0))))
        props.append(('z_as_relative', 'false'))
        return props

    def convert_nine_patch_world(self, go, godot_parent, nname, sr):
        sp = sr['sprite']
        size = sr['size']
        w, h = size[0] * PX, size[1] * PX
        pos = go['localPosition']
        b = sp['border']  # left, bottom, right, top
        props = [('position', vec2(pos[0] * PX - w / 2, -pos[1] * PX - h / 2)), ('size', vec2(w, h)),
                 ('texture', self.tscn.ext_res('Texture2D', self.tex_path(sp['texture']))),
                 ('patch_margin_left', str(int(b[0]))), ('patch_margin_bottom', str(int(b[1]))),
                 ('patch_margin_right', str(int(b[2]))), ('patch_margin_top', str(int(b[3]))),
                 ('z_index', str(sr.get('sortingOrder', 0))), ('z_as_relative', 'false')]
        rot = q_to_godot_rot(go['localRotation'])
        if abs(rot) > 1e-9:
            props.append(('rotation', fnum(rot)))
        c = sr.get('color', [1, 1, 1, 1])
        if c != [1, 1, 1, 1]:
            props.append(('modulate', col(c)))
        if not go['active']:
            props.append(('visible', 'false'))
        self.tscn.node(nname, 'NinePatchRect', godot_parent, props)
        self.path_map[go['path']] = godot_parent + '/' + nname

    # ---------------- scripts
    def monster_props(self, mb, gpath):
        p = mb['props']
        props = []
        hb = p.get('healthBar')
        if hb:
            self.pending_monster_hb = (gpath, hb['path'])
        props.append(('damage_per_hit', fnum(p.get('damagePerHit', 10))))
        systems, delays, repeats = [], [], []
        for s in p.get('hitEffectSettings', []):
            if s.get('system'):
                systems.append(s['system']['path'])
                delays.append(s.get('delay', 0.0))
                repeats.append(int(s.get('repeatCount', 1)))
        self.pending_monster_systems = (gpath, systems)
        props.append(('hit_effect_delays', 'Array[float]([%s])' % ', '.join(fnum(d) for d in delays)))
        props.append(('hit_effect_repeat_counts', 'Array[int]([%s])' % ', '.join(str(r) for r in repeats)))
        props.append(('hit_color', col(p.get('hitColor', [1, 0, 0, 1]))))
        props.append(('flash_intensity', fnum(p.get('flashIntensity', 1.0))))
        props.append(('flash_duration', fnum(p.get('flashDuration', 0.1))))
        props.append(('scale_multiplier', fnum(p.get('scaleMultiplier', 1.2))))
        props.append(('punch_duration', fnum(p.get('punchDuration', 0.15))))
        props.append(('use_hit_stop', 'true' if p.get('useHitStop', True) else 'false'))
        props.append(('hit_stop_duration', fnum(p.get('hitStopDuration', 0.05))))
        props.append(('hit_stop_time_scale', fnum(p.get('hitStopTimeScale', 0.0))))
        props.append(('use_camera_shake', 'true' if p.get('useCameraShake', True) else 'false'))
        props.append(('shake_magnitude', fnum(p.get('shakeMagnitude', 0.1))))
        props.append(('shake_duration', fnum(p.get('shakeDuration', 0.1))))
        return props

    def spring_props(self, sp, gpath, unity_path=None):
        p = dict(sp['props'])
        if unity_path in HIDDEN_SPRING_FIELDS:
            p.update(HIDDEN_SPRING_FIELDS[unity_path])
        props = []
        preset = p.get('preset', {}).get('value', 0) if isinstance(p.get('preset'), dict) else p.get('preset', 0)
        props.append(('preset', str(int(preset))))
        for uk, gk in [('maxDistance', 'max_distance'), ('maxRotation', 'max_rotation'), ('elasticity', 'elasticity'), ('softness', 'softness'),
                       ('reactionForce', 'reaction_force'), ('windStrength', 'wind_strength'), ('windSpeed', 'wind_speed'), ('rotationBias', 'rotation_bias'),
                       ('teleportThreshold', 'teleport_threshold'), ('savedLocalRotationZ', 'saved_local_rotation_z')]:
            if uk in p:
                props.append((gk, fnum(p[uk])))
        for uk, gk in [('invertRotation', 'invert_rotation'), ('usePosition', 'use_position'), ('useRotation', 'use_rotation'), ('lockX', 'lock_x'), ('lockY', 'lock_y'), ('isInitialized', 'is_initialized')]:
            if uk in p:
                props.append((gk, 'true' if p[uk] else 'false'))
        if 'physicsPivotOffset' in p:
            v = p['physicsPivotOffset']
            props.append(('physics_pivot_offset', vec2(v[0], v[1])))
        if 'savedLocalPivotPos' in p:
            v = p['savedLocalPivotPos']
            props.append(('saved_local_pivot_pos', vec2(v[0], v[1])))
        if p.get('targetTransform'):
            self.pending_springs = getattr(self, 'pending_springs', [])
            self.pending_springs.append((gpath, p['targetTransform']['path'], len(self.tscn.nodes)))
        return props

    # ---------------- bones / skins
    def is_bone_candidate(self, go):
        return False

    def collect_bone_paths(self, avatar_go):
        """All Unity GO paths under the avatar that are bones (referenced by a SpriteSkin or ancestors of one)."""
        refs = set()
        for ch in avatar_go['children']:
            for c in ch['components']:
                if c['type'].endswith('SpriteRenderer') and 'skinMesh' in c:
                    for bp in c['skinMesh']['boneTransforms']:
                        refs.add(bp)
        # ancestors up to (excluding) the avatar
        for bp in list(refs):
            parts = bp.split('/')
            for i in range(len(parts), 0, -1):
                anc = '/'.join(parts[:i])
                if anc == avatar_go['path']:
                    break
                self.bone_paths.add(anc)
        # also every descendant of the root bone that has bone children (eyes_2 etc.) is covered above.

    def compute_bone_rests(self, avatar_go):
        """Rest pose (in skeleton/avatar space, Godot px) for each bone from the sprite bind poses."""
        for ch in avatar_go['children']:
            sr = self.comp(ch, 'UnityEngine.SpriteRenderer')
            if not sr or 'skinMesh' not in sr:
                continue
            sm = sr['skinMesh']
            # sprite transform relative to avatar (Unity units)
            spos = ch['localPosition']
            srot = math.radians(unity_z_angle(ch['localRotation']))
            sscl = ch['localScale']
            t_sprite = aff_from_trs((spos[0], spos[1]), srot, (sscl[0], sscl[1]))
            for bpath, bp in zip(sm['boneTransforms'], sm['bindPoses']):
                if bpath in self.bone_rest_global:
                    continue
                inv_bind = aff_inv(inv_mat(bp))      # bone in sprite space (Unity units)
                bone_in_avatar = aff_mul(t_sprite, inv_bind)
                self.bone_rest_global[bpath] = bone_in_avatar

    def apply_bone_rest(self, go, node_index):
        """Set Bone2D.rest (local to parent bone) from the computed rest pose."""
        g = self.bone_rest_global.get(go['path'])
        parent_path = go['path'].rsplit('/', 1)[0]
        pg = self.bone_rest_global.get(parent_path)
        if g is None:
            # fall back: current local transform
            pos = go['localPosition']
            rot = math.radians(unity_z_angle(go['localRotation']))
            local = aff_from_trs((pos[0], pos[1]), rot, (go['localScale'][0], go['localScale'][1]))
        else:
            if pg is None:
                # parent is the avatar root (identity in avatar space) -> local = global
                local = g
            else:
                local = aff_mul(aff_inv(pg), g)
        (tx, ty), rot, (sx, sy) = aff_decompose(local)
        # Unity (y-up, CCW) -> Godot (y-down, CW): flip y of translation, negate rotation
        gx, gy = tx * PX, -ty * PX
        grot = -rot
        cs, sn = math.cos(grot), math.sin(grot)
        rest = 'Transform2D(%s, %s, %s, %s, %s, %s)' % (fnum(cs * sx), fnum(sn * sx), fnum(-sn * sy), fnum(cs * sy), fnum(gx), fnum(gy))
        self.tscn.nodes[node_index][3].append(('rest', rest))
        self.tscn.nodes[node_index][3].append(('auto_calculate_length_and_angle', 'false'))

    def finalize_skins(self):
        for go, gpath, sr in self.skin_sprites:
            sm = sr['skinMesh']
            sp = sr['sprite']
            tex = self.textures[sp['texture']['file']]
            tw, th = tex['width'], tex['height']
            verts = ['Vector2(%s, %s)' % (fnum(v[0] * PX), fnum(-v[1] * PX)) for v in sm['vertices']]
            uvs = ['Vector2(%s, %s)' % (fnum(u[0] * tw), fnum((1.0 - u[1]) * th)) for u in sm['uv']]
            idx = sm['indices']
            tris = []
            for i in range(0, len(idx) - 2, 3):
                tris.append('PackedInt32Array(%d, %d, %d)' % (idx[i], idx[i + 1], idx[i + 2]))
            # find node to append props
            node_index = next(i for i, n in enumerate(self.tscn.nodes) if ((n[2] + '/' + n[0]) if n[2] else n[0]) == gpath)
            props = self.tscn.nodes[node_index][3]
            props.append(('texture', self.tscn.ext_res('Texture2D', self.tex_path(sp['texture']))))
            props.append(('polygon', 'PackedVector2Array(%s)' % ', '.join(v[8:-1] for v in verts)))
            props.append(('uv', 'PackedVector2Array(%s)' % ', '.join(u[8:-1] for u in uvs)))
            props.append(('polygons', '[%s]' % ', '.join(tris)))
            c = sr.get('color', [1, 1, 1, 1])
            if c != [1, 1, 1, 1]:
                props.append(('color', col(c)))
            props.append(('z_index', str(sr.get('sortingOrder', 0))))
            props.append(('z_as_relative', 'false'))
            # skeleton + bones
            props.append(('skeleton', 'NodePath(%s)' % gstr(self.rel_path(gpath, self.skeleton_path))))
            bones_entries = []
            nverts = len(sm['vertices'])
            bw = sm.get('boneWeights') or []
            for bi, bpath in enumerate(sm['boneTransforms']):
                weights = [0.0] * nverts
                for vi, w in enumerate(bw):
                    for k in range(4):
                        if w['i%d' % k] == bi and w['w%d' % k] > 0:
                            weights[vi] += w['w%d' % k]
                gbone = self.path_map.get(bpath)
                if gbone is None:
                    print('  ! bone path missing', bpath)
                    continue
                rel = self.rel_path(self.skeleton_path, gbone)
                bones_entries.append('NodePath(%s), PackedFloat32Array(%s)' % (gstr(rel), ', '.join(fnum(x) for x in weights)))
            props.append(('bones', '[%s]' % ', '.join(bones_entries)))

    def finalize_ik(self, ikm, avatar_gpath):
        # LimbSolver2D nodes
        for limb, gpath, node_index in getattr(self, 'pending_limbs', []):
            p = limb['props']
            chain = p['m_Chain']
            props = self.tscn.nodes[node_index][3]
            props.append(('constrain_rotation', 'true' if p.get('m_ConstrainRotation', True) else 'false'))
            props.append(('solve_from_default_pose', 'true' if p.get('m_SolveFromDefaultPose', True) else 'false'))
            props.append(('weight', fnum(p.get('m_Weight', 1.0))))
            props.append(('flip', 'true' if p.get('m_Flip') else 'false'))
            eff = self.path_map.get(chain['m_EffectorTransform']['path'])
            tgt = self.path_map.get(chain['m_TargetTransform']['path'])
            props.append(('effector', 'NodePath(%s)' % gstr(self.rel_path(gpath, eff))))
            props.append(('target', 'NodePath(%s)' % gstr(self.rel_path(gpath, tgt))))
            tr = [self.rel_path(gpath, self.path_map[t['path']]) for t in chain['m_Transforms']]
            props.append(('chain_transforms', 'Array[NodePath]([%s])' % ', '.join('NodePath(%s)' % gstr(t) for t in tr)))
            rots = [fnum(-math.radians(unity_z_angle([q[0], q[1], q[2], q[3]]))) for q in chain['m_DefaultLocalRotations']]
            props.append(('default_local_rotations', 'Array[float]([%s])' % ', '.join(rots)))
        self.pending_limbs = []
        if ikm:
            p = ikm['props']
            node_index, props = next((i, n[3]) for i, n in enumerate(self.tscn.nodes) if ((n[2] + '/' + n[0]) if n[2] else n[0]) == avatar_gpath)
            solvers = []
            for s in p.get('m_Solvers', []):
                gp = self.path_map.get(s['path'])
                if gp:
                    solvers.append('NodePath(%s)' % gstr(self.rel_path(avatar_gpath, gp)))
            props.append(('weight', fnum(p.get('m_Weight', 1.0))))
            props.append(('solvers', 'Array[NodePath]([%s])' % ', '.join(solvers)))

    # ---------------- canvas / UI
    def convert_canvas(self, canvas_go, godot_parent):
        layer = self.unique_child_name(godot_parent, 'CanvasLayer')
        lpath = godot_parent + '/' + layer
        self.tscn.node(layer, 'CanvasLayer', godot_parent, [('layer', '1')])
        cname = self.unique_child_name(lpath, canvas_go['name'])
        cpath = lpath + '/' + cname
        self.path_map[canvas_go['path']] = cpath
        self.tscn.node(cname, 'Control', lpath, [('anchors_preset', '15'), ('anchor_right', '1.0'), ('anchor_bottom', '1.0'),
                                                 ('offset_right', '0.0'), ('offset_bottom', '0.0'), ('mouse_filter', '2')])
        for ch in canvas_go['children']:
            self.convert_ui_go(ch, cpath, (SCREEN_W, SCREEN_H))

    def rect_props(self, go, parent_size):
        W, H = parent_size
        amin, amax = go['anchorMin'], go['anchorMax']
        apos, sdelta, pivot = go['anchoredPosition'], go['sizeDelta'], go['pivot']
        width = (amax[0] - amin[0]) * W + sdelta[0]
        height = (amax[1] - amin[1]) * H + sdelta[1]
        xmin, xmax = amin[0] * W, amax[0] * W
        ymin, ymax = amin[1] * H, amax[1] * H
        pivot_x = xmin + (xmax - xmin) * pivot[0] + apos[0]
        pivot_y_up = ymin + (ymax - ymin) * pivot[1] + apos[1]
        left = pivot_x - pivot[0] * width
        bottom = pivot_y_up - pivot[1] * height
        top = H - (bottom + height)
        a_l, a_r = amin[0], amax[0]
        a_t, a_b = 1 - amax[1], 1 - amin[1]
        props = [('anchor_left', fnum(a_l)), ('anchor_top', fnum(a_t)), ('anchor_right', fnum(a_r)), ('anchor_bottom', fnum(a_b)),
                 ('offset_left', fnum(left - a_l * W)), ('offset_top', fnum(top - a_t * H)),
                 ('offset_right', fnum(left + width - a_r * W)), ('offset_bottom', fnum(top + height - a_b * H)),
                 ('pivot_offset', vec2(pivot[0] * width, (1 - pivot[1]) * height))]
        s = go['localScale']
        if abs(s[0] - 1) > 1e-9 or abs(s[1] - 1) > 1e-9:
            props.append(('scale', vec2(s[0], s[1])))
        rot = q_to_godot_rot(go['localRotation'])
        if abs(rot) > 1e-9:
            props.append(('rotation', fnum(rot)))
        return props, (width, height)

    def convert_ui_go(self, go, godot_parent, parent_size):
        nname = self.unique_child_name(godot_parent, go['name'])
        gpath = godot_parent + '/' + nname
        self.path_map[go['path']] = gpath
        props, size = self.rect_props(go, parent_size)
        props.append(('mouse_filter', '2'))
        img = self.comp(go, 'UnityEngine.UI.Image')
        hb = self.comp(go, 'HealthBar')
        ntype = 'Control'
        if img and img.get('sprite'):
            sp = img['sprite']
            tex = self.tscn.ext_res('Texture2D', self.tex_path(sp['texture']))
            if img['imageType'] == 'Sliced':
                ntype = 'NinePatchRect'
                b = sp['border']
                props += [('texture', tex), ('patch_margin_left', str(int(b[0]))), ('patch_margin_bottom', str(int(b[1]))),
                          ('patch_margin_right', str(int(b[2]))), ('patch_margin_top', str(int(b[3])))]
                c = img.get('color', [1, 1, 1, 1])
                if c != [1, 1, 1, 1]:
                    props.append(('modulate', col(c)))
            elif img['imageType'] == 'Filled':
                ntype = 'TextureProgressBar'
                fill_modes = {'Horizontal': 0, 'Vertical': 2, 'Radial90': 4, 'Radial180': 5, 'Radial360': 6}
                props += [('texture_progress', tex), ('nine_patch_stretch', 'true'), ('fill_mode', str(fill_modes.get(img['fillMethod'], 0))),
                          ('min_value', '0.0'), ('max_value', '1.0'), ('step', '0.0'), ('value', fnum(img.get('fillAmount', 1.0))),
                          ('tint_progress', col(img.get('color', [1, 1, 1, 1])))]
            else:
                ntype = 'TextureRect'
                props += [('texture', tex), ('expand_mode', '1'), ('stretch_mode', '0')]
                c = img.get('color', [1, 1, 1, 1])
                if c != [1, 1, 1, 1]:
                    props.append(('modulate', col(c)))
        if hb:
            props.append(('script', self.tscn.ext_res('Script', 'res://scripts/health_bar.gd')))
            p = hb['props']
            self.pending_healthbar = (gpath, p)
            props.append(('max_health', fnum(p.get('maxHealth', 100))))
            props.append(('current_health', fnum(p.get('currentHealth', 100))))
            props.append(('fill_color', col(p.get('fillColor', [0, 1, 0, 1]))))
            props.append(('effect_delay', fnum(p.get('effectDelay', 0.5))))
            props.append(('effect_speed', fnum(p.get('effectSpeed', 1.0))))
            props.append(('gradient_speed', fnum(p.get('gradientSpeed', 5.0))))
            props.append(('regen_delay', fnum(p.get('regenDelay', 5.0))))
            props.append(('regen_speed', fnum(p.get('regenSpeed', 50.0))))
            g = p.get('damageGradient')
            if g:
                offsets = ', '.join(fnum(k['t']) for k in g['colorKeys'])
                colors = ', '.join(fnum(x) for k in g['colorKeys'] for x in k['c'])
                grad = self.tscn.sub_res('Gradient', [('offsets', 'PackedFloat32Array(%s)' % offsets), ('colors', 'PackedColorArray(%s)' % colors)])
                props.append(('damage_gradient', grad))
        if not go['active']:
            props.append(('visible', 'false'))
        node_index = len(self.tscn.nodes)
        self.tscn.node(nname, ntype, godot_parent, props)
        for ch in go['children']:
            self.convert_ui_go(ch, gpath, size)
        if hb:
            p = hb['props']
            fp = self.path_map.get(p['fillImage']['path']) if p.get('fillImage') else None
            dp = self.path_map.get(p['damageEffectImage']['path']) if p.get('damageEffectImage') else None
            if fp:
                self.tscn.nodes[node_index][3].append(('fill_image', 'NodePath(%s)' % gstr(self.rel_path(gpath, fp))))
            if dp:
                self.tscn.nodes[node_index][3].append(('damage_effect_image', 'NodePath(%s)' % gstr(self.rel_path(gpath, dp))))

    # ---------------- cube (3D in 2D via SubViewport)
    def convert_cube(self, go, godot_parent):
        nname = self.unique_child_name(godot_parent, go['name'])
        gpath = godot_parent + '/' + nname
        self.path_map[go['path']] = gpath
        pos = go['localPosition']
        props = [('position', vec2(pos[0] * PX, -pos[1] * PX)), ('z_index', '1000'), ('z_as_relative', 'false')]
        if not go['active']:
            props.append(('visible', 'false'))
        self.tscn.node(nname, 'Node2D', godot_parent, props)
        vp_size = 400
        self.tscn.node('SubViewport', 'SubViewport', gpath, [('own_world_3d', 'true'), ('transparent_bg', 'true'),
                                                              ('size', 'Vector2i(%d, %d)' % (vp_size, vp_size)), ('render_target_update_mode', '4')])
        vp = gpath + '/SubViewport'
        env = self.tscn.sub_res('Environment', [('background_mode', '0'), ('ambient_light_source', '2'),
                                                ('ambient_light_color', 'Color(0.55, 0.58, 0.66, 1)'), ('ambient_light_energy', '1.0')])
        self.tscn.node('WorldEnvironment', 'WorldEnvironment', vp, [('environment', env)])
        self.tscn.node('Camera3D', 'Camera3D', vp, [('transform', 'Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 10)'),
                                                    ('projection', '1'), ('size', fnum(vp_size / PX)), ('near', '0.1'), ('far', '100.0')])
        self.tscn.node('DirectionalLight3D', 'DirectionalLight3D', vp, [('transform', 'Transform3D(0.866, -0.25, 0.433, 0, 0.866, 0.5, -0.5, -0.433, 0.75, 0, 0, 0)'),
                                                                        ('light_color', 'Color(1, 0.98, 0.95, 1)'), ('light_energy', '0.6')])
        mesh = self.tscn.sub_res('BoxMesh', [('size', 'Vector3(1, 1, 1)')])
        mat = self.tscn.sub_res('StandardMaterial3D', [('albedo_color', 'Color(0.8, 0.8, 0.8, 1)'), ('roughness', '0.5')])
        rot = self.comp(go, 'CubeRotator')
        cprops = [('mesh', mesh), ('surface_material_override/0', mat)]
        if rot:
            p = rot['props']
            cprops.append(('script', self.tscn.ext_res('Script', 'res://scripts/cube_rotator.gd')))
            cprops.append(('rotation_speed_x', fnum(p.get('rotationSpeedX', 0))))
            cprops.append(('rotation_speed_y', fnum(p.get('rotationSpeedY', 90))))
            cprops.append(('rotation_speed_z', fnum(p.get('rotationSpeedZ', 0))))
        self.tscn.node('CubeMesh', 'MeshInstance3D', vp, cprops)
        vt = self.tscn.sub_res('ViewportTexture', [('viewport_path', 'NodePath(%s)' % gstr(self.rel_path(self.tscn.nodes[0][0], vp)))])
        self.tscn.node('View', 'Sprite2D', gpath, [('texture', vt)])

    # ---------------- post-pass: resolve cross references
    def resolve_pending(self):
        t = self.tscn
        def node_index_of(gpath):
            return next(i for i, n in enumerate(t.nodes) if ((n[2] + '/' + n[0]) if n[2] else n[0]) == gpath)
        if getattr(self, 'pending_monster_hb', None):
            gpath, hbpath = self.pending_monster_hb
            target = self.path_map.get(hbpath)
            if target:
                t.nodes[node_index_of(gpath)][3].append(('health_bar', 'NodePath(%s)' % gstr(self.rel_path(gpath, target))))
            self.pending_monster_hb = None
        if getattr(self, 'pending_monster_systems', None):
            gpath, systems = self.pending_monster_systems
            paths = [self.path_map.get(s) for s in systems]
            paths = [p for p in paths if p]
            t.nodes[node_index_of(gpath)][3].append(('hit_effect_systems', 'Array[NodePath]([%s])' % ', '.join('NodePath(%s)' % gstr(self.rel_path(gpath, p)) for p in paths)))
            self.pending_monster_systems = None
        for gpath, tpath, node_index in getattr(self, 'pending_springs', []):
            target = self.path_map.get(tpath)
            if target:
                t.nodes[node_index][3].append(('target_transform', 'NodePath(%s)' % gstr(self.rel_path(gpath, target))))
        self.pending_springs = []


def main():
    gen = Generator(EXPORT)
    gen.convert_scene_wrapper = None
    for scene_json, out_name, root in [('Touch_Game_demo.json', 'Touch_Game_demo.tscn', 'Touch_Game_demo'),
                                       ('Touch_Game_demo_anim.json', 'Touch_Game_demo_anim.tscn', 'Touch_Game_demo_anim')]:
        gen.convert_scene_with_resolve(scene_json, out_name, root)


def convert_scene_with_resolve(self, scene_json, out_name, root_name):
    scene = json.load(open(os.path.join(self.export_dir, scene_json), encoding='utf-8'))
    self.scene = scene
    self.scene_go_by_path = {}
    def index(n):
        self.scene_go_by_path[n['path']] = n
        for c in n['children']:
            index(c)
    for r in scene['roots']:
        index(r)
    tscn = Tscn()
    self.tscn = tscn
    self.path_map = {}
    self.pending_anim = []
    self.skin_sprites = []
    self.bone_paths = set()
    self.bone_rest_global = {}
    self.used_names = {}
    self.skeleton_path = None
    tscn.node(root_name, 'Node2D', None)
    for r in scene['roots']:
        self.convert_go(r, root_name, root_name)
    self.resolve_pending()
    for animator_go, gpath in self.pending_anim:
        self.build_animation_player(tscn, animator_go, gpath, scene, self.path_map)
    text = tscn.text()
    out_path = os.path.join(SCENE_DIR, out_name)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print('wrote', out_path, '(%d nodes)' % len(tscn.nodes))


Generator.convert_scene_with_resolve = convert_scene_with_resolve

if __name__ == '__main__':
    main()
