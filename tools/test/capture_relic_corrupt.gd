## 성좌판 침식 칸 캡처 (2026-11-09): 실제 전투 HUD 에서 칸을 열고 유물 몇 개를 놓은 뒤 두 칸을 침식시켜
## 침식 등장(퍼짐) → 유지 → 가리킴(호버) → 정화(걷힘)를 찍는다. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/RelicCorruptCapture.tscn -- --out=res://docs/relic_corrupt/<이름>/ [--style=0|1]
## --style 을 주면 VDRelicHud.set_corrupt_style 로 프리셋을 고른다 (없으면 저장된 값). 출력:
##   full.png (전체 화면) · board.png (성좌판 확대) · spawn_strip.png (침식 퍼짐 6장) · hold_strip.png (유지 중 6장, 움직임)
##   hover.png · purify_strip.png
extends Node

var OUT := "res://docs/relic_corrupt/before/"
var style := -1
const CORRUPT_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 3)]
const RELIC_CELLS := {Vector2i(0, 0): "thunder_shard", Vector2i(0, 1): "ember", Vector2i(1, 2): "resonance", Vector2i(0, 2): "frost_crystal"}

var b: VDBattle
var hud


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=")
			if not OUT.ends_with("/"):
				OUT += "/"
		elif a.begins_with("--style="):
			style = int(a.trim_prefix("--style="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	while b.enemies.is_empty():
		await get_tree().process_frame
	await _wait(1.2)
	hud = b.relic_hud
	if style >= 0 and hud.has_method("set_corrupt_style"):
		hud.set_corrupt_style(style, false)
	var board: VDRelicBoard = b.relic_board
	for c in VDRelicData.BOARD_CELLS:
		board.cells[c] = VDRelicBoard.Cell.OPEN
	for c in RELIC_CELLS:
		board.relics[c] = RELIC_CELLS[c]
	board.changed.emit()
	await _wait(0.3)
	await _shot_full("open")
	# 침식: 두 칸을 차례로 (전투의 corrupt_random 과 같은 신호)
	var frames: Array[Image] = []
	for c in CORRUPT_CELLS:
		board.cells[c] = VDRelicBoard.Cell.CORRUPT
		board.cell_fx.emit(c, "corrupt")
		board.changed.emit()
	for t in [0.0, 0.1, 0.2, 0.3, 0.45, 0.65]:
		await _until(t)
		frames.append(await _crop_cell(CORRUPT_CELLS[0]))
	_strip(frames, "spawn_strip")
	await _wait(0.8)
	await _shot_full("full")
	await _shot_board("board")
	frames.clear()
	for i in 6:
		frames.append(await _crop_cell(CORRUPT_CELLS[0]))
		await _wait(0.13)
	_strip(frames, "hold_strip")
	# 호버: 마우스를 침식 칸 위로 (주입 이벤트)
	var center: Vector2 = hud.get_global_transform_with_canvas() * hud.cell_center(CORRUPT_CELLS[1])
	var ev := InputEventMouseMotion.new()
	ev.position = get_viewport().get_final_transform() * center
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await _wait(0.6)
	await _shot_board("hover")
	# 정화: 정수 무시하고 바로
	_t0 = Time.get_ticks_msec()
	board.purify(CORRUPT_CELLS[0])
	frames.clear()
	for t in [0.0, 0.1, 0.2, 0.3, 0.45, 0.65]:
		await _until(t)
		frames.append(await _crop_cell(CORRUPT_CELLS[0]))
	_strip(frames, "purify_strip")
	print("[corrupt] done ", OUT)
	get_tree().quit(0)


var _t0 := 0


func _until(t: float) -> void:
	if _t0 == 0:
		_t0 = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - _t0) / 1000.0 < t:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _screen_rect(design: Rect2) -> Rect2i:
	var ft := get_viewport().get_final_transform()
	var p0: Vector2 = ft * design.position
	var p1: Vector2 = ft * design.end
	return Rect2i(Vector2i(p0), Vector2i(p1 - p0))


func _shot_full(name: String) -> void:
	(await _grab()).save_png(OUT + name + ".png")


## 성좌판 영역 (칸 10개 둘레) 을 잘라 2배로 키운다
func _shot_board(name: String) -> void:
	var img := await _grab()
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c in VDRelicData.BOARD_CELLS:
		var p: Vector2 = hud.get_global_transform_with_canvas() * hud.cell_center(c)
		lo = lo.min(p)
		hi = hi.max(p)
	var r := _screen_rect(Rect2(lo - Vector2(90, 80), hi - lo + Vector2(180, 160))).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + name + ".png")


func _crop_cell(c: Vector2i) -> Image:
	var img := await _grab()
	var p: Vector2 = hud.get_global_transform_with_canvas() * hud.cell_center(c)
	var r := _screen_rect(Rect2(p - Vector2(95, 85), Vector2(190, 170))).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_LANCZOS)
	return crop


func _strip(frames: Array[Image], name: String) -> void:
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var strip := Image.create(w * frames.size(), h, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i(w * i, 0))
	strip.save_png(OUT + name + ".png")
