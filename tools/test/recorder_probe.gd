## 화면 녹화 점검: 로비를 띄우고 SceneSwitcher.recorder 로 몇 초 녹화한 뒤 AVI 를 다시 읽어 헤더·프레임 수·첫 프레임 JPEG 를 확인한다.
## 창이 필요하다 (헤드리스는 화면을 못 읽는다):
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/RecorderProbe.tscn -- --out=<dir> [--sec=3]
## <dir> 에 녹화 avi 와 첫·마지막 프레임 png 를 남긴다. 결과는 [recorder_probe] OK / FAIL 줄.
extends Node

var worker := false
var out_dir := ""
var sec := 3.0


func _ready() -> void:
	if worker:
		_run()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--sec="):
			sec = a.substr(6).to_float()
	var w := Node.new()
	w.set_script(get_script())
	w.set("worker", true)
	w.set("out_dir", out_dir)
	w.set("sec", sec)
	get_tree().root.add_child.call_deferred(w)
	get_tree().change_scene_to_file.call_deferred(SceneSwitcher.SCENES[SceneSwitcher.LOBBY]["path"])


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var rec = SceneSwitcher.recorder
	rec.out_dir = out_dir
	rec.start()
	await get_tree().create_timer(sec * 0.5).timeout
	SceneSwitcher.set_menu_open(true)   # 메뉴 글자가 녹화 시간으로 바뀌는지
	await get_tree().create_timer(sec * 0.5).timeout
	SceneSwitcher.set_menu_open(false)
	var path: String = rec._path
	rec.stop()
	print("[recorder_probe] file ", path, " ", FileAccess.get_file_as_bytes(path).size(), " bytes")
	_check(path)
	get_tree().quit()


func _check(path: String) -> void:
	var b := FileAccess.get_file_as_bytes(path)
	var fail := []
	if b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "AVI ":
		fail.append("RIFF 머리")
	if b.decode_u32(4) != b.size() - 8:
		fail.append("RIFF 크기 %d != %d" % [b.decode_u32(4), b.size() - 8])
	var frames := b.decode_u32(48)
	var samples := b.decode_u32(264)
	var w := b.decode_u32(64)
	var h := b.decode_u32(68)
	print("[recorder_probe] %dx%d frames=%d (%.2fs) audio=%d (%.2fs)" % [w, h, frames, frames / 30.0, samples, samples / AudioServer.get_mix_rate()])
	if absf(frames / 30.0 - sec) > 0.5:
		fail.append("프레임 수가 녹화 시간과 다름")
	# movi 를 훑어 영상 청크 수를 세고 첫·마지막 JPEG 를 풀어 본다
	var pos := 324
	var movi_end := 320 + b.decode_u32(316)
	var jpgs := []
	var audio_chunks := 0
	while pos < movi_end:
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var n := b.decode_u32(pos + 4)
		if id == "00dc":
			jpgs.append(b.slice(pos + 8, pos + 8 + n))
		elif id == "01wb":
			audio_chunks += 1
		else:
			fail.append("모르는 청크 " + id)
			break
		pos += 8 + n + (n % 2)
	if jpgs.size() != frames:
		fail.append("영상 청크 %d != 프레임 %d" % [jpgs.size(), frames])
	if b.slice(movi_end, movi_end + 4).get_string_from_ascii() != "idx1":
		fail.append("idx1 없음")
	elif b.decode_u32(movi_end + 4) / 16 != jpgs.size() + audio_chunks:
		fail.append("idx1 항목 수")
	for k in [0, jpgs.size() - 1]:
		if jpgs.is_empty():
			break
		var img := Image.new()
		if img.load_jpg_from_buffer(jpgs[k]) != OK or img.get_size() != Vector2i(w, h):
			fail.append("JPEG %d 풀기 실패" % k)
		else:
			img.save_png(out_dir.path_join("frame_%d.png" % k))
	print("[recorder_probe] ", "OK" if fail.is_empty() else "FAIL " + str(fail))
