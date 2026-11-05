## CPU re-implementation of the Unity ParticleSystem subset used by the ported scenes
## (Epic Toon FX style 2D effects). The whole Unity component is stored in `config`
## (exported straight from Unity by the port tool) and interpreted here, so the
## behaviour (bursts, random-between-two-constants, curves, gradients, texture sheet
## frames, world/local simulation space, trails, Stop()/Play() semantics) matches.
##
## Internal simulation works in Unity space (metres, y-up, CCW rotation) and is
## converted to Godot pixels (1 unit = 100 px, y-down) when drawing.
class_name UnityParticles2D
extends Node2D

const PX := 100.0
const UNITY_GRAVITY := -9.81

@export var config: Dictionary = {}
@export var texture: Texture2D
@export var trail_texture: Texture2D
@export var renderer_enabled: bool = true

var playing := false
var emitting := false
var _time := 0.0            # playback time inside the current cycle (seconds, after startDelay)
var _total_time := 0.0
var _delay_left := 0.0
var _emit_accum := 0.0
var _burst_next_cycle: Array = []
var _cycle_index := 0
var _particles: Array = []  # Array of Dictionary
var _rng := RandomNumberGenerator.new()
var _noise: FastNoiseLite
var _trail_node: Node2D
var _tile_x := 1
var _tile_y := 1

# cached config
var _main: Dictionary
var _emission: Dictionary
var _shape: Dictionary
var _vol: Dictionary
var _lim: Dictionary
var _fol: Dictionary
var _col: Dictionary
var _sol: Dictionary
var _rol: Dictionary
var _noise_m: Dictionary
var _tsa: Dictionary
var _trails: Dictionary
var _render: Dictionary
var _duration := 5.0
var _loop := true
var _sim_world := false
var _speed := 1.0
var _loaded := false


func _ready() -> void:
	_rng.randomize()
	_load_config()
	if _main.get("playOnAwake", false) and _main.get("_activeInHierarchy", true):
		play(false)


func _load_config() -> void:
	if _loaded or config.is_empty():
		return
	_loaded = true
	_main = config.get("main", {})
	_emission = config.get("emission", {})
	_shape = config.get("shape", {})
	_vol = config.get("velocityOverLifetime", {})
	_lim = config.get("limitVelocityOverLifetime", {})
	_fol = config.get("forceOverLifetime", {})
	_col = config.get("colorOverLifetime", {})
	_sol = config.get("sizeOverLifetime", {})
	_rol = config.get("rotationOverLifetime", {})
	_noise_m = config.get("noise", {})
	_tsa = config.get("textureSheetAnimation", {})
	_trails = config.get("trails", {})
	_render = config.get("renderer", {})
	_duration = float(_main.get("duration", 5.0))
	_loop = bool(_main.get("loop", true))
	_sim_world = String(_main.get("simulationSpace", "Local")) == "World"
	_speed = float(_main.get("simulationSpeed", 1.0))
	if _tsa.get("enabled", false):
		_tile_x = max(1, int(_tsa.get("numTilesX", 1)))
		_tile_y = max(1, int(_tsa.get("numTilesY", 1)))
	if _noise_m.get("enabled", false):
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_noise.frequency = 1.0
		_noise.seed = _rng.randi()
	if _trails.get("enabled", false):
		_trail_node = Node2D.new()
		_trail_node.name = "_trails"
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = _blend_mode_for(String(_render.get("trailBlend", _render.get("blend", "mix"))))
		_trail_node.material = mat
		_trail_node.z_index = z_index
		_trail_node.z_as_relative = z_as_relative
		_trail_node.draw.connect(_draw_trails)
		add_child(_trail_node)
	if texture == null and _render.has("texture"):
		texture = load(String(_render["texture"]))
	if trail_texture == null and _render.has("trailTexture"):
		trail_texture = load(String(_render["trailTexture"]))
	if material == null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = _blend_mode_for(String(_render.get("blend", "mix")))
		material = m


static func _blend_mode_for(b: String) -> CanvasItemMaterial.BlendMode:
	match b:
		"add": return CanvasItemMaterial.BLEND_MODE_ADD
		"premul": return CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		_: return CanvasItemMaterial.BLEND_MODE_MIX


