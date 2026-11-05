extends SceneTree
## Frame-time probe for character switching (needs a real renderer, run windowed on the sub monitor).

var cs: CharacterSelect
var sc: Node

func _init() -> void:
	var inst: Node = load("res://scenes/Touch_Game_demo_anim.tscn").instantiate()
	root.add_child(inst)
	cs = inst.get_node("BG_all/characters_list")
	sc = inst.get_node("BG_all/stand_character")
	for i in 30:
		await process_frame
	for round in 2:
		for idx in cs.character_indices():
			var t0 := Time.get_ticks_usec()
			cs.select(idx)
			var t1 := Time.get_ticks_usec()
			var worst := 0
			var prev := Time.get_ticks_usec()
			for f in 20:
				await process_frame
				var now := Time.get_ticks_usec()
				worst = maxi(worst, now - prev)
				prev = now
			print("round %d panel %d: select() %.1f ms, worst frame %.1f ms" % [round, idx, (t1 - t0) / 1000.0, worst / 1000.0])
	quit()
