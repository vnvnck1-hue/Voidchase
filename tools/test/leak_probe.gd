## 장기 세션 누수 점검: 로비 → 각 모드(몇 초 플레이) → 로비 를 여러 바퀴 돌며
## 로비로 돌아올 때마다 노드·오브젝트·고아 노드·리소스 수와 정적 메모리를 찍는다.
## 바퀴가 늘어도 수치가 계속 오르지 않으면(첫 바퀴 캐시 적재 뒤 평탄) 누수 없음.
##   godot --headless --path . res://tools/test/LeakProbe.tscn -- --rounds=4 --stay=4
extends Node

var rounds := 4
var stay := 4.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			rounds = int(a.substr(9))
		elif a.begins_with("--stay="):
			stay = float(a.substr(7))
	# current_scene 이 바뀌어도 살아남도록 루트에 붙여 진행한다
	get_tree().root.add_child.call_deferred(_Worker.new(rounds, stay))


class _Worker extends Node:
	var rounds: int
	var stay: float
	var _rows: Array[Dictionary] = []

	func _init(r: int, s: float) -> void:
		rounds = r
		stay = s
		name = "LeakProbeWorker"

	func _ready() -> void:
		_run()

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _settle() -> void:
		while SceneSwitcher.is_loading():
			await get_tree().process_frame
		# queue_free 가 처리되도록 몇 프레임 더
		for i in 5:
			await get_tree().process_frame

	func _sample(tag: String) -> void:
		var row := {
			"tag": tag,
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"settings": SceneSwitcher._items.size(),
			"time_scale": Engine.time_scale,
		}
		_rows.append(row)
		print("[leak_probe] %-18s nodes=%5d objects=%6d orphans=%4d resources=%5d mem=%7.1fMB settings=%d time_scale=%.2f" % [
			tag, row.nodes, row.objects, row.orphans, row.resources, row.mem_mb, row.settings, row.time_scale])

	func _run() -> void:
		await _wait(0.3)
		SceneSwitcher.go_lobby()
		await _wait(0.1)
		await _settle()
		_sample("start")
		for r in rounds:
			for i in range(1, SceneSwitcher.SCENES.size()):
				SceneSwitcher.switch_to(i)
				await _wait(0.1)
				await _settle()
				await _wait(stay)
				SceneSwitcher.go_lobby()
				await _wait(0.1)
				await _settle()
			await _wait(0.5)
			_sample("round %d" % (r + 1))
		# 2바퀴째부터 증가량 = 바퀴당 누적분 (첫 바퀴는 캐시·셰이더 적재가 섞인다)
		var fail := 0
		if _rows.size() >= 3:
			var a: Dictionary = _rows[1]
			var b: Dictionary = _rows[_rows.size() - 1]
			var n := float(_rows.size() - 2)
			for k in ["nodes", "objects", "orphans", "resources", "settings"]:
				var per := (float(b[k]) - float(a[k])) / n
				var bad := per > (2.0 if k != "objects" else 20.0)
				if bad:
					fail += 1
				print("[leak_probe] %s %-9s per round %+.1f" % ["FAIL" if bad else "ok  ", k, per])
			print("[leak_probe]      mem       per round %+.2fMB" % ((b.mem_mb - a.mem_mb) / n))
		print("[leak_probe] DONE fail=%d" % fail)
		get_tree().quit(1 if fail > 0 else 0)
