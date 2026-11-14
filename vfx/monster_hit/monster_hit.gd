## 몬스터 피격 이펙트 (2D, 원샷). play() 를 부르면 hit_dir 방향으로 맞은 타격을 그린다.
## 원본: VFX연구 저장소 vfx/monster_hit/monster_hit.gd (2026-11-10). 이 게임에서는 vd_cartoon_hit_fx.gd 가 값을 넣고 재생한다.
##
## 레이어 (아래 → 위), 30fps 기준 f0 = 접촉
##   ICHOR  체액 방울   f2–f13  맞은 면 바깥(공격자 쪽 위)으로 튀어 중력으로 떨어진다. matter / accent
##   RING   충격파 링   f2–f6   빠르게 퍼지고 두께가 먼저 줄며 끊긴다
##   SPARK  스파크      f0–f7   타격 방향으로 뿜어진다. 빠른 초반엔 길고 느려지면 짧아진다
##   STREAK 타격 선     f0–f3   타격 방향을 가로지르는 얇은 섬광 선
##   FLASH  코어 플래시 f0–f3   흰 코어/노랑/주황 + 어두운 테두리. 뒤쪽(공격자 쪽) 가시는 짧다
##
## 모든 수치는 아래 @export 변수다. 인스펙터나 데모 패널(scenes/monster_hit_demo.tscn)에서 바꾸면
## 다음 play() 부터 반영된다(apply()). 시간 단위는 초, 크기 단위는 px(size = 1 기준).
## 시간은 셰이더 TIME 대신 스크립트 나이(_age)로 구동한다. 매번 같은 결과가 나와야 리뷰가 결정적이다.
extends Node2D

const FIELD_SHADER := preload("res://vfx/monster_hit/hit_field.gdshader")
const RING_SHADER := preload("res://vfx/monster_hit/hit_ring.gdshader")
const TEX_STAR := preload("res://vfx/monster_hit/hit_star.png")
const TEX_SPARK := preload("res://vfx/monster_hit/spark.png")
const TEX_BLOB := preload("res://vfx/monster_hit/blob.png")
const TEX_EROSION := preload("res://vfx/monster_hit/erosion.png")

@export var hit_dir := Vector2.RIGHT       # 타격이 밀고 가는 방향
@export_range(0.3, 3.0, 0.05) var size := 1.0   # 전체 배율. 1 = 몸통 폭 약 200px 기준
@export var seed_value := 1

@export_group("Flash 코어 플래시")
@export_range(0.03, 0.4, 0.005) var flash_life := 0.135
@export_range(50.0, 400.0, 1.0) var flash_size := 205.0        # 별 텍스처 한 변 (px)
@export_range(0.5, 2.5, 0.05) var flash_stretch := 1.5         # 타격 방향 늘림 (세로 0.85 고정)
@export_range(0.0, 60.0, 1.0) var flash_push := 16.0           # 몸 쪽으로 밀어 넣는 거리
@export_range(1.0, 3.0, 0.05) var flash_back_taper := 1.9      # 뒤쪽 가시를 몇 배 짧게
@export_range(0.0, 0.2, 0.005) var flash_rim := 0.09           # 어두운 테두리 두께 (장 단위)
@export_range(0.0, 2.0, 0.05) var flash_erode := 0.9           # 사라질 때 갉아먹는 세기
@export_range(0.0, 1.0, 0.05) var flash_hot_until := 0.5       # 흰 코어가 남는 진행도

@export_group("Streak 타격 선")
@export_range(0.0, 0.3, 0.005) var streak_life := 0.1          # 0 이면 끔
@export_range(50.0, 600.0, 5.0) var streak_length := 270.0
@export_range(2.0, 40.0, 0.5) var streak_width := 18.0

@export_group("Ring 충격파 링")
@export_range(0.0, 0.2, 0.005) var ring_delay := 0.05          # 같은 프레임에 한 번 나이를 먹어 0.05 = f1 시작
@export_range(0.0, 0.5, 0.005) var ring_life := 0.16           # 0 이면 끔
@export_range(60.0, 500.0, 5.0) var ring_size := 230.0         # 쿼드 한 변. 최종 지름 ≈ 0.92배
@export_range(0.0, 0.15, 0.005) var ring_width := 0.05         # 시작 두께 (쿼드 UV 단위)
@export_range(0.0, 1.5, 0.05) var ring_erode := 0.25           # 끊김 세기
@export_range(0.3, 1.0, 0.01) var ring_cut := 0.82             # 이 진행도에서 그리기를 멈춤