# ---------------------------------------------------------------- public API (Unity-like)

## ParticleSystem.Play(withChildren = true)
func play(with_children: bool = true) -> void:
	_load_config()
	if not playing or not emitting:
		# stopped (or emission stopped) -> restart from time 0 with start delay
		_time = 0.0
		_cycle_index = 0
		_emit_accum = 0.0
		_delay_left = _eval_mm(_main.get("startDelay", {}), 0.0, _rng.randf())
		_reset_bursts()
		playing = true
		emitting = true
		if _main.get("prewarm", false) and _loop:
			_prewarm()
	if with_children:
		for c in get_children():
			if c is UnityParticles2D:
				c.play(true)


## ParticleSystem.Stop(withChildren = true, StopEmitting)
func stop(with_children: bool = true) -> void:
	emitting = false
	if with_children:
		for c in get_children():
			if c is UnityParticles2D:
				c.stop(true)


func clear() -> void:
	_particles.clear()
	queue_redraw()


func is_alive() -> bool:
	return emitting or not _particles.is_empty()


func _prewarm() -> void:
	var saved_delay := _delay_left
	_delay_left = 0.0
	var steps := int(ceil(_duration * 30.0))
	var dt := _duration / steps
	for i in steps:
		_step(dt)
	_delay_left = saved_delay


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	if not _loaded:
		return
	var dt := delta * _speed
	if _main.get("useUnscaledTime", false) and Engine.time_scale > 0.0:
		dt = delta / Engine.time_scale * _speed
	if not playing and _particles.is_empty():
		return
	_step(dt)
	queue_redraw()
	if _trail_node != null:
		_trail_node.queue_redraw()


func _step(dt: float) -> void:
	if dt <= 0.0:
		return
	_total_time += dt
	# emission timeline
	if playing and emitting:
		if _delay_left > 0.0:
			var d := minf(_delay_left, dt)
			_delay_left -= d
			dt_emit_and_update(dt - d, dt)
			return
		_emit_over(dt)
	_update_particles(dt)


func dt_emit_and_update(emit_dt: float, full_dt: float) -> void:
	if emit_dt > 0.0:
		_emit_over(emit_dt)
	_update_particles(full_dt)


func _emit_over(dt: float) -> void:
	var t0 := _time
	var t1 := _time + dt
	var max_particles := int(_main.get("maxParticles", 1000))
	if _emission.get("enabled", false):
		# rate over time (evaluated at normalized time of the cycle)
		var rate_mm: Dictionary = _emission.get("rateOverTime", {})
		var rate := _eval_mm(rate_mm, clampf(t0 / _duration, 0.0, 1.0), _rng.randf())
		if rate > 0.0:
			_emit_accum += rate * dt
			while _emit_accum >= 1.0:
				_emit_accum -= 1.0
				if _particles.size() < max_particles:
					_emit_one(t1)
		# bursts
		for b in _burst_next_cycle:
			var bt: float = float(b["time"])
			while b["remaining"] != 0 and bt + b["fired"] * float(b["interval"]) >= t0 and bt + b["fired"] * float(b["interval"]) < t1:
				if _rng.randf() <= float(b.get("probability", 1.0)):
					var count := int(round(_eval_mm(b["count"], clampf(t0 / _duration, 0.0, 1.0), _rng.randf())))
					for i in count:
						if _particles.size() < max_particles:
							_emit_one(t1)
				b["fired"] += 1
				if b["remaining"] > 0:
					b["remaining"] -= 1
	_time = t1
	if _time >= _duration:
		if _loop:
			_time -= _duration
			_cycle_index += 1
			_reset_bursts()
		else:
			# finished one cycle: stop emitting (particles die out)
			emitting = false
			playing = not _particles.is_empty()
			_time = _duration


func _reset_bursts() -> void:
	_burst_next_cycle.clear()
	for b in _emission.get("bursts", []):
		var cycles := int(b.get("cycleCount", 1))
		_burst_next_cycle.append({
			"time": float(b.get("time", 0.0)),
			"count": b.get("count", {}),
			"remaining": cycles if cycles > 0 else -1,
			"interval": maxf(float(b.get("repeatInterval", 0.01)), 0.001),
			"probability": float(b.get("probability", 1.0)),
			"fired": 0,
		})


