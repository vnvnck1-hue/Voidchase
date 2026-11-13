## 공허 정수 바닥 물리 + HUD 흡수 캡처.
##   결정을 깔고 → 가운데 "kill" 충격 → 튕겨 나가는 프레임 저장, 수치(높이·이동 거리·바닥 위인지) 출력
##   → collect() 동안 정수 글자 크기는 그대로(1.0)이고 아이콘만 커지는지 검사.
## 수치만: Godot --headless --path . res://tools/test/EssencePhysicsCapture.tscn
## 화면까지(서브 모니터): Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/EssencePhysicsCapture.tscn -- --out=<폴더>
extends Node

var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	await get_tree().create_timer(1.5).timeout
	var c := VDData.to_screen(VDMap.center_f(b.room))
	for i in 10:
		b.essence_drops.spawn(c + Vector2.from_angle(i * TAU / 10.0) * Vector2(70, 35), -80.0, 3)
	await get_tree().create_timer(1.6).timeout
	var spawn_spread := _max_stray(b)
	# 충격 검사는 자리 잡은 결정을 다시 가운데 링에 놓고(생성 자리도 그곳으로) 한다
	for i in b.essence_drops.drops.size():
		var p := c + Vector2.from_angle(i * TAU / 10.0) * Vector2(70, 35)
		b.essence_drops.drops[i]["node"].position = p
		b.essence_drops.drops[i]["home"] = p
	var before: Array[Vector2] = []
	for d in b.essence_drops.drops:
		before.append(d["node"].position)
	_shot("0_settled")
	b.shockwave.add(c, "kill", 1.0)
	var max_h := 0.0
	for f in 24:
		await get_tree().process_frame
		for d in b.essence_drops.drops:
			max_h = maxf(max_h, d["h"])
		if f in [4, 10, 18]:
			_shot("1_blast_f%d" % f)
	await get_tree().create_timer(2.0).timeout
	_shot("2_resettled")
	var moved := 0.0
	var off_floor := 0
	var still_air := 0
	for i in b.essence_drops.drops.size():
		var d: Dictionary = b.essence_drops.drops[i]
		moved += (d["node"].position - before[i]).length()
		if not b.map.tiles.has(VDData.to_cell(d["node"].position)):
			off_floor += 1
		if d["h"] > 0.5:
			still_air += 1
	moved /= maxf(1.0, b.essence_drops.drops.size())
	var blast_spread := _max_stray(b)
	print("[ess] max_h=%.1f  avg_moved=%.1f  off_floor=%d  still_air=%d" % [max_h, moved, off_floor, still_air])
	print("[ess] stray from home (flat px): spawn=%.1f  after_blast=%.1f" % [spawn_spread, blast_spread])
	# 소팅: 결정은 유닛과 같은 y 정렬 부모, z 0. 아군 바로 뒤·앞에 하나씩 두고 찍어 본다
	var sorted_ok := true
	for d in b.essence_drops.drops:
		var n: Node2D = d["node"]
		sorted_ok = sorted_ok and n.get_parent() == b.units_root and n.z_index == 0 and n.z_as_relative
	var hero: VDUnit = b.allies[0]
	for a in b.allies:   # 가장 왼쪽 (앞에 가리는 캐릭터가 없는) 아군
		if a.position.x < hero.position.x:
			hero = a
	var behind: Dictionary = b.essence_drops.drops[0]
	var front: Dictionary = b.essence_drops.drops[1]
	behind["node"].position = hero.position + Vector2(10, -18)
	behind["home"] = behind["node"].position
	front["node"].position = hero.position + Vector2(-10, 18)
	front["home"] = front["node"].position
	await get_tree().create_timer(0.3).timeout
	print("[ess] hero=%s %s  behind=%s front=%s" % [hero.display_name, hero.position, behind["node"].position, front["node"].position])
	_shot("5_sort_hero")
	print("[ess] sort: parent=units_root z0=%s" % sorted_ok)
	# 흡수: 글자 크기는 1.0 그대로, 아이콘은 1 보다 커져야 한다
	var lbl: Control = b._lbl_essence
	var icon: Control = b._essence_icon
	var sec := b.essence_drops.collect(icon, b._on_essence_arrive)
	var lbl_max := 0.0
	var icon_max := 0.0
	var t := 0.0
	var shot_done := false
	var trail_shots := 0
	var flash_max := 0.0
	var sparkle_max := 0
	while t < sec + 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		lbl_max = maxf(lbl_max, lbl.scale.x)
		icon_max = maxf(icon_max, maxf(icon.scale.x, icon.scale.y))
		var fv: Variant = (icon.material as ShaderMaterial).get_shader_parameter("flash")
		if fv != null:
			flash_max = maxf(flash_max, fv)
		var n := 0
		for ch in b.hud_root.get_children():
			if ch is TextureRect and (ch as TextureRect).texture == VDEssenceDrops._sparkle:
				n += 1
		sparkle_max = maxi(sparkle_max, n)
		if trail_shots < 2 and t > 0.55 + trail_shots * 0.12:
			_shot("3_trail_%d" % trail_shots)
			trail_shots += 1
		if not shot_done and icon.scale.y > 1.3:
			shot_done = true
			_shot("4_collect_icon_pop")
	print("[ess] collect: label_scale_max=%.3f  icon_scale_max=%.3f  flash_max=%.2f  sparkles_max=%d  essence=%d" % [lbl_max, icon_max, flash_max, sparkle_max, b.essence])
	var ok := max_h > 10.0 and moved > 10.0 and off_floor == 0 and still_air == 0 and lbl_max < 1.001 and icon_max > 1.2 \
		and flash_max > 0.9 and sparkle_max > 5 and sorted_ok and spawn_spread < 110.0 and blast_spread < 110.0
	print("[ess] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## 생성 자리에서 가장 멀리 간 결정의 거리 (아이소 보정 바닥 px).
func _max_stray(b: VDBattle) -> float:
	var m := 0.0
	for d in b.essence_drops.drops:
		var off: Vector2 = d["node"].position - d["home"]
		m = maxf(m, Vector2(off.x, off.y / VDEssenceDrops.ISO).length())
	return m


func _shot(name: String) -> void:
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
