## 원화 조립 씬(VoidDefenseVisualTest.tscn)의 영웅 리그·몬스터·배경 프랍 스프라이트를 그레이박스 유닛용으로 꺼내 쓴다.
## 씬을 인스턴스하지 않고 PackedScene 의 SceneState 만 읽어, 파츠 텍스처·위치·offset·z_index 를 복사한다.
## 좌표 원본은 조립 씬 하나(tools/void_defense_original/build_visual_test.py 생성물)뿐이라 여기엔 수치를 두지 않는다.
class_name VDRig
extends RefCounted

const SOURCE := "res://scenes/void_defense/VoidDefenseVisualTest.tscn"
## 원화 캔버스의 타일(약 192x96)을 그레이박스 타일(128x64)에 맞추는 배율.
const HERO_SCALE := 0.66
## 영웅 머리를 조립 씬 위치보다 몸통 쪽(아래)으로 내리는 양(원화 px). 조립 씬 그대로면 목이 살짝 떠 보인다 (2026-11-06).
const HEAD_DROP := 5.0
## 적 타입 → 조립 씬의 몬스터 스프라이트와 배율·틴트. 몬스터 원화는 왼쪽(아군 쪽)을 바라본다.
const ENEMY_ART := {
	"normal": {"sprite": "voidling_front", "scale": 0.6, "tint": Color(1, 1, 1)},
	"boss":   {"sprite": "void_lord", "scale": 0.42, "tint": Color(1, 1, 1)},
}
## 독립 스프라이트의 전장 표시 너비와 발밑에서 띄우는 높이(px).
## foot: 원본 이미지에서 발이 땅에 닿는 중심의 y(px, 없으면 이미지 맨 아래). 다리가 여럿인 원화는 맨 아래 발끝이 아니라 발들의 가운데가 셀 중심에 와야 뜨지 않는다.
const SPECIALIST_ART := {
	"fast": {"texture": preload("res://assets/void_defense_enemies/void_shard.png"), "width": 104.0, "lift": 0.0},
	"skirmisher": {"texture": preload("res://assets/void_defense_enemies/void_spore.png"), "width": 90.0, "lift": 12.0},
	"tank": {"texture": preload("res://assets/void_defense_enemies/void_bulwark.png"), "width": 138.0, "lift": 0.0},
	"longneck": {"texture": preload("res://assets/void_defense_enemies/void_longneck.png"), "width": 200.0, "lift": 0.0, "foot": 605.0},
	## 보스 공허 감시자 (tools/vfx/extract_parry_fx.py 가 컨셉 PSD '보스몹' 그룹에서 뽑는다). 떠 있다.
	"watcher": {"texture": preload("res://assets/void_defense_enemies/void_watcher.png"), "width": 360.0, "lift": 40.0},
}
## 파츠 몬스터: 머리·몸통·팔이 따로인 적. 배치는 생성물(data), 움직임은 VDPartsAnim.
## width: 전장 표시 너비(px). 파츠 PNG 는 dir 아래 <파츠 이름>.png (tools/enemies/build_crystal_crab.py).
const PARTS_ART := {
	"crab": {"data": preload("res://scripts/void_defense/vd_crystal_crab_parts.gd"), "dir": "res://assets/void_defense_enemies/crystal_crab/", "width": 160.0},
	## 본 메시 파츠(kind = "mesh")가 섞인 몬스터: 후드·촉수는 Skeleton2D 본으로 휜다. anim = 움직임 스크립트.
	"wraith": {"data": preload("res://scripts/void_defense/vd_void_wraith_parts.gd"), "dir": "res://assets/void_defense_enemies/void_wraith/", "width": 262.0, "anim": preload("res://scripts/void_defense/vd_wraith_anim.gd")},
	## 첫 보스 공허 응시자: 몸통·날개는 본 메시, 눈 14개는 kind = "eye" (눈알 + 동공 + 덮개 세 장, 동공이 눈알 안에서 굴러다닌다).
	"gazer": {"data": preload("res://scripts/void_defense/vd_void_gazer_parts.gd"), "dir": "res://assets/void_defense_enemies/void_gazer/", "width": 618.0, "anim": preload("res://scripts/void_defense/vd_gazer_anim.gd")},
}
## 기믹 무리 적: 전용 원화가 올 때까지 기존 적의 비주얼을 배율·틴트만 바꿔 쓴다 (as 의 비주얼 × scale, 파츠에 tint 곱).
## 전용 원화 요청은 docs/stage_wave_port/CODEX_REQUESTS.md. 원화가 오면 SPECIALIST_ART 에 넣고 여기서 빼면 된다.
const ENEMY_ALIAS := {
	"swarm":    {"as": "normal", "scale": 0.62, "tint": Color(0.85, 0.8, 1.0)},
	"splitter": {"as": "normal", "scale": 1.28, "tint": Color(0.75, 0.6, 0.95)},
	"splitling": {"as": "normal", "scale": 0.5, "tint": Color(0.9, 0.75, 1.0)},
	"assassin": {"as": "fast", "scale": 1.0, "tint": Color(0.55, 0.3, 0.65)},
	"sprinter": {"as": "fast", "scale": 1.12, "tint": Color(1.0, 0.75, 0.9)},
	"hydra":    {"as": "skirmisher", "scale": 1.15, "tint": Color(0.9, 0.55, 1.0)},
	"illusionist": {"as": "normal", "scale": 1.1, "tint": Color(1.0, 0.6, 1.0)},
	"illusion": {"as": "normal", "scale": 1.1, "tint": Color(0.8, 0.7, 1.0)},
}