# Node's transform in Unity space (metres, y-up, CCW angle).
func _unity_xform() -> Dictionary:
	var g := global_transform
	var pos := Vector2(g.origin.x / PX, -g.origin.y / PX)
	var rot := -g.get_rotation()
	var scl := g.get_scale()
	return {"pos": pos, "rot": rot, "scale": scl}


func _size_scale() -> Vector2:
	var mode := String(_main.get("scalingMode", "Local"))
	if mode == "Hierarchy":
		return global_transform.get_scale()
	elif mode == "Shape":
		return Vector2.ONE
	return scale


func _shape_scale() -> Vector2:
	var mode := String(_main.get("scalingMode", "Local"))
	if mode == "Local":
		return scale
	return global_transform.get_scale()


func _emit_one(emit_time: float) -> void:
	var nt := clampf(_time / _duration, 0.0, 1.0)
	var u := _rng.randf()  # per-particle random factor shared by the start values
	var p := {}
	var life := _eval_mm(_main.get("startLifetime", {}), nt, _rng.randf())
	if life <= 0.0:
		return
	p["life"] = life
	p["age"] = 0.0
	p["seed"] = u
	p["seed_col"] = _rng.randf()
	p["seed_size"] = _rng.randf()
	p["seed_vel"] = _rng.randf()
	p["seed_rot"] = _rng.randf()
	p["seed_frame"] = _rng.randf()
	var speed := _eval_mm(_main.get("startSpeed", {}), nt, _rng.randf())
	var size := _eval_mm(_main.get("startSize", {}), nt, p["seed_size"])
	var size_x := size
	var size_y := size
	if _main.get("startSize3D", false):
		size_x = _eval_mm(_main.get("startSizeX", {}), nt, p["seed_size"])
		size_y = _eval_mm(_main.get("startSizeY", {}), nt, p["seed_size"])
	p["size0"] = Vector2(size_x, size_y)
	var rot := _eval_mm(_main.get("startRotation", {}), nt, _rng.randf())  # radians
	if _main.get("flipRotation", 0.0) > 0.0 and _rng.randf() < float(_main.get("flipRotation", 0.0)):
		rot = -rot
	p["rot"] = rot
	p["color0"] = _eval_mmg(_main.get("startColor", {}), nt, p["seed_col"])
	p["ang_vel"] = 0.0
	if _rol.get("enabled", false):
		p["ang_vel"] = _eval_mm(_rol.get("z", {}), 0.0, p["seed_rot"])

	# shape -> local position + direction (Unity local space, metres, y-up)
	var pd := _sample_shape(emit_time)
	var local_pos: Vector2 = pd["pos"]
	var dir: Vector2 = pd["dir"]
	var shape_scale := _shape_scale()
	local_pos = Vector2(local_pos.x * shape_scale.x, local_pos.y * shape_scale.y)
	var vel := dir * speed
	var xf := _unity_xform()
	if _sim_world:
		p["pos"] = xf["pos"] + local_pos.rotated(xf["rot"])
		p["vel"] = vel.rotated(xf["rot"])
	else:
		p["pos"] = local_pos
		p["vel"] = vel
	p["trail"] = []
	p["trail_life"] = _eval_mm(_trails.get("lifetime", {}), 0.0, _rng.randf()) if _trails.get("enabled", false) else 0.0
	_particles.append(p)


