## 게임 화면 잠깐 녹화 (SceneSwitcher 자식, 설정 메뉴 [화면 녹화] · F12).
## 화면은 매 프레임 그린 뒤(RenderingServer.frame_post_draw) 루트 뷰포트를 읽어 JPEG 로 굽고, 게임 소리는 Master 버스에
## AudioEffectCapture 를 잠깐 꽂아 받는다. 둘을 MJPEG + PCM AVI 하나로 쓴다 — 외부 프로그램(ffmpeg 등) 없이 바로 재생되는 파일.
## 저장 위치: 윈도 "동영상/KSC_Touch_Game" 폴더 (없으면 user://recordings). MAX_SEC 가 지나면 저절로 멈춘다.
## 시간은 실제 시간 기준이다: 게임이 멈칫해 프레임을 못 찍으면 직전 프레임을 그만큼 반복해 넣어 소리와 어긋나지 않게 한다.
## JPEG 굽기는 WorkerThreadPool 에서, 파일 쓰기는 메인 스레드에서 순서대로 한다. 녹화 중 표시(● REC)는 톱니 왼쪽에 뜨고 누르면 멈춘다.
extends Control

const FPS := 30
const MAX_SEC := 60.0
const MAX_HEIGHT := 1080          # 이보다 큰 창(울트라와이드 전체화면 등)은 이 높이로 줄여 굽는다
const JPEG_QUALITY := 0.85
const MAX_PENDING := 6            # 굽는 중인 프레임이 이보다 많으면 이번 프레임은 건너뛴다 (나중에 반복으로 메운다)
const PILL_RECT := Rect2(1716, 20, 136, 36)
const TOAST_RECT := Rect2(1404, 68, 500, 52)

signal saved(path: String)

## 비우면 동영상 폴더. 테스트(tools/test/RecorderProbe.tscn)가 다른 곳으로 돌릴 때만 쓴다.
var out_dir := ""
var _file: FileAccess
var _path := ""
var _size := Vector2i.ZERO
var _t0 := 0
## 찍기로 한 프레임 수 (반복 포함) / 파일에 쓴 프레임 수
var _scheduled := 0
var _written := 0
## 굽는 중: [{seq, task, repeat}] 순서대로. 다 구운 JPEG 는 _done[seq]
var _queue: Array[Dictionary] = []
var _done := {}
var _mutex := Mutex.new()
var _seq := 0
## movi 안 청크 목록 (idx1 용): [fourcc, offset, size]
var _index: Array = []
var _movi_pos := 0
var _max_frame_bytes := 0
var _audio_bytes := 0
var _mix_rate := 44100
var _capture: AudioEffectCapture
var _pill: Button
var _toast: Button
var _toast_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pill = Button.new()
	_pill.focus_mode = Control.FOCUS_NONE
	_pill.tooltip_text = "녹화 멈춤 (F12)"
	_pill.add_theme_stylebox_override("normal", _flat(Color(0.35, 0.03, 0.08, 0.85)))
	_pill.add_theme_stylebox_override("hover", _flat(Color(0.55, 0.05, 0.12, 0.95)))
	_pill.add_theme_stylebox_override("pressed", _flat(Color(0.55, 0.05, 0.12, 0.95)))
	_pill.add_theme_font_size_override("font_size", 17)
	SceneSwitcher.pin(_pill, Vector2(1, 0), PILL_RECT)
	_pill.pressed.connect(stop)
	_pill.visible = false
	add_child(_pill)
	_toast = Button.new()
	_toast.focus_mode = Control.FOCUS_NONE
	_toast.clip_text = true
	_toast.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast.add_theme_stylebox_override("normal", _flat(Color(0.07, 0.05, 0.13, 0.95)))
	_toast.add_theme_stylebox_override("hover", _flat(Color(0.16, 0.11, 0.28, 0.98)))
	_toast.add_theme_stylebox_override("pressed", _flat(Color(0.16, 0.11, 0.28, 0.98)))
	_toast.add_theme_font_size_override("font_size", 16)
	SceneSwitcher.pin(_toast, Vector2(1, 0), TOAST_RECT)
	_toast.pressed.connect(func() -> void:
		if _path != "":
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_path))
		_toast.visible = false)
	_toast.visible = false
	add_child(_toast)


