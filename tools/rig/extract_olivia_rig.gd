extends SceneTree
## 올리비아 본 리그(BG_all/avatar)를 캐릭터 선택 씬에서 떼어 단독 씬 scenes/characters/olivia_rig.tscn 으로 저장한다.
## 그 씬 안에만 있던 리그를 VOID DEFENSE 턴테이블 등에서 maid_rig.tscn 처럼 인스턴스해 쓰기 위함. 손으로 고치지 말고 다시 실행:
##   Godot --headless --path . -s res://tools/rig/extract_olivia_rig.gd
## 바꾸는 것: 루트를 원점·배율 1·보이게·처리 켜기(선택 씬은 숨겨 두고 패널 선택 때 켠다), 발밑 Shadow 제거(쓰는 쪽이 그림자를 그린다),
## 파츠의 절대 z(z_as_relative=false, 1~18)를 상대 z 로 — 그래야 턴테이블의 깊이별 z 구간 안에서 정렬된다.

const SRC := "res://scenes/Touch_Game_demo_anim.tscn"
const OUT := "res://scenes/characters/olivia_rig.tscn"


func _init() -> void:
	var inst: Node = (load(SRC) as PackedScene).instantiate()
	var avatar: Node2D = inst.get_node("BG_all/avatar")
	avatar.get_parent().remove_child(avatar)
	inst.free()
	avatar.name = "OliviaRig"
	avatar.visible = true
	avatar.process_mode = Node.PROCESS_MODE_INHERIT
	avatar.position = Vector2.ZERO
	avatar.scale = Vector2.ONE
	var shadow := avatar.get_node_or_null("Shadow")
	if shadow:
		avatar.remove_child(shadow)
		shadow.free()
	var parts := 0
	for n in avatar.find_children("*", "", true, false):
		n.owner = avatar
		if n is CanvasItem and not (n as CanvasItem).z_as_relative:
			(n as CanvasItem).z_as_relative = true
			parts += 1
	var ps := PackedScene.new()
	var err := ps.pack(avatar)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("[extract_olivia_rig] %s -> %s (%d parts to relative z) err=%d" % [SRC, OUT, parts, err])
	avatar.free()
	quit(1 if err != OK else 0)