@export_group("Spark 스파크")
@export_range(0, 64, 1) var spark_amount := 12
@export_range(0.05, 1.0, 0.01) var spark_life := 0.24
@export_range(0.0, 1.0, 0.05) var spark_life_random := 0.35
@export_range(0.0, 3000.0, 10.0) var spark_speed_min := 900.0
@export_range(0.0, 3000.0, 10.0) var spark_speed_max := 1600.0
@export_range(0.0, 6000.0, 50.0) var spark_damping_min := 1500.0
@export_range(0.0, 6000.0, 50.0) var spark_damping_max := 2200.0
@export_range(0.0, 180.0, 1.0) var spark_spread := 40.0        # 원뿔 반각 (도)
@export_range(-2000.0, 3000.0, 50.0) var spark_gravity := 600.0
@export_range(0.05, 2.0, 0.01) var spark_scale_min := 0.22     # 64px 텍스처 배율
@export_range(0.05, 2.0, 0.01) var spark_scale_max := 0.7
@export_range(1.0, 6.0, 0.1) var spark_stretch := 3.4          # 초반 속도 방향 늘림 (끝에서 1배)
@export_range(0.0, 0.3, 0.005) var spark_rim := 0.11

@export_group("Ichor 체액")
@export_range(0, 64, 1) var ichor_amount := 10
@export_range(0.0, 0.3, 0.005) var ichor_delay := 0.05
@export_range(0.05, 1.5, 0.01) var ichor_life := 0.3
@export_range(0.0, 3000.0, 10.0) var ichor_speed_min := 620.0
@export_range(0.0, 3000.0, 10.0) var ichor_speed_max := 1100.0
@export_range(0.0, 3000.0, 50.0) var ichor_damping_min := 200.0
@export_range(0.0, 3000.0, 50.0) var ichor_damping_max := 400.0
@export_range(0.0, 180.0, 1.0) var ichor_spread := 38.0
@export_range(-1000.0, 5000.0, 50.0) var ichor_gravity := 1900.0
@export_range(0.0, 2.0, 0.05) var ichor_lift := 1.25           # 공격자 쪽 대비 위로 드는 정도 (0 = 정확히 뒤로)
@export_range(0.05, 2.0, 0.01) var ichor_scale_min := 0.14
@export_range(0.05, 2.0, 0.01) var ichor_scale_max := 0.42
@export_range(1.0, 4.0, 0.1) var ichor_stretch := 1.9

@export_group("Colors 색")
# 팔레트: 주색 = 타격 불꽃(흰 → 노랑 → 주황), 강조색 = 몬스터 체액(자홍), 받침 = 어두운 적갈 테두리
@export var col_hot := Color(1.0, 0.98, 0.9)
@export var col_mid := Color(1.0, 0.82, 0.25)
@export var col_body := Color(1.0, 0.42, 0.1)
@export var col_rim := Color(0.16, 0.04, 0.06)
@export var col_ring_hot := Color(1.0, 0.95, 0.75)
@export var col_ring := Color(1.0, 0.6, 0.18)
@export var col_ichor := Color(0.78, 0.16, 0.5)
@export var col_ichor_hi := Color(1.0, 0.55, 0.8)
@export var col_ichor_rim := Color(0.14, 0.02, 0.1)

var _age := 999.0
var _flash_root: Node2D
var _flash: Sprite2D
var _streak: Sprite2D
var _ring: Sprite2D
var _sparks: GPUParticles2D
var _ichor: GPUParticles2D
var _ichor_started := false