func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(1, 0.55, 0.65, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


func is_recording() -> bool:
	return _file != null


func toggle() -> void:
	if is_recording():
		stop()
	else:
		start()


## 설정 메뉴에 보일 글
func menu_text() -> String:
	if is_recording():
		return "녹화 멈춤  %s  (F12)" % _clock()
	return "화면 녹화 시작  (F12)"


func start() -> void:
	if is_recording():
		return
	var dir := out_dir
	if dir == "":
		dir = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
		dir = "user://recordings" if dir == "" else dir.path_join("KSC_Touch_Game")
	DirAccess.make_dir_recursive_absolute(dir)
	_path = dir.path_join("KSC_%s.avi" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_show_toast("녹화 실패: 파일을 만들 수 없습니다")
		return
	var vp := get_tree().root.get_texture().get_size()
	var k := minf(1.0, float(MAX_HEIGHT) / vp.y)
	_size = Vector2i(int(vp.x * k) & ~1, int(vp.y * k) & ~1)
	_mix_rate = int(AudioServer.get_mix_rate())
	_scheduled = 0
	_written = 0
	_seq = 0
	_queue.clear()
	_done.clear()
	_index.clear()
	_max_frame_bytes = 0
	_audio_bytes = 0
	_write_headers()
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0   # 메인 스레드가 1~2초 멈칫해도 소리가 비지 않게
	AudioServer.add_bus_effect(0, _capture)
	_t0 = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_grab)
	_pill.visible = true
	_toast.visible = false
	print("[recorder] start ", _path, " ", _size)


func stop() -> void:
	if not is_recording():
		return
	RenderingServer.frame_post_draw.disconnect(_grab)
	_flush(true)
	_flush_audio()
	var fx := _bus_effect_index()
	if fx >= 0:
		AudioServer.remove_bus_effect(0, fx)
	_capture = null
	_finish()
	_file.close()
	_file = null
	_pill.visible = false
	print("[recorder] saved ", _path, " frames=", _written)
	_show_toast("저장됨  %s  ·  눌러서 폴더 열기" % _path.get_file())
	saved.emit(_path)


func _process(delta: float) -> void:
	if _toast.visible:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
	if not is_recording():
		return
	_flush()
	_flush_audio()
	_pill.text = "●  REC  " + _clock()
	if _elapsed() >= MAX_SEC:
		stop()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		toggle()
		get_viewport().set_input_as_handled()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = 6.0


func _elapsed() -> float:
	return (Time.get_ticks_usec() - _t0) / 1000000.0


func _clock() -> String:
	var s := int(_elapsed())
	return "%02d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- capture

## 화면을 다 그린 직후: 지금까지 있어야 할 프레임 수만큼 밀려 있으면 이번 화면을 그 수만큼 반복할 프레임으로 찍는다.
func _grab() -> void:
	var due := int(_elapsed() * FPS) + 1 - _scheduled
	if due <= 0 or _queue.size() >= MAX_PENDING:
		return
	var img := get_tree().root.get_texture().get_image()
	if img == null:
		return
	var seq := _seq
	_seq += 1
	_scheduled += due
	var task := WorkerThreadPool.add_task(_encode.bind(seq, img), false, "screen_recorder")
	_queue.append({"seq": seq, "task": task, "repeat": due})


func _encode(seq: int, img: Image) -> void:
	if img.get_size() != _size:
		img.resize(_size.x, _size.y, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var jpg := img.save_jpg_to_buffer(JPEG_QUALITY)
	_mutex.lock()
	_done[seq] = jpg
	_mutex.unlock()


## 앞에서부터 다 구운 프레임을 순서대로 파일에 쓴다. block 이면 굽는 중인 것도 다 기다린다 (멈출 때).
func _flush(block := false) -> void:
	while not _queue.is_empty():
		var q: Dictionary = _queue[0]
		if not block and not WorkerThreadPool.is_task_completed(q["task"]):
			return
		WorkerThreadPool.wait_for_task_completion(q["task"])
		_queue.pop_front()
		_mutex.lock()
		var jpg: PackedByteArray = _done[q["seq"]]
		_done.erase(q["seq"])
		_mutex.unlock()
		_max_frame_bytes = maxi(_max_frame_bytes, jpg.size())
		for i in q["repeat"]:
			_chunk("00dc", jpg)
			_written += 1


func _flush_audio() -> void:
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var buf := _capture.get_buffer(n)
	var pcm := PackedByteArray()
	pcm.resize(buf.size() * 4)
	for i in buf.size():
		var s := buf[i]
		pcm.encode_s16(i * 4, int(clampf(s.x, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(i * 4 + 2, int(clampf(s.y, -1.0, 1.0) * 32767.0))
	_chunk("01wb", pcm)
	_audio_bytes += pcm.size()


func _bus_effect_index() -> int:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _capture:
			return i
	return -1


# ---------------------------------------------------------------- AVI (RIFF)
# RIFF 'AVI ' { LIST hdrl { avih, LIST strl {strh vids, strf}, LIST strl {strh auds, strf} }, LIST movi {...}, idx1 }
# 길이 칸은 0 으로 써 두고 _finish() 에서 되돌아가 채운다.

const _AVIH_FRAMES := 48          # 파일 안 위치 (헤더 크기가 고정이라 상수로 둔다)
const _VSTRH_LENGTH := 140
const _ASTRH_LENGTH := 264
const _AVIH_BUFSIZE := 60
const _VSTRH_BUFSIZE := 144


func _fourcc(s: String) -> void:
	_file.store_buffer(s.to_ascii_buffer())


func _write_headers() -> void:
	var bpf := 4   # 16bit 스테레오 한 샘플 = 4 바이트
	_fourcc("RIFF"); _file.store_32(0); _fourcc("AVI ")
	_fourcc("LIST"); _file.store_32(4 + 64 + 12 + 64 + 48 + 12 + 64 + 24); _fourcc("hdrl")
	# avih (56)
	_fourcc("avih"); _file.store_32(56)
	_file.store_32(1000000 / FPS)
	_file.store_32(0)
	_file.store_32(0)
	_file.store_32(0x10)            # AVIF_HASINDEX
	_file.store_32(0)               # 총 프레임 (_AVIH_FRAMES)
	_file.store_32(0)
	_file.store_32(2)               # 스트림 수
	_file.store_32(0)               # 권장 버퍼 (_AVIH_BUFSIZE)
	_file.store_32(_size.x)
	_file.store_32(_size.y)
	for i in 4:
		_file.store_32(0)
	# 영상 스트림
	_fourcc("LIST"); _file.store_32(4 + 64 + 48); _fourcc("strl")
	_fourcc("strh"); _file.store_32(56)
	_fourcc("vids"); _fourcc("MJPG")
	_file.store_32(0); _file.store_32(0); _file.store_32(0)
	_file.store_32(1); _file.store_32(FPS)          # scale / rate
	_file.store_32(0)
	_file.store_32(0)                                # 길이 (_VSTRH_LENGTH)
	_file.store_32(0)                                # 권장 버퍼 (_VSTRH_BUFSIZE)
	_file.store_32(0xFFFFFFFF)
	_file.store_32(0)
	_file.store_16(0); _file.store_16(0); _file.store_16(_size.x); _file.store_16(_size.y)
	_fourcc("strf"); _file.store_32(40)
	_file.store_32(40)
	_file.store_32(_size.x)
	_file.store_32(_size.y)
	_file.store_16(1); _file.store_16(24)
	_fourcc("MJPG")
	_file.store_32(_size.x * _size.y * 3)
	for i in 4:
		_file.store_32(0)
	# 소리 스트림 (16bit 스테레오 PCM)
	_fourcc("LIST"); _file.store_32(4 + 64 + 24); _fourcc("strl")
	_fourcc("strh"); _file.store_32(56)
	_fourcc("auds"); _file.store_32(0)
	_file.store_32(0); _file.store_32(0); _file.store_32(0)
	_file.store_32(bpf); _file.store_32(_mix_rate * bpf)   # scale / rate → 1 단위 = 샘플 1개
	_file.store_32(0)
	_file.store_32(0)                                # 길이 (_ASTRH_LENGTH, 샘플 수)
	_file.store_32(_mix_rate * bpf)
	_file.store_32(0xFFFFFFFF)
	_file.store_32(bpf)
	_file.store_16(0); _file.store_16(0); _file.store_16(0); _file.store_16(0)
	_fourcc("strf"); _file.store_32(16)
	_file.store_16(1); _file.store_16(2)             # PCM, 2채널
	_file.store_32(_mix_rate)
	_file.store_32(_mix_rate * bpf)
	_file.store_16(bpf); _file.store_16(16)
	_fourcc("LIST"); _file.store_32(0); _fourcc("movi")
	_movi_pos = _file.get_position() - 4


func _chunk(id: String, data: PackedByteArray) -> void:
	_index.append([id, _file.get_position() - _movi_pos, data.size()])
	_fourcc(id)
	_file.store_32(data.size())
	_file.store_buffer(data)
	if data.size() % 2 == 1:
		_file.store_8(0)


func _finish() -> void:
	var movi_end := _file.get_position()
	_fourcc("idx1")
	_file.store_32(_index.size() * 16)
	for e in _index:
		_fourcc(e[0])
		_file.store_32(0x10)   # 키프레임 (MJPEG·PCM 은 전부 독립 청크)
		_file.store_32(e[1])
		_file.store_32(e[2])
	var end := _file.get_position()
	_file.seek(4); _file.store_32(end - 8)
	_file.seek(_movi_pos - 4); _file.store_32(movi_end - _movi_pos)
	_file.seek(_AVIH_FRAMES); _file.store_32(_written)
	_file.seek(_AVIH_BUFSIZE); _file.store_32(_max_frame_bytes + 8)
	_file.seek(_VSTRH_LENGTH); _file.store_32(_written)
	_file.seek(_VSTRH_BUFSIZE); _file.store_32(_max_frame_bytes + 8)
	_file.seek(_ASTRH_LENGTH); _file.store_32(_audio_bytes / 4)
	_file.seek(end)