## 노드 경로(Canvas 아래, "Heroes/mage/body" 등) → {"type", "props"}
static var _nodes := {}


static func _load() -> void:
	if not _nodes.is_empty():
		return
	var st := (load(SOURCE) as PackedScene).get_state()
	for i in st.get_node_count():
		var path := str(st.get_node_path(i)).trim_prefix("./").trim_prefix("Canvas/")
		if not (path.begins_with("Heroes/") or path.begins_with("Monsters/") or path.begins_with("Background/")):
			continue
		var props := {}
		for k in st.get_node_property_count(i):
			props[st.get_node_property_name(i, k)] = st.get_node_property_value(i, k)
		_nodes[path] = {"type": st.get_node_type(i), "props": props}


static func _sprite(props: Dictionary, with_position := true) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = props.get("texture")
	sp.centered = props.get("centered", true)
	sp.offset = props.get("offset", Vector2.ZERO)
	sp.z_index = props.get("z_index", 0)
	if with_position:
		sp.position = props.get("position", Vector2.ZERO)
	return sp


## 영웅 또는 적 타입 id의 비주얼.
## 루트 원점이 발밑이고, 기본 방향은 영웅=오른쪽, 몬스터=왼쪽. 없으면 null.
static func build(id: String, team: int) -> Node2D:
	if team == 1 and ENEMY_ALIAS.has(id):
		var al: Dictionary = ENEMY_ALIAS[id]
		var base := build(String(al["as"]), team)
		if base:
			base.scale *= float(al["scale"])
			for c in base.get_children():
				if c is Sprite2D:
					c.self_modulate *= al["tint"]
		return base
	_load()
	var root := Node2D.new()
	root.name = "Visual"
	if team == 0:
		var prefix := "Heroes/%s/" % id
		var parts: Array[Sprite2D] = []
		for path in _nodes:
			# 리그 루트의 직계 Sprite2D 파츠만 (중첩 노드는 위치 기준이 달라 제외)
			if str(path).begins_with(prefix) and not str(path).trim_prefix(prefix).contains("/") and _nodes[path]["type"] == &"Sprite2D":
				var sp := _sprite(_nodes[path]["props"])
				sp.name = str(path).trim_prefix(prefix)
				if sp.name == "head":
					sp.position.y += HEAD_DROP
				parts.append(sp)
		# 파츠 z_index 를 그대로 두면 다른 유닛과의 y 정렬을 뚫고 올라오므로 자식 순서로 바꾼다
		parts.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.z_index < b.z_index)
		for sp in parts:
			sp.z_index = 0
			root.add_child(sp)
		root.scale = Vector2.ONE * HERO_SCALE
	elif PARTS_ART.has(id):
		var art: Dictionary = PARTS_ART[id]
		var skel := _build_skeleton(art["data"].PARTS)
		if skel:
			root.add_child(skel)
		for part in art["data"].PARTS:
			var tex: Texture2D = load(String(art["dir"]) + String(part["name"]) + ".png")
			if part.get("kind", "sprite") == "mesh":
				root.add_child(_build_mesh(part, tex, skel))
				continue
			var sp := Sprite2D.new()
			sp.name = part["name"]
			sp.texture = tex
			sp.centered = false
			sp.position = part["pos"]
			sp.offset = part["offset"]
			root.add_child(sp)
			if part.get("kind", "sprite") == "eye":
				_build_eye(sp, part, String(art["dir"]))
		root.scale = Vector2.ONE * (float(art["width"]) / float(art["data"].WIDTH))
		root.set_meta("parts", true)
		root.set_meta("parts_anim", art.get("anim", VDPartsAnim))
		root.set_meta("top", float(art["data"].TOP))
	elif SPECIALIST_ART.has(id):
		var art: Dictionary = SPECIALIST_ART[id]
		var sp := Sprite2D.new()
		sp.name = "body"
		sp.texture = art["texture"]
		sp.centered = false
		var size := sp.texture.get_size()
		var zoom: float = art["width"] / size.x
		sp.offset = Vector2(-size.x * 0.5, -float(art.get("foot", size.y)) - art["lift"] / zoom)
		root.add_child(sp)
		root.scale = Vector2.ONE * zoom
	else:
		var art: Dictionary = ENEMY_ART.get(id, {})
		# 몬스터는 "Monsters/<이름>" Sprite2D 이거나, Node2D 앵커 아래 "Monsters/<이름>/sprite" 이다
		var path := "Monsters/%s" % art.get("sprite", "")
		if _nodes.has(path + "/sprite"):
			path += "/sprite"
		if not _nodes.has(path) or _nodes[path]["type"] != &"Sprite2D":
			root.free()
			return null
		var sp := _sprite(_nodes[path]["props"], false)
		sp.name = "body"
		sp.self_modulate = art["tint"]
		root.add_child(sp)
		root.scale = Vector2.ONE * float(art["scale"])
	if root.get_child_count() == 0:
		root.free()
		return null
	return root


