## 로비 전환 점검: 로비 → 각 모드 → Esc(로비) 가 SceneSwitcher 로 도는지 헤드리스에서 확인.
##   godot --headless --path . res://tools/test/LobbyProbe.tscn
## 창이 있으면 --out=<dir> 로 로비·각 모드 스크린샷을 저장한다.
extends Node

var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	# current_scene 이 바뀌어도 살아남도록 루트에 붙은 별도 노드에서 진행
	var worker := Node.new()
	worker.name = "LobbyProbeWorker"
	worker.set_script(load("res://tools/test/lobby_probe_worker.gd"))
	worker.set("out_dir", out_dir)
	get_tree().root.add_child.call_deferred(worker)