func _sample_shape(emit_time: float) -> Dictionary:
	var pos := Vector2.ZERO
	var dir := Vector2.UP
	if not _shape.get("enabled", false):
		return {"pos": pos, "dir": Vector2(0, 0)}  # Unity: no shape -> emit from origin, direction +Z (invisible in 2D)
	var stype := String(_shape.get("shapeType", "Circle"))
	var radius := float(_shape.get("radius", 1.0))
	var thickness := float(_shape.get("radiusThickness", 1.0))
	match stype:
		"Circle":
			var arc := deg_to_rad(float(_shape.get("arc", 360.0)))
			var a := 0.0
			if String(_shape.get("arcMode", "Random")) == "Random":
				a = _rng.randf() * arc
			else:
				# Loop / PingPong / BurstSpread: sweep with arcSpeed (default 1 cycle/s)
				var arc_speed := float(_shape.get("arcSpeed", 1.0))
				var f := fposmod(emit_time * arc_speed, 1.0)
				if String(_shape.get("arcMode", "Random")) == "PingPong":
					f = pingpong(emit_time * arc_speed, 1.0)
				a = f * arc
			var inner := 1.0 - thickness
			var r := radius * sqrt(lerpf(inner * inner, 1.0, _rng.randf()))
			dir = Vector2(cos(a), sin(a))
			pos = dir * r
		"SingleSidedEdge":
			pos = Vector2(lerpf(-radius, radius, _rng.randf()), 0.0)
			dir = Vector2(0, 1)
		"Sphere", "SphereShell", "Hemisphere", "HemisphereShell":
			var a := _rng.randf() * TAU
			var inner := 1.0 - thickness
			var r := radius * pow(lerpf(inner * inner * inner, 1.0, _rng.randf()), 1.0 / 3.0)
			dir = Vector2(cos(a), sin(a))
			pos = dir * r
		"Box", "BoxShell", "BoxEdge", "Rectangle":
			var s: Array = _shape.get("scale", [1, 1, 1])
			pos = Vector2((_rng.randf() - 0.5) * float(s[0]), (_rng.randf() - 0.5) * float(s[1]))
			dir = Vector2(0, 0)
		_:
			# Cone etc. emit along +Z in Unity: no in-plane direction.
			var a := _rng.randf() * TAU
			pos = Vector2(cos(a), sin(a)) * radius * sqrt(_rng.randf())
			dir = Vector2(0, 0)
	var rnd_dir := float(_shape.get("randomDirectionAmount", 0.0))
	if rnd_dir > 0.0:
		var a := _rng.randf() * TAU
		dir = dir.lerp(Vector2(cos(a), sin(a)), rnd_dir).normalized() if dir.length() > 0 else Vector2(cos(a), sin(a))
	# shape transform (position / rotation.z / scale)
	var sp: Array = _shape.get("position", [0, 0, 0])
	var srot: Array = _shape.get("rotation", [0, 0, 0])
	var sscl: Array = _shape.get("scale", [1, 1, 1])
	if stype != "Box" and stype != "Rectangle":
		pos = Vector2(pos.x * float(sscl[0]), pos.y * float(sscl[1]))
	var rz := deg_to_rad(float(srot[2]))
	pos = pos.rotated(rz) + Vector2(float(sp[0]), float(sp[1]))
	dir = dir.rotated(rz)
	return {"pos": pos, "dir": dir}