## 비주얼의 위쪽 끝 y (루트 로컬, 배율 적용 후). 이름·HP 바 위치용.
static func top_of(visual: Node2D) -> float:
	if visual.has_meta("top"):
		return float(visual.get_meta("top")) * visual.scale.y
	var top := 0.0
	for c in visual.get_children():
		var sp := c as Sprite2D
		if sp and sp.texture:
			top = minf(top, sp.position.y + sp.offset.y)
	return top * visual.scale.y


## 파츠 몬스터의 본: 메시 파츠들의 bones([이름, 부모 본 이름, x, y] — 좌표는 비주얼 기준)를 모아 Skeleton2D 하나로 만든다.
## 메시 파츠가 없으면 null. 본의 rest 는 만든 자세 그대로(회전 0)라서 본을 돌리면 그 점을 축으로 아래 본이 전부 따라 돈다.
static func _build_skeleton(parts: Array) -> Skeleton2D:
	var defs := {}
	for part in parts:
		for b in part.get("bones", []):
			defs[String(b[0])] = b
	if defs.is_empty():
		return null
	var skel := Skeleton2D.new()
	skel.name = "Skeleton"
	var made := {}
	while made.size() < defs.size():
		var before := made.size()
		for bname in defs:
			var b: Array = defs[bname]
			var parent := String(b[1])
			if made.has(bname) or (parent != "" and not made.has(parent)):
				continue
			var bone := Bone2D.new()
			bone.name = bname
			var at := Vector2(b[2], b[3])
			if parent == "":
				bone.position = at
				skel.add_child(bone)
			else:
				bone.position = at - Vector2(defs[parent][2], defs[parent][3])
				(made[parent] as Bone2D).add_child(bone)
			bone.rest = Transform2D(0.0, bone.position)
			bone.set_autocalculate_length_and_angle(false)
			bone.set_length(24.0)
			made[bname] = bone
		if made.size() == before:
			push_error("VDRig: 본 부모를 찾을 수 없다")
			break
	return skel


