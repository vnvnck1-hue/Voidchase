## 공허 정수 3D 아이콘: 코드로 만든 다면체 결정(위가 긴 육각 쌍뿔 + 가운데 띠)을 투명 SubViewport 에서
## 천천히 돌리며 렌더하고, 그 ViewportTexture 를 HUD 아이콘·바닥 결정·흡수 연출이 함께 쓴다.
## 만화풍 원화와 어울리게 면은 flat shading, 외곽선은 뒤집힌 껍질(inverted hull)로 그린다.
class_name VDEssenceGem3D
extends SubViewport

const PX := 128                     # 렌더 해상도 (HUD 40px · 바닥 58px 보다 넉넉히)
const SPIN_SEC := 1.6               # Y 축 한 바퀴
const TILT_DEG := 14.0              # 앞으로 살짝 숙여 윗면 깎인 면이 보이게
const BODY := Color(0.46, 0.2, 0.9)
const EMISSION := Color(0.22, 0.05, 0.45)
const OUTLINE := Color(0.09, 0.03, 0.16)
const OUTLINE_GROW := 0.075

var _pivot: Node3D


## host 아래에 하나만 만들어 두고 텍스처를 돌려준다 (렌더하려면 트리 안에 있어야 한다).
static func texture_for(host: Node) -> Texture2D:
	var vp := host.get_node_or_null("EssenceGem3D") as VDEssenceGem3D
	if vp == null:
		vp = VDEssenceGem3D.new()
		vp.name = "EssenceGem3D"
		host.add_child(vp)
	return vp.get_texture()


func _init() -> void:
	size = Vector2i(PX, PX)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_build()


func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.52, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	cam.position = Vector3(0, 0.02, 5)
	add_child(cam)

	var key := DirectionalLight3D.new()           # 왼쪽 위 주광
	key.rotation_degrees = Vector3(-38, -42, 0)
	key.light_energy = 1.35
	key.light_color = Color(1.0, 0.92, 1.0)
	add_child(key)
	var rim := DirectionalLight3D.new()           # 오른쪽 뒤 분홍 테두리광
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(1.0, 0.55, 0.9)
	add_child(rim)

	_pivot = Node3D.new()
	_pivot.rotation_degrees.x = TILT_DEG
	add_child(_pivot)
	var mesh := _crystal_mesh()

	var outline := MeshInstance3D.new()           # 외곽선: 법선 방향으로 부푼 뒷면만 어둡게
	outline.mesh = mesh
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = OUTLINE
	om.cull_mode = BaseMaterial3D.CULL_FRONT
	om.grow = true
	om.grow_amount = OUTLINE_GROW
	outline.material_override = om
	_pivot.add_child(outline)

	var body := MeshInstance3D.new()
	body.mesh = mesh
	var bm := StandardMaterial3D.new()
	bm.albedo_color = BODY
	bm.roughness = 0.28
	bm.metallic = 0.15
	bm.specular_mode = BaseMaterial3D.SPECULAR_TOON
	bm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	bm.emission_enabled = true
	bm.emission = EMISSION
	bm.emission_energy_multiplier = 0.9
	bm.rim_enabled = true
	bm.rim = 0.6
	bm.rim_tint = 0.3
	body.material_override = bm
	_pivot.add_child(body)


## 위가 긴 육각 쌍뿔 + 가운데 육각 띠. 면마다 법선이 따로라 깎인 면이 또렷하다.
static func _crystal_mesh() -> ArrayMesh:
	var top := Vector3(0, 1.0, 0)
	var bottom := Vector3(0, -0.92, 0)
	var up: Array[Vector3] = []
	var down: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		up.append(Vector3(cos(a) * 0.5, 0.3, sin(a) * 0.5))
		down.append(Vector3(cos(a) * 0.5, -0.32, sin(a) * 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)                       # flat shading
	for i in 6:
		var j := (i + 1) % 6
		_tri(st, top, up[j], up[i])
		_tri(st, up[i], up[j], down[j])
		_tri(st, up[i], down[j], down[i])
		_tri(st, bottom, down[i], down[j])
	st.generate_normals()
	return st.commit()


## Godot 앞면은 시계 방향: 바깥에서 볼 때 a→c→b 순서로 넣는다.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _process(delta: float) -> void:
	_pivot.rotation.y = wrapf(_pivot.rotation.y + delta * TAU / SPIN_SEC, 0.0, TAU)
