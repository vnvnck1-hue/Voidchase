## 공허 망령 촉수 타격 VFX. 조각은 컨셉(몬스터 스킬.psd)에서 뽑은 그대로다 (tools/vfx/extract_wraith_skill.py → VDWraithSkillParts).
##   섬광    흰 연보라 바늘·발톱 조각 무리(A 별 모양 / B 긴 두 줄 / C 발톱 두 줄)가 긴 축을 따라 확 뻗었다가 가늘어지며 사라진다
##   빛      뒤에 보랏빛 방사 글로우 (더하기)
##   파편    어두운 남보라·보라 사각 조각이 맞은 반대쪽으로 튀어 날아간다
##   바닥    큰 타격(마지막 한 방)에는 발밑에 발톱 자국: 어두운 보라가 먼저, 밝은 연보라가 위에
## 컨셉은 공격자가 오른쪽·대상이 왼쪽인 그림이라, 공격이 오른쪽으로 향하면 좌우를 뒤집는다.
class_name VDWraithHitFx
extends RefCounted

const P := preload("res://scripts/void_defense/vd_wraith_skill_parts.gd")
const UNIT_SCALE := 0.47        # 텍스처 px → 화면 px (몬스터 표시 배율 0.234 ÷ PSD_SCALE 0.5)
const GLOW_COL := Color(0.55, 0.2, 1.0)

static var _tex := {}
static var _glow: GradientTexture2D


static func tex(tname: String) -> Texture2D:
	if not _tex.has(tname):
		_tex[tname] = load(P.DIR + tname + ".png")
	return _tex[tname]


static func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