## 눈 파츠: 눈알(sp) 알파로 자식을 자른다 → 동공(pupil)이 눈알 밖으로 나가지 않는다. 그 위에 외곽선·하이라이트 덮개(over).
## 자식도 비주얼 재질(피격 흰 섬광)을 타도록 use_parent_material 을 미리 켠다 (VDUnit._set_white 는 직계 자식만 켠다).
static func _build_eye(sp: Sprite2D, part: Dictionary, dir: String) -> void:
	sp.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pupil := Sprite2D.new()
	pupil.name = "pupil"
	pupil.texture = load(dir + String(part["name"]) + "_pupil.png")
	pupil.centered = false
	pupil.position = part["pupil"]
	pupil.offset = part["pupil_offset"]
	pupil.use_parent_material = true
	sp.add_child(pupil)
	var over := Sprite2D.new()
	over.name = "over"
	over.texture = load(dir + String(part["name"]) + "_over.png")
	over.centered = false
	over.offset = part["over_offset"]
	over.use_parent_material = true
	sp.add_child(over)


## 메시 파츠 하나: 본 가중치가 실린 Polygon2D (skel 의 본을 돌리면 텍스처가 휘어진다).
static func _build_mesh(part: Dictionary, tex: Texture2D, skel: Skeleton2D) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = part["name"]
	poly.texture = tex
	poly.polygon = _vec2s(part["verts"])
	poly.uv = _vec2s(part["uvs"])
	var tris: Array = part["tris"]
	var polys := []
	for i in range(0, tris.size(), 3):
		polys.append(PackedInt32Array([tris[i], tris[i + 1], tris[i + 2]]))
	poly.polygons = polys
	poly.skeleton = NodePath("../Skeleton")
	var bones: Array = part["bones"]
	for i in bones.size():
		# 본 경로는 Skeleton2D 기준 (아직 트리 밖이라 부모 이름을 직접 이어 붙인다)
		var path := String(bones[i][0])
		var parent := String(bones[i][1])
		while parent != "":
			path = parent + "/" + path
			parent = String((skel.find_child(parent, true, false) as Node).get_parent().name)
			if parent == "Skeleton":
				break
		poly.add_bone(NodePath(path), PackedFloat32Array(part["weights"][i]))
	return poly


static func _vec2s(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(flat.size() / 2)
	for i in out.size():
		out[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
	return out


## 배경 프랍(아치·기둥·바위·파편·깃발): 조립 씬 Background 중 피벗 앵커(offset)가 있는 스프라이트.
## [{name, texture, offset}] — 원경·발판·가장자리 매트는 offset 이 없어 빠진다.
static func props() -> Array:
	_load()
	var out := []
	for path in _nodes:
		var p := str(path)
		if not p.begins_with("Background/") or p.trim_prefix("Background/").contains("/"):
			continue
		var props: Dictionary = _nodes[path]["props"]
		if _nodes[path]["type"] != &"Sprite2D" or props.get("offset", Vector2.ZERO) == Vector2.ZERO or props.get("texture") == null:
			continue
		out.append({"name": p.trim_prefix("Background/"), "texture": props["texture"], "offset": props["offset"]})
	return out