func _update_particles(dt: float) -> void:
	var xf := _unity_xform()
	var gravity := Vector2(0, UNITY_GRAVITY) * _eval_mm(_main.get("gravityModifier", {}), clampf(_time / _duration, 0, 1), 0.5)
	var vol_on: bool = _vol.get("enabled", false)
	var vol_local := String(_vol.get("space", "Local")) == "Local"
	var lim_on: bool = _lim.get("enabled", false)
	var fol_on: bool = _fol.get("enabled", false)
	var noise_on: bool = _noise_m.get("enabled", false) and _noise != null
	var trails_on: bool = _trails.get("enabled", false)
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p["age"] += dt
		if p["age"] >= p["life"]:
			if trails_on and not bool(_trails.get("dieWithParticles", true)) and p["trail"].size() > 1:
				p["dead"] = true
				_update_trail(p, dt, true)
				if p["trail"].is_empty():
					_particles.remove_at(i)
					continue
				i += 1
				continue
			_particles.remove_at(i)
			continue
		var u: float = p["age"] / p["life"]
		var vel: Vector2 = p["vel"]
		# gravity + force over lifetime (acceleration)
		vel += gravity * dt
		if fol_on:
			var f := Vector2(_eval_mm(_fol.get("x", {}), u, p["seed_vel"]), _eval_mm(_fol.get("y", {}), u, p["seed_vel"]))
			if String(_fol.get("space", "Local")) == "Local" and _sim_world:
				f = f.rotated(xf["rot"])
			vel += f * dt
		var total_vel := vel
		# velocity over lifetime (additive velocity, orbital, radial, speed modifier)
		if vol_on:
			var extra := Vector2(_eval_mm(_vol.get("x", {}), u, p["seed_vel"]), _eval_mm(_vol.get("y", {}), u, p["seed_vel"]))
			if vol_local and _sim_world:
				extra = extra.rotated(xf["rot"])
			var center: Vector2 = xf["pos"] if _sim_world else Vector2.ZERO
			var rel: Vector2 = p["pos"] - center
			var orbital_z := _eval_mm(_vol.get("orbitalZ", {}), u, p["seed_vel"])
			if absf(orbital_z) > 0.0 and rel.length() > 0.0001:
				# Unity orbital velocity around the Z axis (rad/s)
				extra += Vector2(-rel.y, rel.x) * orbital_z
			var radial := _eval_mm(_vol.get("radial", {}), u, p["seed_vel"])
			if absf(radial) > 0.0 and rel.length() > 0.0001:
				extra += rel.normalized() * radial
			total_vel = (vel + extra) * _eval_mm(_vol.get("speedModifier", {}), u, p["seed_vel"])
		# limit velocity over lifetime
		if lim_on:
			var limit := _eval_mm(_lim.get("limit", {}), u, p["seed_vel"]) * _size_scale().x
			var dampen := float(_lim.get("dampen", 0.0))
			var spd := total_vel.length()
			if spd > limit and limit >= 0.0 and spd > 0.0:
				var new_spd := lerpf(spd, limit, dampen)
				var k := new_spd / spd
				total_vel *= k
				vel *= k
			var drag := _eval_mm(_lim.get("drag", {}), u, p["seed_vel"])
			if drag > 0.0:
				var dk := drag
				if bool(_lim.get("multiplyDragByParticleSize", true)):
					dk *= maxf(p["size0"].x, 0.0001)
				if bool(_lim.get("multiplyDragByParticleVelocity", true)):
					dk *= total_vel.length()
				var damp := clampf(1.0 - dk * dt, 0.0, 1.0)
				vel *= damp
				total_vel *= damp
		# noise (position noise field)
		if noise_on:
			var strength := _eval_mm(_noise_m.get("strength", {}), u, p["seed_vel"]) * _eval_mm(_noise_m.get("positionAmount", {}), u, 0.5)
			var freq := float(_noise_m.get("frequency", 0.5))
			if bool(_noise_m.get("damping", true)):
				strength *= freq
			var sp: Vector2 = p["pos"]
			var nx := _noise.get_noise_3d(sp.x * freq * 10.0, sp.y * freq * 10.0, _total_time * 10.0 + p["seed"] * 100.0)
			var ny := _noise.get_noise_3d(sp.x * freq * 10.0 + 37.1, sp.y * freq * 10.0 - 11.3, _total_time * 10.0 + p["seed"] * 100.0 + 50.0)
			total_vel += Vector2(nx, ny) * strength
		p["vel"] = vel
		p["pos"] += total_vel * dt
		p["cur_vel"] = total_vel
		p["rot"] += float(p["ang_vel"]) * dt
		if trails_on:
			_update_trail(p, dt, false)
		i += 1


