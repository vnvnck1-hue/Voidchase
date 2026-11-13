## FTUE 흐름 점검 (헤드리스): 타이틀 → 프롤로그 → 첫 다이브 → 방 5개 → 의뢰 완료 엔딩 → 결과 → 허브(해금·강화)
##   → 두 번째 다이브: 일시정지 메뉴 → 전멸 → 결과. 세이브는 임시 파일을 쓴다 (실제 세이브를 건드리지 않는다).
##   godot --headless --path . res://tools/test/FtueProbe.tscn
## current_scene 이 바뀌어도 살아남도록 루트에 붙인 별도 노드에서 진행한다.
extends Node


func _ready() -> void:
	var worker := Node.new()
	worker.name = "FtueProbeWorker"
	worker.set_script(load("res://tools/test/ftue_probe_worker.gd"))
	get_tree().root.add_child.call_deferred(worker)
