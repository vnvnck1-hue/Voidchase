## 기사 검기(VDSwordSlash)와 바닥 마법진 회전을 프레임별로 캡처한다. docs/void_defense_slash/ 에 저장.
## 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDSlashCapture.tscn
extends Node2D

const OUT := "res://docs/void_defense_slash/"

var _vfx: VDVfx


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RenderingServer.set_default_clear_color(Color(0.18, 0.14, 0.24))
	_vfx = VDVfx.new()
	add_child(_vfx)
	await get_tree().process_frame
	# 왼쪽: 오른쪽을 향한 검기 / 가운데: 왼쪽을 향한 검기 / 오른쪽: 아이소 바닥 마법진
	_vfx.loop("magic_circle", self, Vector2(1020, 420), 30.0, 0.32, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 1.5)
	var vp := get_viewport()
	for i in 24:
		if i % 8 == 0:
			VDSwordSlash.spawn(self, Vector2(250, 360), 200.0, 0.0, false)
			VDSwordSlash.spawn(self, Vector2(620, 360), 200.0, PI, true)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(OUT + "f_%02d.png" % i)
		for k in 2:
			await get_tree().process_frame
	# 실제 전투: 적이 나온 뒤 기사가 몇 번 베는 동안 전체 화면을 b_XX.png 로 남긴다
	for c in get_children():
		c.queue_free()
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	b.start_battle()
	while b.state != VDBattle.State.BATTLE:
		await get_tree().process_frame
	# 검기가 떠 있는 프레임만 저장한다 (최대 16장)
	var saved := 0
	# 첫 웨이브엔 기사가 근접하기 전에 끝나기도 하므로 기사 → 첫 적 공격 연출을 직접 몇 번 부른다
	var knight: VDUnit = null
	for h in b.allies:
		if h.id == "knight":
			knight = h
	for i in 900:
		if i % 20 == 0 and knight and not b.enemies.is_empty():
			b._attack_vfx(knight, b.enemies[0])
		await RenderingServer.frame_post_draw
		if b.fx_root.get_children().any(func(n: Node) -> bool: return n is VDSwordSlash):
			vp.get_texture().get_image().save_png(OUT + "b_%02d.png" % saved)
			saved += 1
			if saved >= 16:
				break
	print("[slash] saved %d battle frames" % saved)
	get_tree().quit(0)