func _update_trail(p: Dictionary, dt: float, dead: bool) -> void:
	var tr: Array = p["trail"]
	var min_dist := float(_trails.get("minVertexDistance", 0.2)) * _size_scale().x
	var life := float(p["trail_life"])
	if bool(_trails.get("sizeAffectsLifetime", false)):
		life *= float(p["size0"].x)
	var now := _total_time
	if not dead:
		var pos: Vector2 = p["pos"]
		if tr.is_empty() or (tr[tr.size() - 1]["pos"] as Vector2).distance_to(pos) >= min_dist:
			tr.append({"pos": pos, "t": now})
		else:
			tr[tr.size() - 1]["pos"] = pos
			tr[tr.size() - 1]["t"] = now
	# remove expired points
	while tr.size() > 0 and now - float(tr[0]["t"]) > life:
		tr.remove_at(0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not renderer_enabled or _particles.is_empty() or texture == null:
		return
	var inv := global_transform.affine_inverse()
	var g := global_transform
	var gscale := g.get_scale()
	var size_scale := _size_scale()
	var render_mode := String(_render.get("renderMode", "Billboard"))
	var length_scale := float(_render.get("lengthScale", 2.0))
	var velocity_scale := float(_render.get("velocityScale", 0.0))
	var pivot_arr: Array = _render.get("pivot", [0, 0, 0])
	var pivot := Vector2(float(pivot_arr[0]), float(pivot_arr[1]))
	var tex_size := texture.get_size()
	var tile_w := tex_size.x / _tile_x
	var tile_h := tex_size.y / _tile_y
	var tsa_on: bool = _tsa.get("enabled", false)
	var col_on: bool = _col.get("enabled", false)
	var sol_on: bool = _sol.get("enabled", false)
	for p in _particles:
		if p.get("dead", false):
			continue
		var u: float = p["age"] / p["life"]
		# color
		var c: Color = p["color0"]
		if col_on:
			c = c * _eval_mmg(_col.get("color", {}), u, p["seed_col"])
		# size (metres)
		var sz: Vector2 = p["size0"]
		if sol_on:
			if bool(_sol.get("separateAxes", false)):
				sz = Vector2(sz.x * _eval_mm(_sol.get("x", {}), u, p["seed_size"]), sz.y * _eval_mm(_sol.get("y", {}), u, p["seed_size"]))
			else:
				sz *= _eval_mm(_sol.get("size", {}), u, p["seed_size"])
		sz = Vector2(sz.x * size_scale.x, sz.y * size_scale.y)
		# texture sheet frame
		var region := Rect2(Vector2.ZERO, tex_size)
		if tsa_on:
			var frame := _frame_index(p, u)
			var col_i := frame % _tile_x
			var row_i := int(frame / _tile_x) % _tile_y
			region = Rect2(col_i * tile_w, row_i * tile_h, tile_w, tile_h)
		# transform in Godot space
		var pos_u: Vector2 = p["pos"]
		var rot_u: float = p["rot"]
		var xform: Transform2D
		var quad_size := Vector2(sz.x, sz.y) * PX
		if render_mode == "Stretch":
			var v: Vector2 = p.get("cur_vel", p["vel"])
			var spd := v.length()
			var len_m := sz.x * length_scale + spd * velocity_scale
			quad_size = Vector2(len_m, sz.y) * PX
			if spd > 0.0001:
				rot_u = v.angle()
			# Unity stretched billboards point their +X along velocity and are centred behind the head
		if _sim_world:
			var gp := Vector2(pos_u.x * PX, -pos_u.y * PX)
			xform = inv * Transform2D(-rot_u, gp)
		else:
			xform = Transform2D(-rot_u, Vector2(pos_u.x * PX, -pos_u.y * PX))
			# compensate node scale so particle size is in world pixels
			quad_size = Vector2(quad_size.x / maxf(gscale.x, 0.0001), quad_size.y / maxf(gscale.y, 0.0001))
			if _sim_world == false and String(_main.get("scalingMode", "Local")) != "Local":
				pass
		xform = xform.scaled_local(quad_size)
		draw_set_transform_matrix(xform)
		var rect := Rect2(-0.5 - pivot.x, -0.5 + pivot.y, 1.0, 1.0)
		draw_texture_rect_region(texture, rect, region, c)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _frame_index(p: Dictionary, u: float) -> int:
	var total := _tile_x * _tile_y
	var start := _eval_mm(_tsa.get("startFrame", {}), 0.0, p["seed_frame"])
	var fot := _eval_mm(_tsa.get("frameOverTime", {}), u, p["seed_frame"])
	var cycles := float(_tsa.get("cycleCount", 1))
	var f := (start + fot * cycles) * total
	var idx := int(floor(f)) % total
	if idx < 0:
		idx += total
	return idx


func _draw_trails() -> void:
	if _trail_node == null or trail_texture == null:
		return
	var inv := global_transform.affine_inverse()
	var size_scale := _size_scale()
	var width_mm: Dictionary = _trails.get("widthOverTrail", {})
	var col_trail: Dictionary = _trails.get("colorOverTrail", {})
	var col_life: Dictionary = _trails.get("colorOverLifetime", {})
	var inherit: bool = _trails.get("inheritParticleColor", true)
	var size_affects_width: bool = _trails.get("sizeAffectsWidth", true)
	var stretch := String(_trails.get("textureMode", "Stretch")) == "Stretch"
	var rid := _trail_node.get_canvas_item()
	for p in _particles:
		var tr: Array = p["trail"]
		if tr.size() < 2:
			continue
		var u: float = clampf(p["age"] / p["life"], 0.0, 1.0)
		var base_col := Color.WHITE
		if inherit:
			base_col = p["color0"]
			if _col.get("enabled", false):
				base_col = base_col * _eval_mmg(_col.get("color", {}), u, p["seed_col"])
		base_col = base_col * _eval_mmg(col_life, u, p["seed_col"])
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var n := tr.size()
		var total_len := 0.0
		for k in range(1, n):
			total_len += (tr[k]["pos"] as Vector2).distance_to(tr[k - 1]["pos"])
		var acc := 0.0
		for k in n:
			var pos_u: Vector2 = tr[k]["pos"]
			if k > 0:
				acc += pos_u.distance_to(tr[k - 1]["pos"])
			var t_along := 1.0 - (acc / total_len if total_len > 0 else 0.0)  # 0 at head (newest), 1 at tail
			var tangent: Vector2
			if k < n - 1:
				tangent = (tr[k + 1]["pos"] as Vector2) - pos_u
			else:
				tangent = pos_u - (tr[k - 1]["pos"] as Vector2)
			if tangent.length() < 0.00001:
				tangent = Vector2.RIGHT
			tangent = tangent.normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var w := _eval_mm(width_mm, t_along, p["seed_size"])
			if size_affects_width:
				w *= float(p["size0"].x)
			w *= size_scale.x
			var c := base_col * _eval_mmg(col_trail, t_along, p["seed_col"])
			var a := pos_u + normal * w * 0.5
			var b := pos_u - normal * w * 0.5
			pts.append(inv * Vector2(a.x * PX, -a.y * PX))
			pts.append(inv * Vector2(b.x * PX, -b.y * PX))
			cols.append(c)
			cols.append(c)
			var uu := t_along if stretch else acc
			uvs.append(Vector2(uu, 0.0))
			uvs.append(Vector2(uu, 1.0))
			if k > 0:
				var i0 := (k - 1) * 2
				idx.append_array([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2])
		RenderingServer.canvas_item_add_triangle_array(rid, idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), trail_texture.get_rid())


