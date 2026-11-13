## 공허 망령 스킬 [공허 촉수 난타]의 촉수 한 가닥: 본 사슬 + 셰이더.
##   모양·색   shaders/wraith_tentacle.tres (생성형 VisualShader: 굵기 줄어듦·그라데이션·흐르는 밝은 띠·후광·연기)
##   움직임   Skeleton2D 본 사슬(SEGS + 1 마디)에 띠 메시(Polygon2D)를 실었다. 매 프레임 뿌리 → 대상으로 가는 S 곡선을 잡고
##            본을 그 곡선에 맞춰 돌리고 늘인다 (마디 위치 = 곡선 위의 점, 마디 회전 = 곡선의 방향). 곡선 위로 물결이 끝 쪽으로 흘러간다.
##   순서     (delay) → 펼치기: 옆으로 크게 휘둘러 부채꼴로 펼친다 → 찌름(on_hit) → 잠깐 버팀
##            → 반대쪽으로 크게 휘둘러 당김 → 다시 찌름 … jabs 번 → 거둬들이며 사라짐.
##   끝 자취   끝이 지나간 길에 밝은 연보라 띠(더하기)가 남아 휘두르는 궤적이 보인다.
## 좌표는 전부 부모 노드 기준. root_fn·target_fn 이 매 프레임 뿌리·대상 위치를 돌려주므로 시전자나 대상이 움직여도 따라간다.
class_name VDWraithTentacle
extends Node2D

const SEGS := 22
const HALF_W := 50.0            # 띠 반폭 (px, 후광 포함)
const BODY_W := 0.56            # 그중 몸통 비율 (뿌리)
const FAN_SEC := 0.3           # 처음 옆으로 펼치는 시간
const OUT_SEC := 0.085          # 찌르는 시간
const HOLD_SEC := 0.05
const BACK_SEC := 0.17          # 반대쪽으로 휘둘러 당기는 시간
const END_SEC := 0.24
const RECOIL := 0.5             # 당겼을 때 길이 (대상까지의 비율)
const FAN_EXT := 0.72           # 펼쳤을 때 길이
const SWING := 1.0             # 휘두를 때 끝이 옆으로 벗어나는 폭 (대상까지 거리의 비율)
const TRAIL_POINTS := 16
const CRACK := 0.2              # 채찍 물결의 높이 (대상까지 거리의 비율): 휘두를 때 뿌리에서 끝으로 굽이가 달려 나간다
const SHADER := preload("res://shaders/wraith_tentacle.tres")

var root_fn: Callable           # () -> Vector2
var target_fn: Callable         # () -> Vector2
var alive_fn: Callable          # () -> bool: false 면 바로 거둬들인다
var on_hit: Callable            # (tip: Vector2, last: bool)
var delay := 0.0
var jabs := 3
var launch := 0.0               # 뿌리에서 나가는 방향을 대상 쪽에서 이만큼 틀어 준다 (rad): 부채꼴로 퍼졌다가 모인다
var side := 1.0                 # 곡선이 휘는 쪽 (+1 / -1). 찌를 때마다 뒤집혀 좌우로 번갈아 휘두른다

var _bones: Array[Bone2D] = []
var _mat: ShaderMaterial
var _trail: Line2D
var _phase := "wait"
var _t := 0.0
var _clock := 0.0
var _jab := 0
var _ext := 0.0                 # 지금 길이 (0 뿌리 ~ 1 대상에 닿음)
var _from := 0.0                # 이번 구간이 시작한 길이
var _swing := 0.0               # 끝이 옆으로 벗어난 정도 (0 곧게 ~ 1)
var _swing_from := 0.0
var _crack := 2.0               # 채찍 물결이 지금 지나는 자리 (0 뿌리 ~ 1 끝, 그 밖이면 없음)
var _crack_k := 0.0             # 그 물결의 세기와 방향
var _flash := 0.0
var _jitter := Vector2.ZERO     # 찌를 때마다 조금씩 다른 곳
var _bulge := 0.3
var _seed := 0.0
var _last_tip := Vector2.ZERO
static var _white: ImageTexture


func _ready() -> void:
	_seed = randf() * 10.0
	_build()
	_roll()
	visible = false