func _ready() -> void:
	_ring = _sprite(TEX_BLOB, RING_SHADER)
	_ring.material.set_shader_parameter("erosion", TEX_EROSION)
	_ichor = _particles(TEX_BLOB, _field_mat(TEX_BLOB, {
		"hot_until": 0.0, "mid_until": 0.45, "cut_start": 0.05, "cut_end": 0.97, "cut_power": 1.0,
		"band_mid": 0.5, "rim_width": 0.12, "stretch_end": 1.0}))
	_sparks = _particles(TEX_SPARK, _field_mat(TEX_SPARK, {
		"hot_until": 0.3, "mid_until": 0.65, "cut_start": 0.02, "cut_end": 0.95, "cut_power": 1.0,
		"band_mid": 0.18, "band_hot": 0.4, "stretch_end": 1.0, "hot_gain": 1.15}))
	_streak = _sprite(TEX_SPARK, FIELD_SHADER)
	_set_params(_streak, {"all_white_until": 0.4, "hot_until": 0.6, "mid_until": 1.0, "cut_start": 0.02,
		"cut_end": 0.9, "cut_power": 0.8, "band_mid": 0.15, "band_hot": 0.35, "rim_width": 0.0, "hot_gain": 1.2})
	# 플래시는 타격 방향으로 돌린 부모 안에서 늘린다. 셰이더의 back_taper 로 뒤쪽(공격자 쪽) 가시를 줄여
	# "밀고 들어간 힘"이 앞쪽으로 읽히게 한다
	_flash_root = Node2D.new()
	add_child(_flash_root)
	_flash = _sprite(TEX_STAR, FIELD_SHADER)
	_flash.reparent(_flash_root)
	_set_params(_flash, {"all_white_until": 0.0, "mid_until": 0.8, "cut_start": 0.0, "cut_end": 0.8,
		"cut_power": 1.0, "band_mid": 0.12, "band_hot": 0.3, "erode_scale": 0.8, "hot_gain": 1.2})
	_flash.material.set_shader_parameter("erosion", TEX_EROSION)
	apply()
	_hide_all()


## @export 값을 머티리얼·파티클에 반영한다. play() 가 매번 부르므로 값만 바꾸면 다음 타격부터 적용된다.
func apply() -> void:
	var fire := {"col_hot": col_hot, "col_mid": col_mid, "col_body": col_body, "col_rim": col_rim}
	_set_params(_flash, fire)
	_set_params(_flash, {"back_taper": flash_back_taper, "rim_width": flash_rim, "erode": flash_erode,
		"hot_until": flash_hot_until})
	_set_params(_streak, fire)
	_set_params(_ring, {"col_hot": col_ring_hot, "col_body": col_ring, "col_rim": col_rim,
		"width_start": ring_width, "erode": ring_erode})

	_set_params(_sparks, fire)
	_set_params(_sparks, {"rim_width": spark_rim, "stretch_start": spark_stretch})
	# amount·lifetime 은 바꾸면 버퍼를 새로 만들어 날아가던 입자가 지워지므로, 값이 달라졌을 때만 넣는다
	if _sparks.amount != maxi(spark_amount, 1):
		_sparks.amount = maxi(spark_amount, 1)
	if not is_equal_approx(_sparks.lifetime, spark_life):
		_sparks.lifetime = spark_life
	var sm := _sparks.process_material as ParticleProcessMaterial
	sm.spread = spark_spread
	sm.initial_velocity_min = spark_speed_min * size
	sm.initial_velocity_max = maxf(spark_speed_max, spark_speed_min) * size
	sm.damping_min = spark_damping_min * size
	sm.damping_max = maxf(spark_damping_max, spark_damping_min) * size
	sm.gravity = Vector3(0, spark_gravity * size, 0)
	sm.scale_min = spark_scale_min * size
	sm.scale_max = maxf(spark_scale_max, spark_scale_min) * size
	sm.lifetime_randomness = spark_life_random
	sm.emission_sphere_radius = 4.0 * size

	_set_params(_ichor, {"col_hot": col_ichor_hi, "col_mid": col_ichor_hi, "col_body": col_ichor,
		"col_rim": col_ichor_rim, "stretch_start": ichor_stretch})
	# amount·lifetime 은 바꾸면 버퍼를 새로 만들어 날아가던 입자가 지워지므로, 값이 달라졌을 때만 넣는다
	if _ichor.amount != maxi(ichor_amount, 1):
		_ichor.amount = maxi(ichor_amount, 1)
	if not is_equal_approx(_ichor.lifetime, ichor_life):
		_ichor.lifetime = ichor_life
	var im := _ichor.process_material as ParticleProcessMaterial
	im.spread = ichor_spread
	im.initial_velocity_min = ichor_speed_min * size
	im.initial_velocity_max = maxf(ichor_speed_max, ichor_speed_min) * size
	im.damping_min = ichor_damping_min * size
	im.damping_max = maxf(ichor_damping_max, ichor_damping_min) * size
	im.gravity = Vector3(0, ichor_gravity * size, 0)
	im.scale_min = ichor_scale_min * size
	im.scale_max = maxf(ichor_scale_max, ichor_scale_min) * size
	im.lifetime_randomness = 0.2
	im.emission_sphere_radius = 10.0 * size


