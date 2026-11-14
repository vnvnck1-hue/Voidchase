extends Node

const SHOTS := [0.5, 0.65, 0.8, 1.3, 2.2, 2.9]
var out_dir := ""


func _ready() -> void:
	_run()


func _run() -> void:
	# 로비 → 모드 1 (SceneSwitcher.SCENES[1])
	var tree := get_tree()
	var dir := out_dir
	SceneSwitcher.go_lobby()
	await tree.create_timer(0.1).timeout
	while SceneSwitcher.is_loading():   # 테스트 씬 → 로비 전환이 끝나야 다음 전환을 받는다
		await tree.process_frame
	await tree.create_timer(0.5).timeout
	var t0 := Time.get_ticks_usec()
	SceneSwitcher.switch_to(1)
	var ls = SceneSwitcher._loading
	print("[loading_probe] planned %.2fs" % ls._duration)
	var shots := SHOTS.duplicate()
	var last_line := ""
	var frozen_frames := 0
	var prev_shown := -1.0
	while SceneSwitcher.is_loading():
		await tree.process_frame
		var t := (Time.get_ticks_usec() - t0) / 1e6
		if is_instance_valid(ls):
			if ls._shown == prev_shown:
				frozen_frames += 1
			prev_shown = ls._shown
			var line := "%3d%% %s" % [int(ls._progress_at(ls._shown) * 100), "FROZEN" if ls._shown < ls.elapsed() - 0.02 else ""]
			if line != last_line:
				print("[loading_probe] t=%.2f %s" % [t, line])
				last_line = line
		if not shots.is_empty() and t >= shots[0] and dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var img := tree.root.get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(dir)
			img.save_png(dir.path_join("loading_%.1f.png" % shots[0]))
			shots.pop_front()
	var total := (Time.get_ticks_usec() - t0) / 1e6
	var cur := SceneSwitcher.current_index()
	print("[loading_probe] done total=%.2fs scene=%d frozen_frames=%d %s" % [total, cur, frozen_frames, "OK" if cur == 1 and total > 0.9 and total < 4.5 else "FAILED"])
	tree.quit(0 if cur == 1 else 1)