## 본 사슬과 띠 메시. 기본 자세는 +x 로 곧게 뻗은 띠: 마디 i 는 (i × 1, 0), 단면 i 는 마디 i 에 그대로 붙는다.
func _build() -> void:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)   # UV 를 0..1 그대로 넘기려는 1px 텍스처
	# 끝 자취 (몸통 뒤)
	_trail = Line2D.new()
	_trail.width = 20.0
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.0))
	wc.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = wc
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.6, 0.25, 1.0, 0.0), Color(0.75, 0.4, 1.0, 0.5), Color(1.0, 0.85, 1.0, 0.95)])
	_trail.gradient = grad
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.material = VDVfx.add_material()
	add_child(_trail)
	var skel := Skeleton2D.new()
	skel.name = "Skeleton"
	add_child(skel)
	var parent: Node = skel
	var path := ""
	var poly := Polygon2D.new()
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var paths: Array[String] = []
	for i in SEGS + 1:
		var bone := Bone2D.new()
		bone.name = "b%d" % i
		bone.position = Vector2(1.0 if i > 0 else 0.0, 0.0)
		bone.rest = Transform2D(0.0, bone.position)
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(1.0)
		parent.add_child(bone)
		parent = bone
		path = bone.name if path == "" else path + "/" + bone.name
		paths.append(path)
		_bones.append(bone)
		var u := float(i) / SEGS
		verts.append(Vector2(i, -HALF_W))
		verts.append(Vector2(i, HALF_W))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
	var polys := []
	for i in SEGS:
		var a := i * 2
		polys.append(PackedInt32Array([a, a + 1, a + 3]))
		polys.append(PackedInt32Array([a, a + 3, a + 2]))
	poly.texture = _white
	poly.polygon = verts
	poly.uv = uvs
	poly.polygons = polys
	poly.skeleton = NodePath("../Skeleton")
	for i in SEGS + 1:
		var w := PackedFloat32Array()
		w.resize(verts.size())
		w[i * 2] = 1.0
		w[i * 2 + 1] = 1.0
		poly.add_bone(NodePath(paths[i]), w)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", _seed)
	# 전투 화면에서 묻히지 않게 컨셉보다 조금 밝고 후광을 넓게
	_mat.set_shader_parameter("glow_w", 0.22)
	_mat.set_shader_parameter("glow_i", 1.7)
	_mat.set_shader_parameter("col_mid", Color(0.46, 0.2, 0.86))
	_mat.set_shader_parameter("col_sheen", Color(0.82, 0.5, 1.0))
	poly.material = _mat
	add_child(poly)


func _roll() -> void:
	_jitter = Vector2(randf_range(-18.0, 18.0), randf_range(-22.0, 14.0))
	_bulge = randf_range(0.3, 0.65)


