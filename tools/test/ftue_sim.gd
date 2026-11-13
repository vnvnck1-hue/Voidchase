## 의뢰 런 난이도 가늠 (헤드리스): 강화 없이 자동으로 끝까지 돌려 어디서 끝나는지 본다.
##   godot --headless --path . res://tools/test/FtueSim.tscn -- --runs=3 [--upgrades=2]
## 조작: 배치 그대로 시작, 궁극기는 차면 자동, 유물은 첫 카드를 골라 열린 빈 칸에 끼운다, 갈림길은 첫 길.
## --upgrades=N 이면 강화 4종을 각각 N 단계까지 올린 상태로 돈다. 세이브는 임시 파일.
extends Node

const SAVE := "user://ftue_sim_save.cfg"
const SPEED := 8.0

var runs := 3
var upgrades := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--upgrades="):
			upgrades = int(a.substr(11))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	GameSave.use_path(SAVE)
	GameSave.set_hints_enabled(false)
	GameSave.mark_prologue_seen()
	if upgrades > 0:
		GameSave.add_crystals(999)
		for id in GameSave.UPGRADE_ORDER:
			for i in upgrades:
				GameSave.buy_upgrade(id)
	_run()


func _run() -> void:
	var results: Array = []
	for r in runs:
		VDBattle.mode_request = {"mode": "case", "case": "harin"}
		var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
		add_child(b)
		b.auto_ult = true
		b.camera.set_game_speed(SPEED)
		var t0 := Time.get_ticks_msec()
		while not b.case_run.finished and (Time.get_ticks_msec() - t0) / 1000.0 < 300.0:
			await get_tree().process_frame
			match b.state:
				VDBattle.State.PLACEMENT:
					_place_relics(b)
					if not b._spawning:
						b.start_battle()
				VDBattle.State.CHOOSE_PATH:
					_place_relics(b)
					if b.exits.size() > 0:
						b.choose_path(0)
			if b.relic_hud.has_offer() and not b.relic_hud.offer_ids().is_empty():
				b.relic_hud.pick(String(b.relic_hud.offer_ids()[0]))
				await get_tree().create_timer(0.7, true, false, true).timeout
		var alive := 0
		for a in b.allies:
			if a.alive:
				alive += 1
		var cleared: bool = GameSave.is_cleared("harin")
		results.append([int(b.case_run.stats["rooms"]), b.stage, b.wave_in_stage, alive])
		print("[ftue_sim] run %d: rooms=%d  ended at stage %d wave %d  alive=%d  cleared_any=%s  %.0fs" % [r + 1, int(b.case_run.stats["rooms"]), b.stage, b.wave_in_stage, alive, cleared, (Time.get_ticks_msec() - t0) / 1000.0])
		b.queue_free()
		await get_tree().create_timer(0.3, true, false, true).timeout
	print("[ftue_sim] DONE upgrades=%d  %s" % [upgrades, str(results)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## 보관함의 유물·슬롯을 쓸 수 있는 칸에 끼운다.
func _place_relics(b: VDBattle) -> void:
	var board := b.relic_board
	var i := 0
	var guard := 0
	while i < board.tray.size() and guard < 40:
		guard += 1
		var done := false
		for c: Vector2i in board.cells:
			if board.is_slot(i):
				if board.can_unlock(c) and board.unlock_from_tray(i, c):
					done = true
					break
			elif board.relic_at(c) == "" and board.can_place(c) and board.place_from_tray(i, c):
				done = true
				break
		if not done:
			i += 1