# ---------------------------------------------------------------- Unity curve helpers

## MinMaxCurve evaluate. t = normalized time (0..1), u = per-particle random (0..1)
static func _eval_mm(mm: Dictionary, t: float, u: float) -> float:
	if mm.is_empty():
		return 0.0
	var mode := String(mm.get("mode", "Constant"))
	match mode:
		"Constant":
			return float(mm.get("constant", 0.0))
		"TwoConstants":
			return lerpf(float(mm.get("constantMin", 0.0)), float(mm.get("constantMax", 0.0)), u)
		"Curve":
			return _eval_curve(mm.get("curveMax", {}), t) * float(mm.get("multiplier", 1.0))
		"TwoCurves":
			var a := _eval_curve(mm.get("curveMin", {}), t)
			var b := _eval_curve(mm.get("curveMax", {}), t)
			return lerpf(a, b, u) * float(mm.get("multiplier", 1.0))
	return float(mm.get("constant", 0.0))


## Unity AnimationCurve (Hermite with tangents, clamped outside the key range).
static func _eval_curve(curve: Dictionary, t: float) -> float:
	if curve == null or curve.is_empty():
		return 0.0
	var keys: Array = curve.get("keys", [])
	if keys.is_empty():
		return 0.0
	if keys.size() == 1 or t <= float(keys[0]["t"]):
		return float(keys[0]["v"])
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		return float(last["v"])
	for i in range(keys.size() - 1):
		var k0: Dictionary = keys[i]
		var k1: Dictionary = keys[i + 1]
		var t0 := float(k0["t"])
		var t1 := float(k1["t"])
		if t >= t0 and t <= t1:
			var dt := t1 - t0
			if dt <= 0.0:
				return float(k1["v"])
			var s := (t - t0) / dt
			var m0 := float(k0["out"]) * dt
			var m1 := float(k1["in"]) * dt
			if is_inf(m0) or is_inf(m1) or is_nan(m0) or is_nan(m1) or absf(m0) > 1e20 or absf(m1) > 1e20:
				return float(k0["v"])  # constant (stepped) segment
			var s2 := s * s
			var s3 := s2 * s
			var h00 := 2 * s3 - 3 * s2 + 1
			var h10 := s3 - 2 * s2 + s
			var h01 := -2 * s3 + 3 * s2
			var h11 := s3 - s2
			return h00 * float(k0["v"]) + h10 * m0 + h01 * float(k1["v"]) + h11 * m1
	return float(last["v"])