func _process(delta: float) -> void:
	_clock += delta
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_crack += delta * (9.0 if _phase == "out" else 5.5)   # 물결이 끝까지 달려 나가는 속도
	if _phase != "end" and alive_fn.is_valid() and not alive_fn.call():
		_go("end")
	match _phase:
		"wait":
			if _t >= delay:
				visible = true
				_go("fan")
		"fan":
			# 옆으로 크게 휘두르며 펼친다
			var k := clampf(_t / FAN_SEC, 0.0, 1.0)
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			_ext = lerpf(_from, FAN_EXT, e)
			_swing = lerpf(_swing_from, 1.0, e)
			if k >= 1.0:
				_go("out")
		"out":
			var k := clampf(_t / OUT_SEC, 0.0, 1.0)
			_ext = lerpf(_from, 1.0, k * k * k)              # 뒤로 갈수록 빨라져 꽂힌다
			_swing = lerpf(_swing_from, 0.0, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_flash = 1.0
				_go("hold")
				if on_hit.is_valid():
					on_hit.call(_tip(), _jab == jabs - 1)
		"hold":
			if _t >= HOLD_SEC:
				if _jab + 1 < jabs:
					side = -side                              # 다음엔 반대쪽으로 휘두른다
					_go("back")
				else:
					_go("end")
		"back":
			var k := clampf(_t / BACK_SEC, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			_ext = lerpf(_from, RECOIL, e)
			# 반대쪽으로 크게 넘어갔다가 살짝 되돌아온다 (채찍을 되감는 탄성)
			_swing = lerpf(_swing_from, 1.0, e) + 0.28 * sin(k * PI) * (1.0 - _swing_from)
			if k >= 1.0:
				_jab += 1
				_roll()
				_go("out")
		"end":
			var k := clampf(_t / END_SEC, 0.0, 1.0)
			_ext = lerpf(_from, 0.0, k * k)
			_swing = lerpf(_swing_from, 0.5, k)
			_mat.set_shader_parameter("alpha_k", 1.0 - k * k)
			_trail.modulate.a = 1.0 - k
			if k >= 1.0:
				queue_free()
				return
	_pose()


func _go(phase: String) -> void:
	_phase = phase
	_t = 0.0
	_from = _ext
	_swing_from = _swing
	# 휘두르기 시작할 때마다 뿌리에서 채찍 물결을 하나 쏜다 (찌를 땐 크게, 당길 땐 반대쪽으로)
	match phase:
		"fan":
			_crack = -0.2
			_crack_k = 0.8 * side
		"out":
			_crack = -0.15
			_crack_k = -1.0 * side
		"back":
			_crack = -0.2
			_crack_k = 0.9 * side


func _tip() -> Vector2:
	return _last_tip


## 본을 곡선에 맞춘다.
func _pose() -> void:
	if not root_fn.is_valid() or not target_fn.is_valid():
		return
	var r: Vector2 = root_fn.call()
	var aim: Vector2 = (target_fn.call() as Vector2) + _jitter
	var full := aim - r
	var length := maxf(full.length(), 1.0)
	var dir := full / length
	var perp := Vector2(-dir.y, dir.x)
	# 끝: 휘두를 땐 옆으로 크게 벗어나 있다가, 찌를 땐 곧게 꽂힌다
	var tip := r.lerp(aim, _ext) + perp * side * _swing * SWING * length * (0.35 + 0.65 * _ext)
	# 뿌리에서는 부채꼴로 퍼져 나가고(launch), 대상에는 반대쪽으로 휘어 들어간다 → S 곡선
	var p1 := r + dir.rotated(launch) * length * 0.58 * (0.4 + 0.6 * _ext)
	var p2 := tip - dir.rotated(-launch * 0.45) * length * 0.3 * _ext + perp * side * (_bulge + 0.5 * _swing) * length * 0.32
	var pts := PackedVector2Array()
	pts.resize(SEGS + 1)
	var loose := 0.3 + 0.7 * (1.0 - _ext)          # 당겼을 때 더 크게 꿈틀거린다
	for i in SEGS + 1:
		var s := float(i) / SEGS
		var q := 1.0 - s
		var p := q * q * q * r + 3.0 * q * q * s * p1 + 3.0 * q * s * s * p2 + s * s * s * tip
		# 끝 쪽으로 흘러가는 물결 (뿌리와 끝은 고정)
		p += perp * sin(s * 8.0 - _clock * 30.0 + _seed) * 9.0 * loose * s * q * 4.0
		# 채찍 물결: 뿌리에서 끝으로 달려 나가는 큰 굽이 하나 (끝으로 갈수록 커진다 — 채찍 끝이 가장 크게 튄다)
		var cd := (s - _crack) / 0.2
		p += perp * _crack_k * CRACK * length * exp(-cd * cd) * (0.35 + 0.65 * s) * minf(s * 6.0, 1.0)
		pts[i] = p
	# 마디 i: 위치 = 곡선 위의 점(부모 x 축 위로 마디 간격만큼), 회전 = 다음 점으로 가는 방향 (부모 회전과의 차)
	var prev_rot := 0.0
	for i in SEGS + 1:
		var b := _bones[i]
		var rot := (pts[i + 1] - pts[i]).angle() if i < SEGS else prev_rot
		if i == 0:
			b.position = pts[0]
			b.rotation = rot
		else:
			b.position = Vector2(pts[i].distance_to(pts[i - 1]), 0.0)
			b.rotation = angle_difference(prev_rot, rot)
		prev_rot = rot
	_last_tip = pts[SEGS]
	# 끝 자취: 끝에서 조금 안쪽 점이 지나간 길
	if visible:
		_trail.add_point(pts[SEGS - 1])
		while _trail.get_point_count() > TRAIL_POINTS:
			_trail.remove_point(0)
	_mat.set_shader_parameter("body_w", BODY_W * (0.45 + 0.55 * clampf(_ext * 1.3, 0.0, 1.0)))
	_mat.set_shader_parameter("flash", _flash)
