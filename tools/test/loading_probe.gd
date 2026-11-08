## 페이크 로딩 화면 점검: 로비 → 모드 1 로 들어가며 진행도·굳음을 0.05초마다 기록하고, 창이 있으면 --out=<dir> 에 장면을 찍는다.
##   godot --headless --path . res://tools/test/LoadingProbe.tscn
##   (창) godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/LoadingProbe.tscn -- --out=<dir>
extends Node

var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	# current_scene 이 바뀌어도 살아남도록 루트에 붙은 별도 노드에서 진행
	var worker := Node.new()
	worker.name = "LoadingProbeWorker"
	worker.set_script(load("res://tools/test/loading_probe_worker.gd"))
	worker.set("out_dir", out_dir)
	get_tree().root.add_child.call_deferred(worker)
