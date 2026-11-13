## FTUE 화면 캡처 진입점 (tools/test/ftue_capture_worker.gd 를 루트에 붙여 씬이 바뀌어도 이어 간다).
extends Node


func _ready() -> void:
	var worker := Node.new()
	worker.name = "FtueCaptureWorker"
	worker.set_script(load("res://tools/test/ftue_capture_worker.gd"))
	get_tree().root.add_child.call_deferred(worker)
