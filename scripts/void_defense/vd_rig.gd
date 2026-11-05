## 원화 조립 씬(VoidDefenseVisualTest.tscn)의 영웅 리그·몬스터·배경 프랍 스프라이트를 그레이박스 유닛용으로 꺼내 쓴다.
## 씬을 인스턴스하지 않고 PackedScene 의 SceneState 만 읽어, 파츠 텍스처·위치·offset·z_index 를 복사한다.
## 좌표 원본은 조립 씬 하나(tools/void_defense_original/build_visual_test.py 생성물)뿐이라 여기엔 수치를 두지 않는다.
class_name VDRig
extends RefCounted

const SOURCE := "res://scenes/void_defense/VoidDefenseVisualTest.tscn"
## 원화 캔버스의 타일(약 192x96)을 그레이박스 타일(128x64)에 맞추는 배율.
const HERO_SCALE := 0.66
## 적 타입 → 조립 씬의 몬스터 스프라이트와 배율·틴트. 몬스터 원화는 왼쪽(아군 쪽)을 바라본다.
const ENEMY_ART := {
	"normal": {"sprite": "voidling_front", "scale": 0.6, "tint": Color(1, 1, 1)},
	"boss":   {"sprite": "void_lord", "scale": 0.42, "tint": Color(1, 1, 1)},
}
## 독립 스프라이트의 전장 표시 너비와 발밑에서 띄우는 높이(px).
const SPECIALIST_ART := {
	"fast": {"texture": preload("res://assets/void_defense_enemies/void_shard.png"), "width": 104.0, "lift": 0.0},
	"skirmisher": {"texture": preload("res://assets/void_defense_enemies/void_spore.png"), "width": 90.0, "lift": 12.0},
	"tank": {"texture": preload("res://assets/void_defense_enemies/void_bulwark.png"), "width": 138.0, "lift": 0.0},
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
				parts.append(sp)
		# 파츠 z_index 를 그대로 두면 다른 유닛과의 y 정렬을 뚫고 올라오므로 자식 순서로 바꾼다
		parts.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.z_index < b.z_index)
		for sp in parts:
			sp.z_index = 0
			root.add_child(sp)
		root.scale = Vector2.ONE * HERO_SCALE
	elif SPECIALIST_ART.has(id):
		var art: Dictionary = SPECIALIST_ART[id]
		var sp := Sprite2D.new()
		sp.name = "body"
		sp.texture = art["texture"]
		sp.centered = false
		var size := sp.texture.get_size()
		var zoom: float = art["width"] / size.x
		sp.offset = Vector2(-size.x * 0.5, -size.y - art["lift"] / zoom)
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
	var top := 0.0
	for c in visual.get_children():
		var sp := c as Sprite2D
		if sp and sp.texture:
			top = minf(top, sp.position.y + sp.offset.y)
	return top * visual.scale.y


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
