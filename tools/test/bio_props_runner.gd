extends "res://tools/test/bio_lab_runner.gd"
const OUT := "res://docs/bio_lab_props_runtime/"
var prop_failures: Array[String] = []
var prop_checks: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	audit_room("initial")
	var map_before := _b.map.tiles.duplicate(true)
	var items_before: Array = _b.bio_props.items.map(func(item: Dictionary) -> Vector2: return item["base"])
	_b.set_background_theme(VDWorldTheme.Kind.VOID, false)
	_check(not _b.bio_props.visible and _b.props.back.visible, "void hides bio decorations")
	_b.set_background_theme(VDWorldTheme.Kind.DESERT, false)
	_check(not _b.bio_props.visible, "desert hides bio decorations")
	_b.set_background_theme(VDWorldTheme.Kind.BIO, false)
	_check(_b.bio_props.visible and items_before == _b.bio_props.items.map(func(item: Dictionary) -> Vector2: return item["base"]) and _b.map.tiles == map_before, "bio restores same decorations without moving units/map")
	write_report()


func _check(ok: bool, label: String) -> void:
	print("[bio-props-game] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		prop_failures.append(label)


func audit_room(phase: String) -> void:
	var room_id: int = _b.room["id"]
	var count := _b.bio_props.room_count(room_id)
	var overlap := 0
	for item in _b.bio_props.items:
		for cell in item["cells"]:
			if _b.map.tiles.has(cell): overlap += 1
	_check(count == 3, "room %d has all three props" % room_id)
	_check(overlap == 0, "decorative supports never occupy playable cells")
	prop_checks.append({"phase": phase, "room": room_id, "shape": _b.room["shape"], "props": count, "playable_overlap": overlap})
	write_report()
	if not prop_failures.is_empty():
		get_tree().quit(1)


func _on_state(s: int) -> void:
	if s == VDBattle.State.PLACEMENT and _started:
		audit_room("arrived")
	super._on_state(s)


func write_report() -> void:
	var f := FileAccess.open(OUT + "gameplay_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rooms": prop_checks, "failures": prop_failures}, "\t"))
	f.close()