func play() -> void:
	apply()
	var d := hit_dir.normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_age = 0.0
	_ichor_started = false

	# 플래시: 타격 방향으로 늘리고 몸 쪽으로 조금 밀어 넣는다. 가시 각도는 매번 조금 다르게
	_flash_root.rotation = d.angle()
	_flash_root.position = d * flash_push * size
	_flash.rotation = rng.randf_range(-0.15, 0.15)
	_flash.material.set_shader_parameter("erode_offset", Vector2(rng.randf(), rng.randf()))
	_streak.rotation = d.angle() + PI * 0.5 + rng.randf_range(-0.12, 0.12)
	_ring.rotation = d.angle()
	_ring.material.set_shader_parameter("angle_offset", rng.randf())

	_sparks.rotation = d.angle()
	# 체액은 상처 바깥(공격자 쪽)으로, 위로 들려서 튄다. 스파크와 반대 방향이라 방향 대비가 생긴다
	var up := Vector2.UP if absf(d.y) < 0.9 else Vector2.LEFT
	_ichor.rotation = (-d + up * ichor_lift).angle()
	_ichor.position = d * 10.0 * size

	_sparks.seed = seed_value
	_ichor.seed = seed_value + 101
	_sparks.emitting = spark_amount > 0
	if spark_amount > 0:
		_sparks.restart()
	for n in [_flash, _streak, _ring]:
		n.visible = true
	_update()


func _process(delta: float) -> void:
	if _age > 3.0:
		return
	_age += delta
	if not _ichor_started and _age >= ichor_delay:
		_ichor_started = true
		if ichor_amount > 0:
			_ichor.restart()
	_update()


func _update() -> void:
	var d := hit_dir.normalized()

	var tf := _age / flash_life
	_flash.visible = tf < 1.0
	if _flash.visible:
		# f0 은 작게 터지고 f1 에 최대, 그 뒤로는 크기를 유지한 채 임계값으로 깎인다
		var grow := 0.7 + 0.45 * (1.0 - pow(1.0 - minf(tf * 3.0, 1.0), 3.0))
		_flash_root.scale = Vector2(flash_stretch, 0.85) * grow * size * flash_size / 256.0
		_flash.material.set_shader_parameter("life", tf)

	var ts := _age / streak_life if streak_life > 0.0 else 1.0
	_streak.visible = ts < 1.0
	if _streak.visible:
		# 길이는 계속 늘고 굵기는 줄어든다 (스파크 텍스처 64px 기준)
		_streak.scale = Vector2(streak_width / 64.0 * (1.0 - ts * 0.6),
			streak_length / 64.0 * (1.0 + ts * 0.33)) * size
		_streak.material.set_shader_parameter("life", ts)

	var tr := (_age - ring_delay) / ring_life if ring_life > 0.0 else 1.0
	_ring.visible = tr >= 0.0 and tr < ring_cut      # 끝부분은 머리카락 두께라 끊는다
	if _ring.visible:
		_ring.scale = Vector2.ONE * ring_size / 64.0 * size
		_ring.material.set_shader_parameter("life", tr)
		_ring.position = d * 6.0 * size


func _hide_all() -> void:
	for n in [_flash, _streak, _ring]:
		n.visible = false


func _sprite(tex: Texture2D, shader: Shader) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	var m := ShaderMaterial.new()
	m.shader = shader
	if shader == FIELD_SHADER:
		m.set_shader_parameter("field", tex)
	s.material = m
	add_child(s)
	return s


func _set_params(s: CanvasItem, params: Dictionary) -> void:
	for k in params:
		s.material.set_shader_parameter(k, params[k])


func _field_mat(tex: Texture2D, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FIELD_SHADER
	m.set_shader_parameter("field", tex)
	m.set_shader_parameter("erosion", TEX_EROSION)
	m.set_shader_parameter("use_particle_life", true)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _particles(tex: Texture2D, mat: ShaderMaterial) -> GPUParticles2D:
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.particle_flag_align_y = true
	pm.direction = Vector3(1, 0, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	var p := GPUParticles2D.new()
	p.process_material = pm
	p.texture = tex
	p.material = mat
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.use_fixed_seed = true
	p.local_coords = false
	add_child(p)
	return p
