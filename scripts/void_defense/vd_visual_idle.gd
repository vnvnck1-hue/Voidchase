## VOID DEFENSE 원화 조립 씬의 절차 애니메이션. 씬 파일은 그대로 두고 런타임에 노드를 움직인다.
##   영웅   : 몸통이 발밑 피벗 기준으로 숨쉬기(세로 늘었다 줄기), 머리·무기는 따라 올라가며 살짝 기울어진다
##   몬스터 : 보이들링은 발밑 기준 찌그러짐·늘어남 + 좌우 흔들림, 공허 군주는 느린 호흡과 글로우 맥동
##   이펙트 : 총구 섬광은 빠르게 깜빡이고, 회복 십자는 떠오르며 사라지기를 반복
##   프랍   : 돌·아치·기둥은 피벗 기준으로 가볍게 흔들리며 위아래로 떠다니고(파편일수록 크게), 깃발은 펄럭인다(skew)
## 모든 기준값은 setup() 때 씬에서 읽어 두고, enabled 를 끄면 기준 자세로 되돌린다.
extends Node

var enabled := true:
	set(v):
		enabled = v
		if not v:
			_reset()

var _t := 0.0
var _items: Array[Dictionary] = []
var _flicker_t := 0.0
var _flicker := 1.0


func setup(canvas: Node2D) -> void:
	_items.clear()
	# 배경 프랍: 피벗 앵커(offset 이 있는) 스프라이트만. 원경·발판·가장자리 매트는 제외
	for s in canvas.get_node("Background").get_children():
		var sp := s as Sprite2D
		if sp == null or sp.offset == Vector2.ZERO:
			continue
		_add(sp, "banner" if sp.name == "star_banner" else "prop", _prop_params(sp.name))
	# 영웅 리그
	for h in canvas.get_node("Heroes").get_children():
		if h.name == "Effects":
			for e in h.get_children():
				var es := e as Sprite2D
				if es:
					_add(es, "flash" if es.name.begins_with("muzzle") else "heal", {"period": 1.4, "rise": 18.0})
			continue
		var ph := _phase(h.name)
		for p in h.get_children():
			var sp := p as Sprite2D
			if sp == null:
				continue
			var kind := "hero_body"
			if sp.name == "head":
				kind = "hero_head"
			elif sp.name.begins_with("weapon"):
				kind = "hero_weapon"
			_add(sp, kind, {"period": 2.6, "phase": ph})
	# 몬스터: 래퍼 Node2D(피격 트윈용) 안의 `sprite` 를 움직인다
	for m in canvas.get_node("Monsters").get_children():
		var sp := m.get_node_or_null("sprite") as Sprite2D
		if sp == null:
			sp = m as Sprite2D
		if sp == null:
			continue
		if m.name == "void_lord":
			_add(sp, "boss", {"period": 3.8, "phase": 0.0})
		else:
			_add(sp, "voidling", {"period": 1.6 + 0.25 * _phase(m.name), "phase": _phase(m.name) * 2.0})
	print("[vd_visual_idle] animating %d nodes" % _items.size())


func _add(n: Sprite2D, kind: String, params: Dictionary) -> void:
	_items.append({
		"node": n, "kind": kind, "p": params,
		"pos": n.position, "rot": n.rotation, "scale": n.scale, "skew": n.skew, "mod": n.modulate,
	})


## 이름에서 정해지는 고정 위상(0~1). 같은 종류끼리 박자가 겹치지 않게 한다.
func _phase(name: String) -> float:
	return float(abs(name.hash()) % 1000) / 1000.0


func _prop_params(name: String) -> Dictionary:
	# 파편(chip)은 가볍게 크게 떠다니고, 돌(rock)은 중간, 아치·기둥은 아주 조금만 흔들린다
	if name.begins_with("chip"):
		return {"rot": 3.0, "bob": 5.0, "period": 2.6 + 1.2 * _phase(name), "phase": _phase(name)}
	if name.begins_with("rock"):
		return {"rot": 0.9, "bob": 2.5, "period": 3.6 + 1.6 * _phase(name), "phase": _phase(name)}
	return {"rot": 0.45, "bob": 1.5, "period": 5.0 + 2.0 * _phase(name), "phase": _phase(name)}


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	_flicker_t += delta
	if _flicker_t > 0.05:
		_flicker_t = 0.0
		_flicker = randf_range(0.7, 1.25)
	for it in _items:
		var n: Sprite2D = it["node"]
		var p: Dictionary = it["p"]
		var base_pos: Vector2 = it["pos"]
		match it["kind"]:
			"prop":
				var w := TAU / float(p["period"])
				var ph: float = p["phase"] * TAU
				n.rotation = it["rot"] + deg_to_rad(p["rot"]) * sin(_t * w + ph)
				n.position = base_pos + Vector2(0, p["bob"] * sin(_t * w * 0.7 + ph * 1.3))
			"banner":
				var ph: float = p["phase"] * TAU
				n.skew = it["skew"] + 0.05 * sin(_t * 4.2 + ph) + 0.02 * sin(_t * 9.1 + ph)
				n.rotation = it["rot"] + deg_to_rad(0.8) * sin(_t * 1.9 + ph)
			"hero_body":
				var b := _breath(p)
				n.scale = it["scale"] * Vector2(1.0 - 0.012 * b, 1.0 + 0.022 * b)
			"hero_head":
				var b := _breath(p)
				n.position = base_pos + Vector2(0, -3.0 * b)
				n.rotation = it["rot"] + deg_to_rad(1.6) * sin(_t * TAU / (p["period"] * 1.7) + p["phase"] * TAU)
			"hero_weapon":
				var b := _breath(p)
				n.position = base_pos + Vector2(0, -2.0 * b)
				n.rotation = it["rot"] + deg_to_rad(1.2) * sin(_t * TAU / (p["period"] * 1.3) + p["phase"] * TAU + 1.0)
			"voidling":
				var w := TAU / float(p["period"])
				var s := sin(_t * w + p["phase"])
				n.scale = it["scale"] * Vector2(1.0 + 0.06 * s, 1.0 - 0.07 * s)
				n.position = base_pos + Vector2(2.5 * sin(_t * w * 0.5 + p["phase"]), 0)
			"boss":
				var w := TAU / float(p["period"])
				var s := sin(_t * w)
				n.scale = it["scale"] * Vector2(1.0 + 0.012 * s, 1.0 + 0.018 * s)
				n.position = base_pos + Vector2(0, -3.0 * sin(_t * w * 0.5))
				n.modulate = it["mod"] * Color(1.0 + 0.06 * s, 1.0, 1.0 + 0.1 * s, 1.0)
			"flash":
				n.scale = it["scale"] * Vector2(_flicker, 0.85 + 0.3 * (_flicker - 0.7))
				n.modulate = Color(it["mod"], clampf(0.6 + 0.4 * _flicker, 0.0, 1.0))
			"heal":
				var period: float = p["period"]
				var u: float = fmod(_t + _phase(n.name) * period, period) / period
				n.position = base_pos + Vector2(0, -p["rise"] * u)
				n.scale = it["scale"] * (0.85 + 0.25 * u)
				n.modulate = Color(it["mod"], 1.0 - u * u)


func _breath(p: Dictionary) -> float:
	return sin(_t * TAU / float(p["period"]) + p["phase"] * TAU)


func _reset() -> void:
	for it in _items:
		var n: Sprite2D = it["node"]
		n.position = it["pos"]
		n.rotation = it["rot"]
		n.scale = it["scale"]
		n.skew = it["skew"]
		n.modulate = it["mod"]
