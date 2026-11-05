## VOID DEFENSE 플립북 VFX: 타워대시·헥스 블레이드·VFX연구에서 가져온 스프라이트 시트를 재생한다.
## 출처는 assets/vfx/void_defense/SOURCES.md. 이펙트는 수명이 끝나면 스스로 사라진다.
##   spawn(name, pos, ...)            한 번 재생
##   loop(name, pos, duration, ...)   duration 동안 반복 후 페이드
##   projectile(name, from, to, dur)  from→to 로 날아가는 루프 시트 (도착하면 사라짐)
class_name VDVfx
extends Node

const DIR := "res://assets/vfx/void_defense/"

## name -> 시트 정보. size 는 한 프레임의 px, pivot 은 프레임 안의 기준점(0~1).
const LIB := {
	"hit_light":   {"file": "td_hit_spark_light.png",  "cols": 8, "rows": 2, "frames": 12, "fps": 30.0, "size": 64,   "blend": "normal"},
	"hit_heavy":   {"file": "td_hit_spark_heavy.png",  "cols": 8, "rows": 2, "frames": 16, "fps": 40.0, "size": 96,   "blend": "normal"},
	"slash":       {"file": "td_slash_steel_swing.png","cols": 8, "rows": 2, "frames": 16, "fps": 30.0, "size": 64,   "blend": "add"},
	"parry":       {"file": "td_parry_spark.png",      "cols": 8, "rows": 2, "frames": 14, "fps": 40.0, "size": 64,   "blend": "normal"},
	"kill_burst":  {"file": "td_multikill_burst.png",  "cols": 8, "rows": 3, "frames": 20, "fps": 30.0, "size": 128,  "blend": "normal"},
	"slam":        {"file": "td_slam_impact.png",      "cols": 8, "rows": 3, "frames": 18, "fps": 34.0, "size": 128,  "blend": "normal", "pivot": Vector2(0.5, 0.78)},
	"dust":        {"file": "td_land_dust.png",        "cols": 8, "rows": 2, "frames": 14, "fps": 30.0, "size": 64,   "blend": "normal", "pivot": Vector2(0.5, 0.82)},
	"dash":        {"file": "td_dash_burst.png",       "cols": 8, "rows": 2, "frames": 12, "fps": 30.0, "size": 64,   "blend": "normal", "pivot": Vector2(0.6, 0.82)},
	"gun_hit":     {"file": "hx_hit_spark_sheet.png",  "cols": 3, "rows": 1, "frames": 3,  "fps": 22.0, "size": 256,  "blend": "normal"},
	"burst":       {"file": "vr_impact_burst.png",     "cols": 4, "rows": 4, "frames": 16, "fps": 32.0, "size": 512,  "blend": "add"},
	"heal":        {"file": "vr_heal_sparkles.png",    "cols": 4, "rows": 4, "frames": 16, "fps": 20.0, "size": 512,  "blend": "add"},
	"orb":         {"file": "vr_energy_orb.png",       "cols": 4, "rows": 4, "frames": 16, "fps": 30.0, "size": 512,  "blend": "add", "loop": true},
	"shockwave":   {"file": "vr_shockwave.png",        "cols": 4, "rows": 4, "frames": 16, "fps": 30.0, "size": 512,  "blend": "add"},
	"portal":      {"file": "vr_portal_swirl.png",     "cols": 4, "rows": 4, "frames": 16, "fps": 24.0, "size": 512,  "blend": "add", "loop": true},
	"lightning":   {"file": "vr_lightning_bolt.png",   "cols": 4, "rows": 4, "frames": 16, "fps": 30.0, "size": 512,  "blend": "add"},
	"magic_circle":{"file": "vr_magic_circle.png",     "cols": 1, "rows": 1, "frames": 1,  "fps": 1.0,  "size": 1024, "blend": "add", "loop": true},
}

var _tex := {}
var _mat_add: CanvasItemMaterial
var play_count := {}        # 테스트용: 이름별 재생 횟수


func _ready() -> void:
	_mat_add = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for name in LIB:
		var t := load(DIR + LIB[name]["file"])
		if t:
			_tex[name] = t
		else:
			push_warning("[VDVfx] missing " + DIR + LIB[name]["file"])


## 한 번 재생. parent 아래에 붙인다(보통 fx_root 또는 ground_root).
## scl 은 균등 배율, stretch 는 추가 (x, y) 배율(아이소 바닥용 (1, 0.5) 등).
func spawn(name: String, parent: Node, pos: Vector2, scl := 1.0, rot := 0.0, tint := Color.WHITE,
		stretch := Vector2.ONE, flip := false, speed := 1.0) -> Sprite2D:
	var s := _make(name, pos, scl, rot, tint, stretch, flip)
	if s == null:
		return null
	s.set_meta("loop", false)
	s.set_meta("speed", speed)
	parent.add_child(s)
	return s


## duration 초 동안 루프 재생 후 fade 초에 걸쳐 사라진다.
func loop(name: String, parent: Node, pos: Vector2, duration: float, scl := 1.0, rot := 0.0,
		tint := Color.WHITE, stretch := Vector2.ONE, fade := 0.25, spin := 0.0) -> Sprite2D:
	var s := _make(name, pos, scl, rot, tint, stretch, false)
	if s == null:
		return null
	s.set_meta("loop", true)
	s.set_meta("speed", 1.0)
	s.set_meta("spin", spin)
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(s, "modulate:a", 0.0, fade)
	tw.tween_callback(s.queue_free)
	return s


## from → to 로 dur 초 동안 날아가는 루프 시트. track을 주면 이동 중인 목표를 따라간다.
func projectile(name: String, parent: Node, from: Vector2, to: Vector2, dur: float, scl := 1.0,
		tint := Color.WHITE, spin := 0.0, track := Callable()) -> Sprite2D:
	var s := _make(name, from, scl, (to - from).angle(), tint, Vector2.ONE, false)
	if s == null:
		return null
	s.set_meta("loop", true)
	s.set_meta("speed", 1.0)
	s.set_meta("spin", spin)
	parent.add_child(s)
	var tw := s.create_tween()
	if track.is_valid():
		tw.tween_method(func(progress: float) -> void:
			var aim: Vector2 = track.call()
			s.position = from.lerp(aim, progress), 0.0, 1.0, dur)
	else:
		tw.tween_property(s, "position", to, dur)
	tw.tween_callback(s.queue_free)
	return s


func _make(name: String, pos: Vector2, scl: float, rot: float, tint: Color, stretch: Vector2, flip: bool) -> Sprite2D:
	if not _tex.has(name):
		return null
	var info: Dictionary = LIB[name]
	play_count[name] = int(play_count.get(name, 0)) + 1
	var s := Sprite2D.new()
	s.texture = _tex[name]
	s.hframes = info["cols"]
	s.vframes = info["rows"]
	s.frame = 0
	s.position = pos
	s.rotation = rot
	s.scale = Vector2(scl, scl) * stretch
	if flip:
		s.scale.x = -s.scale.x
	s.modulate = tint
	var pivot: Vector2 = info.get("pivot", Vector2(0.5, 0.5))
	s.offset = (Vector2(0.5, 0.5) - pivot) * float(info["size"])
	if info["blend"] == "add":
		s.material = _mat_add
	s.set_meta("name", name)
	s.set_meta("t", 0.0)
	s.set_script(_PLAYER)
	return s


## 프레임 진행은 각 스프라이트에 붙는 작은 스크립트가 맡는다.
const _PLAYER := preload("res://scripts/void_defense/vd_vfx_player.gd")
