## FTUE 실제 속도 플레이스루 진입점 (tools/test/ftue_playthrough_worker.gd 를 루트에 붙인다).
extends Node


func _ready() -> void:
	var worker := Node.new()
	worker.name = "FtuePlaythroughWorker"
	worker.set_script(load("res://tools/test/ftue_playthrough_worker.gd"))
	get_tree().root.add_child.call_deferred(worker)