static func _eval_mmg(g: Dictionary, t: float, u: float) -> Color:
	if g.is_empty():
		return Color.WHITE
	var mode := String(g.get("mode", "Color"))
	match mode:
		"Color":
			return _arr_col(g.get("color", [1, 1, 1, 1]))
		"TwoColors":
			return _arr_col(g.get("colorMin", [1, 1, 1, 1])).lerp(_arr_col(g.get("colorMax", [1, 1, 1, 1])), u)
		"Gradient":
			return _eval_gradient(g.get("gradientMax", {}), t)
		"TwoGradients":
			return _eval_gradient(g.get("gradientMin", {}), t).lerp(_eval_gradient(g.get("gradientMax", {}), t), u)
		"RandomColor":
			return _eval_gradient(g.get("gradientMax", {}), u)
	return Color.WHITE


static func _eval_gradient(gr: Dictionary, t: float) -> Color:
	if gr == null or gr.is_empty():
		return Color.WHITE
	var fixed := String(gr.get("mode", "Blend")) == "Fixed"
	var ck: Array = gr.get("colorKeys", [])
	var ak: Array = gr.get("alphaKeys", [])
	var rgb := Color.WHITE
	if not ck.is_empty():
		rgb = _eval_keys_color(ck, t, fixed)
	var a := 1.0
	if not ak.is_empty():
		a = _eval_keys_alpha(ak, t, fixed)
	return Color(rgb.r, rgb.g, rgb.b, a)


static func _eval_keys_color(keys: Array, t: float, fixed: bool) -> Color:
	if t <= float(keys[0]["t"]):
		return _arr_col(keys[0]["c"])
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		return _arr_col(last["c"])
	for i in range(keys.size() - 1):
		var t0 := float(keys[i]["t"])
		var t1 := float(keys[i + 1]["t"])
		if t >= t0 and t <= t1:
			if fixed:
				return _arr_col(keys[i + 1]["c"])
			var s := (t - t0) / maxf(t1 - t0, 0.00001)
			return _arr_col(keys[i]["c"]).lerp(_arr_col(keys[i + 1]["c"]), s)
	return _arr_col(last["c"])


static func _eval_keys_alpha(keys: Array, t: float, fixed: bool) -> float:
	if t <= float(keys[0]["t"]):
		return float(keys[0]["a"])
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		return float(last["a"])
	for i in range(keys.size() - 1):
		var t0 := float(keys[i]["t"])
		var t1 := float(keys[i + 1]["t"])
		if t >= t0 and t <= t1:
			if fixed:
				return float(keys[i + 1]["a"])
			var s := (t - t0) / maxf(t1 - t0, 0.00001)
			return lerpf(float(keys[i]["a"]), float(keys[i + 1]["a"]), s)
	return float(last["a"])


static func _arr_col(a) -> Color:
	if a is Color:
		return a
	if a is Array and a.size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color.WHITE