## 섬광(pop): 타격마다 랜덤 크기의 짧은 빛 + 빛줄기.
## at: 맞은 자리, dir: 공격이 날아온 방향(공격자 → 대상), big: 마지막 한 방(더 크게 + 무리 둘).
static func spawn(parent: Node, at: Vector2, dir: Vector2, big := false, k := 1.0) -> Node2D:
	var root := Node2D.new()
	root.position = at
	parent.add_child(root)
	var flip := -1.0 if dir.x > 0.0 else 1.0
	var s := UNIT_SCALE * k * (1.47 if big else 1.12)   # 2026-11-12 사용자 요청으로 40% 키움
	# 빛
	var glow := Sprite2D.new()
	glow.texture = _glow_tex()
	glow.material = VDVfx.add_material()
	glow.modulate = Color(GLOW_COL, 0.75 if big else 0.4)
	glow.scale = Vector2(1.8, 1.4) * s
	root.add_child(glow)
	var gt := root.create_tween()
	gt.tween_property(glow, "scale", Vector2(4.4, 3.0) * s, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.tween_property(glow, "modulate:a", 0.0, 0.22)
	# 섬광: 타격마다 크기가 제각각인 흰 연보라 빛이 아주 짧게 터진다 (타다다닷 — 연타의 박자가 눈에 보이게)
	var pop := randf_range(0.7, 2.3) * (1.4 if big else 1.0)
	for layer in 2:
		var fl := Sprite2D.new()
		fl.texture = _glow_tex()
		fl.material = VDVfx.add_material()
		fl.position = Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		# 바깥 = 넓은 보랏빛, 안 = 작고 하얀 심지
		fl.modulate = Color(0.75, 0.45, 1.0, 0.95) if layer == 0 else Color(1.0, 0.96, 1.0, 1.0)
		var fs := pop * UNIT_SCALE * (1.9 if layer == 0 else 0.95)
		fl.scale = Vector2(fs, fs) * 0.55
		root.add_child(fl)
		var ft := root.create_tween()
		ft.tween_property(fl, "scale", Vector2(fs, fs) * Vector2(1.35, 1.0), 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.tween_property(fl, "modulate:a", 0.0, randf_range(0.05, 0.09))
	# 가로로 길게 번쩍이는 빛줄기 (랜덤 각도·길이)
	var streak := Sprite2D.new()
	streak.texture = _glow_tex()
	streak.material = VDVfx.add_material()
	streak.modulate = Color(0.95, 0.85, 1.0, 0.95)
	streak.rotation = randf() * PI
	streak.scale = Vector2(pop * 2.6, 0.12) * UNIT_SCALE
	root.add_child(streak)
	var stt := root.create_tween()
	stt.tween_property(streak, "scale", Vector2(pop * 4.2, 0.05) * UNIT_SCALE, 0.05)
	stt.parallel().tween_property(streak, "modulate:a", 0.0, 0.08)
	# 섬광 무리
	var picks: Array = ["A", "B"] if big else [["A", "A", "B", "C"].pick_random()]
	for ci in picks.size():
		var cluster := Node2D.new()
		cluster.scale = Vector2(flip * s, s)
		cluster.rotation = randf_range(-0.55, 0.55) + (0.0 if ci == 0 else 0.3 * flip)
		if ci > 0:
			cluster.position = Vector2(-30.0 * flip, 34.0) * s
		root.add_child(cluster)
		for piece in P.CLUSTERS[picks[ci]]:
			_needle(root, cluster, piece)
	# 파편: 맞은 반대쪽(= dir 쪽)으로
	for i in (7 if big else randi_range(2, 4)):
		_debris(root, dir, s)
	root.create_tween().tween_callback(root.queue_free).set_delay(0.8)
	return root


## 조각 하나: 긴 축(axis)으로 돌린 받침 안에 거꾸로 돌린 스프라이트 → 받침의 x 배율이 긴 축 방향 늘임이 된다.
static func _needle(root: Node2D, cluster: Node2D, piece: Dictionary) -> void:
	var hold := Node2D.new()
	hold.position = piece["pos"]
	hold.rotation = piece["axis"]
	cluster.add_child(hold)
	var sp := Sprite2D.new()
	sp.texture = tex(piece["tex"])
	sp.rotation = -float(piece["axis"])
	hold.add_child(sp)
	var dark: bool = piece["dark"]
	var wait := randf_range(0.0, 0.035) + (0.02 if dark else 0.0)
	hold.scale = Vector2(0.12, 1.7)
	hold.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_interval(wait)
	tw.tween_property(hold, "modulate:a", 0.85 if dark else 1.0, 0.01)
	tw.parallel().tween_property(hold, "scale", Vector2(1.18, 1.0), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hold, "scale", Vector2(1.0, 0.9), 0.04)
	tw.tween_property(hold, "scale", Vector2(1.3, 0.0), 0.15 if dark else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if dark:
		tw.parallel().tween_property(hold, "modulate:a", 0.0, 0.15)


static func _debris(root: Node2D, dir: Vector2, s: float) -> void:
	var sp := Sprite2D.new()
	sp.texture = tex(P.DEBRIS.pick_random())
	sp.scale = Vector2.ONE * s * randf_range(0.7, 1.15)
	sp.rotation = randf() * TAU
	sp.position = Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 10.0))
	root.add_child(sp)
	root.move_child(sp, 1)   # 빛 위, 섬광 아래
	var vel := dir.rotated(randf_range(-0.95, 0.95)) * randf_range(170.0, 420.0) + Vector2(0, randf_range(-150.0, -20.0))
	var from := sp.position
	var life := randf_range(0.32, 0.52)
	var spin := randf_range(-9.0, 9.0)
	var rot0 := sp.rotation
	var tw := root.create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		# 처음에 빠르고 곧 느려지며 떨어진다
		var e := 1.0 - (1.0 - t / life) * (1.0 - t / life)
		sp.position = from + vel * life * 0.55 * e + Vector2(0, 260.0 * t * t)
		sp.rotation = rot0 + spin * t, 0.0, life, life)
	tw.tween_property(sp, "modulate:a", 0.0, life * 0.45).set_delay(life * 0.55)


## 바닥 발톱 자국 (발밑, 바닥 이펙트 층에). dir 는 spawn 과 같다.
static func ground(parent: Node, at: Vector2, dir: Vector2, k := 1.0) -> void:
	var root := Node2D.new()
	root.position = at
	var flip := -1.0 if dir.x > 0.0 else 1.0
	parent.add_child(root)
	for i in 2:
		var sp := Sprite2D.new()
		sp.texture = tex(P.GROUND[i])
		var s := UNIT_SCALE * k * 1.4
		sp.position = Vector2(-6.0 * flip * i, 0.0)
		sp.scale = Vector2(flip * s * 0.25, s * 0.5)
		sp.modulate.a = 0.0
		root.add_child(sp)
		var tw := root.create_tween()
		tw.tween_interval(0.035 * i)
		tw.tween_property(sp, "modulate:a", 0.95, 0.02)
		tw.parallel().tween_property(sp, "scale", Vector2(flip * s * 1.08, s), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector2(flip * s, s * 0.92), 0.12)
		tw.tween_property(sp, "modulate:a", 0.0, 0.28 - 0.06 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	root.create_tween().tween_callback(root.queue_free).set_delay(0.8)
