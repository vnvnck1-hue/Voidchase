## Test harness: loads a scene, takes screenshots at given times, optionally simulates a
## click on the monster, then quits. Used from the command line:
##   godot --path . res://tools/test/ShotRunner.tscn -- --scene=res://scenes/Touch_Game_demo.tscn --out=D:/shots --click
extends Node

var scene_path := "res://scenes/Touch_Game_demo.tscn"
var out_dir := "user://shots"
var do_click := false
var direct_act := false
var shot_times: Array[float] = [0.3, 1.0, 2.0]
var click_time := 1.0
var quit_time := 3.0
var _t := 0.0
var _shots_done := 0
var _clicked := false
var _frames := 0
var _instance: Node
var _pending_current := false
var key_to_press := ""
var key_repeat := 1
var key_time := -1.0
var click_repeat := 1
var click_interval := 0.5
var _clicks := 0
var key_burst := 1
var key_interval := 0.5
var _presses := 0
var _max_delta := 0.0
var _next_report := 1.0
## --click_world=x,y (repeatable): synthetic left clicks at world positions, click_interval apart
var world_clicks: Array[Vector2] = []
var _world_clicks_done := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--click":
			do_click = true
		elif a == "--act":
			do_click = true
			direct_act = true
		elif a.begins_with("--shots="):
			shot_times.clear()
			for s in a.substr(8).split(","):
				shot_times.append(float(s))
		elif a.begins_with("--click_time="):
			click_time = float(a.substr(13))
		elif a.begins_with("--key="):
			key_to_press = a.substr(6)
		elif a.begins_with("--key_burst="):
			key_burst = int(a.substr(12))
		elif a.begins_with("--key_time="):
			key_time = float(a.substr(11))
		elif a.begins_with("--click_repeat="):
			click_repeat = int(a.substr(15))
		elif a.begins_with("--click_interval="):
			click_interval = float(a.substr(17))
		elif a.begins_with("--key_repeat="):
			key_repeat = int(a.substr(13))
		elif a.begins_with("--key_interval="):
			key_interval = float(a.substr(15))
		elif a.begins_with("--click_world="):
			var xy := a.substr(14).split(",")
			world_clicks.append(Vector2(float(xy[0]), float(xy[1])))
		elif a.begins_with("--quit="):
			quit_time = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("cannot load " + scene_path)
		get_tree().quit(1)
		return
	_instance = packed.instantiate()
	if key_to_press != "":
		# make the loaded scene the real current_scene so change_scene() works
		get_tree().root.add_child.call_deferred(_instance)
		set_deferred("_pending_current", true)
	else:
		add_child(_instance)
	print("[shot_runner] loaded ", scene_path)


func _process(delta: float) -> void:
	_frames += 1
	if _pending_current and _instance.is_inside_tree():
		_pending_current = false
		get_tree().current_scene = _instance
	_max_delta = maxf(_max_delta, delta)
	if _t >= _next_report:
		_next_report += 1.0
		print("[stat] t=%.1f max_dt=%.3f nodes=%d orphans=%d objects=%d mem=%.1fMB draw=%d" % [_t, _max_delta, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		_max_delta = 0.0
	if key_time < 0.0:
		key_time = click_time
	if key_to_press != "" and _presses < key_repeat and _t >= key_time + _presses * key_interval:
		_presses += 1
		print("[shot_runner] pressing key ", key_to_press, " #", _presses, " x", key_burst, " t=%.2f" % _t)
		for bi in key_burst:
			var k := InputEventKey.new()
			k.keycode = OS.find_keycode_from_string(key_to_press)
			k.pressed = true
			Input.parse_input_event(k)
	_t += delta / maxf(Engine.time_scale, 0.0001)  # real time
	if do_click and _clicks < click_repeat and _t >= click_time + _clicks * click_interval:
		_clicks += 1
		_do_click()
	if _world_clicks_done < world_clicks.size() and _t >= click_time + _world_clicks_done * click_interval:
		_click_world(world_clicks[_world_clicks_done])
		_world_clicks_done += 1
	while _shots_done < shot_times.size() and _t >= shot_times[_shots_done]:
		_take_shot(_shots_done)
		_shots_done += 1
	if _t >= quit_time:
		var cs := get_tree().current_scene
		print("[shot_runner] current_scene=", cs.scene_file_path if cs else "<none>")
		print("[shot_runner] done, frames=", _frames)
		get_tree().quit(0)


func _take_shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("shot_%02d_t%.2f.png" % [i, _t])
	img.save_png(path)
	print("[shot_runner] saved ", path)


func _click_world(gpos: Vector2) -> void:
	var vp := get_viewport()
	var screen_pos: Vector2 = vp.get_screen_transform() * (vp.get_canvas_transform() * gpos)
	print("[shot_runner] click_world ", gpos, " screen=", screen_pos)
	var mm := InputEventMouseMotion.new()
	mm.position = screen_pos
	Input.parse_input_event(mm)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = screen_pos
		Input.parse_input_event(ev)


func _do_click() -> void:
	var scene_root: Node = get_tree().current_scene if key_to_press != "" else _instance
	if scene_root == null:
		print("[shot_runner] no current scene to click")
		return
	var body := scene_root.find_child("body", true, false)
	if body == null:
		print("[shot_runner] no body node to click")
		return
	if direct_act:
		print("[shot_runner] calling act() directly")
		body.act()
		return
	var target: Node2D = body
	var area := body.find_child("BoxCollider2D", false, false)
	var gpos: Vector2 = target.global_position
	if area != null and area.get_child_count() > 0:
		gpos = (area.get_child(0) as Node2D).global_position
	var vp := get_viewport()
	var canvas_pos: Vector2 = vp.get_canvas_transform() * gpos
	var screen_pos: Vector2 = vp.get_screen_transform() * canvas_pos
	print("[shot_runner] clicking world=", gpos, " canvas=", canvas_pos, " screen=", screen_pos)
	var mm := InputEventMouseMotion.new()
	mm.position = screen_pos
	Input.parse_input_event(mm)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen_pos
	Input.parse_input_event(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = screen_pos
	Input.parse_input_event(ev2)
