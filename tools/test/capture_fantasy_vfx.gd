## 판타지 성향 VFX 점검 캡처 (2026-11-09): 사이파이 컨셉에 맞지 않을 수 있는 연출을 연출 연구실 무대(적 4 + 아군 2) 위에 하나씩 띄워 찍는다.
## 각 연출은 전투 코드의 vfx 호출(시트·색·배율·납작하기)을 그대로 옮겨 재생한다. 창이 필요하므로 서브 모니터에서:
##   Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/FantasyVfxCapture.tscn
## 출력: docs/fantasy_vfx_audit/*.png  (+ shots.txt 에 파일 → 연출 이름). 사용자 인자 `-- --out=res://docs/fantasy_vfx_audit/after/` 로 다른 폴더에
## (2026-11-09 사이파이 교체 전 = docs/fantasy_vfx_audit/, 교체 뒤 = docs/fantasy_vfx_audit/after/)
extends Node

var OUT := "res://docs/fantasy_vfx_audit/"
const RelicProjFx := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")

var lab: Node2D
var vfx: VDVfx
var fx: Node2D
var ground: Node2D
var cam: VDCamera
var enemies: Array = []
var knight: VDUnit
var healer: VDUnit
var _log := PackedStringArray()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=")
			if not OUT.ends_with("/"):
				OUT += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lab = load("res://scenes/void_defense/FxLab.tscn").instantiate()
	add_child(lab)
	await _wait(0.3)
	var picker: CanvasLayer = lab.get("_picker")
	if picker:
		picker.queue_free()
		lab.set("_picker", null)
	lab.call("_cutin_stage")
	enemies = lab.get("_enemies")
	vfx = lab.get("vfx")
	fx = lab.get("fx_root")
	ground = lab.get("ground_fx")
	cam = lab.get("camera")
	# 아군 둘: A 구역에서 적 쪽에 가까운 칸 둘
	var room: Dictionary = lab.get("room")
	var a_cells: Array[Vector2i] = []
	for l in VDMap.local_cells(room, "A"):
		a_cells.append(VDMap.to_world(room, l.x, l.y))
	var ec: Vector2 = lab.call("_e_center")
	a_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(ec) < Vector2(b).distance_squared_to(ec))
	knight = _ally("knight", a_cells[0])
	healer = _ally("healer", a_cells[mini(2, a_cells.size() - 1)])
	_frame()
	await _wait(0.4)
	await _shot("00_stage", "무대 (적 4 · 기사 · 힐러)")

	# ---- 1 힐러 일반 회복: 발밑 마법진 + 회복 반짝임 (vd_battle.gd heal_once)
	vfx.loop("magic_circle", ground, healer.position, 0.35, 0.2, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 1.5)
	vfx.spawn("heal", fx, _chest(knight), 0.5, 0.0, Color(0.8, 1.0, 0.8))
	await _wait(0.1)
	await _shot("01_heal_basic_a", "힐러 일반 회복: 마법진(vr_magic_circle) + 회복 반짝임(vr_heal_sparkles)")
	await _wait(0.15)
	await _shot("01_heal_basic_b", "힐러 일반 회복 (0.25초)")
	await _settle(0.8)

	# ---- 2 힐러 고유 스킬 생명의 축복 (vd_skills.gd _blessing)
	vfx.loop("magic_circle", ground, healer.position, 0.8, 0.32, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.35, 1.5)
	for a in [knight, healer]:
		vfx.spawn("heal", fx, _chest(a), 0.65, 0.0, Color(0.8, 1.0, 0.8))
		vfx.loop("magic_circle", ground, a.position, 0.5, 0.16, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 2.0)
	vfx.spawn("burst", fx, _chest(healer), 0.4, 0.0, healer.color.lightened(0.3))
	await _wait(0.2)
	await _shot("02_blessing_a", "힐러 스킬 생명의 축복: 큰 마법진 + 아군마다 작은 마법진 + 회복 반짝임")
	await _wait(0.25)
	await _shot("02_blessing_b", "생명의 축복 (0.45초)")
	await _settle(1.0)

	# ---- 3 마법사 고유 스킬 절대 영도 (vd_skills.gd _absolute_zero)
	var mage_pos := healer.position
	vfx.loop("magic_circle", ground, mage_pos, 0.6, 0.28, 0.0, Color(0.5, 0.8, 1.0), Vector2(1.0, 0.5), 0.3, 2.0)
	vfx.spawn("shockwave", ground, mage_pos, 2.2, 0.0, Color(0.55, 0.85, 1.0), Vector2(1.0, 0.5), false, 0.8)
	await _wait(0.15)
	await _shot("03_absolute_zero_a", "마법사 스킬 절대 영도: 푸른 마법진 + 바닥 충격파")
	await _wait(0.15)
	for e in enemies:
		e.stun(1.2, true)
		vfx.spawn("lightning", fx, e.position + Vector2(0, e._top * 0.6), 0.35, 0.0, Color(0.6, 0.85, 1.0))
		vfx.spawn("burst", fx, _chest(e), 0.45, randf() * TAU, Color(0.6, 0.85, 1.0))
	await _wait(0.1)
	await _shot("03_absolute_zero_b", "절대 영도 적중: 적마다 하늘 번개(vr_lightning_bolt) + 별 섬광, 몸은 얼음빛")
	await _settle(1.5)

	# ---- 4 힐러 궁극기 부활의 기도 (vd_ults.gd _prayer)
	vfx.loop("magic_circle", ground, healer.position, 1.0, 0.45, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 1.2)
	await _wait(0.15)
	await _shot("04_prayer_a", "힐러 궁극기 부활의 기도: 금빛 큰 마법진")
	var p := knight.position
	vfx.spawn("lightning", fx, p + Vector2(0, knight._top * 0.6), 0.9, 0.0, Color(1.0, 0.92, 0.55))
	vfx.spawn("heal", fx, _chest(knight), 1.0, 0.0, Color(1.0, 1.0, 0.8))
	vfx.spawn("shockwave", ground, p, 1.1, 0.0, Color(1.4, 1.3, 0.7), Vector2(1.0, 0.5))
	vfx.loop("magic_circle", ground, p, 1.2, 0.3, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 2.0)
	await _wait(0.12)
	await _shot("04_prayer_b", "부활: 금빛 하늘 번개 + 회복 반짝임 + 충격파 + 마법진")
	await _settle(1.6)

	# ---- 5 마법사 궁극기 체인 라이트닝 (vd_ults.gd _chain_run)
	var prev := _chest(healer) + Vector2(0, -20)
	for i in enemies.size():
		var e: VDUnit = enemies[i]
		VDUlts.bolt(fx, prev, _chest(e), Color(0.75, 0.85, 1.0), 0.6)
		prev = _chest(e)
	var last: VDUnit = enemies[enemies.size() - 1]
	vfx.spawn("lightning", fx, last.position + Vector2(0, last._top * 0.6), 0.9, 0.0, Color(0.7, 0.85, 1.0))
	vfx.spawn("shockwave", ground, last.position, 0.8, 0.0, Color(0.6, 0.8, 1.6), Vector2(1.0, 0.5))
	await _wait(0.1)
	await _shot("05_chain_lightning", "마법사 궁극기 체인 라이트닝: 지그재그 번개 선 + 마지막 적 하늘 번개")
	await _settle(1.2)

	# ---- 6 레벨업 (vd_battle.gd _on_leveled)
	var at := _chest(knight)
	vfx.spawn("burst", fx, at, 0.8, 0.0, Color(1.0, 0.9, 0.5))
	vfx.spawn("lightning", fx, knight.position + Vector2(0, knight._top * 0.9), 0.7, 0.0, Color(1.0, 0.92, 0.6))
	vfx.spawn("shockwave", ground, knight.position, 0.7, 0.0, Color(1.0, 0.85, 0.4), Vector2(1.0, 0.5))
	await _wait(0.12)
	await _shot("06_levelup", "레벨업: 금빛 별 섬광 + 금빛 번개 기둥 + 바닥 충격파")
	await _settle(1.0)

	# ---- 7 영웅 전투불능 (vd_battle.gd _on_unit_died)
	vfx.spawn("lightning", fx, knight.position + Vector2(0, knight._top * 0.9), 0.6, 0.0, Color(1.0, 0.45, 0.55))
	vfx.spawn("burst", fx, _chest(knight), 0.45, 0.0, Color(1.0, 0.4, 0.5))
	await _wait(0.1)
	await _shot("07_hero_down", "영웅 전투불능: 붉은 하늘 번개 + 별 섬광")
	await _settle(1.0)

	# ---- 8 적 소환 균열(포털) · 강적 예고 마법진 (vd_summon_fx.gd)
	var foot: Vector2 = enemies[0].position
	VDSummonFx.play_portal(vfx, ground, foot, false)
	VDSummonFx.play_portal(vfx, ground, enemies[1].position, true)
	await _wait(0.2)
	await _shot("08_summon_portal", "적 소환 예고 균열: 보라 소용돌이 포털(vr_portal_swirl), 보통/보스")
	await _settle(0.8)
	VDSummonFx.play_champion_warn(vfx, ground, null, foot)
	await _wait(0.4)
	await _shot("08_champion_warn", "강적 예고: 큰 붉은 소용돌이 포털 + 자홍 마법진")
	await _wait(0.4)
	VDSummonFx.play_champion_impact(vfx, ground, fx, null, foot, enemies[0]._top)
	await _wait(0.1)
	await _shot("08_champion_impact", "강적 착지: 충격파 + 위로 솟는 번개 + 먼지 + 내려찍기")
	await _settle(1.5)

	# ---- 9 공허 군주 공허 강하: 순간이동 포털 (vd_enemy_skills.gd)
	vfx.loop("portal", ground, enemies[2].position, 1.0, 0.45, 0.0, Color(0.55, 0.25, 1.0), Vector2(1.0, 0.5), 0.12, 4.0)
	vfx.loop("portal", ground, enemies[3].position, 1.0, 0.55, 0.0, Color(0.85, 0.4, 1.0), Vector2(1.0, 0.5), 0.1, -5.0)
	vfx.spawn("lightning", fx, enemies[2].position + Vector2(0, enemies[2]._top * 0.9), 0.5, 0.0, Color(0.72, 0.32, 1.0).lightened(0.3))
	await _wait(0.25)
	await _shot("09_boss_descent_portal", "보스 공허 강하: 사라지는 자리·내려오는 자리 보라 포털 + 번개")
	await _settle(1.2)

	# ---- 10 에너지 구슬 투사체 (마법사 평타 · 포자 · 망루 충전)
	vfx.projectile("orb", fx, _chest(healer) + Vector2(0, -10), _chest(enemies[0]), 0.9, 0.2, Color(0.85, 0.6, 1.0), 8.0)
	vfx.projectile("orb", fx, _chest(knight), _chest(enemies[1]), 0.9, 0.14, Color(1.0, 0.35, 0.8), 8.0)
	vfx.loop("orb", fx, _chest(enemies[3]) + Vector2(0, -20), 1.0, 0.1, 0.0, Color(1.0, 0.25, 0.42), Vector2.ONE, 0.1, 6.0)
	await _wait(0.4)
	await _shot("10_energy_orb", "에너지 구슬(vr_energy_orb): 마법사 평타(보라)·포자(분홍) 투사체, 망루 레이저 충전(붉음)")
	await _settle(1.0)

	# ---- 11 유물 투사체 5종 (relics/vd_relic_fx.gd, 연구실 relic 모드 그대로)
	lab.set("_mode", "relic")
	lab.set("_auto", false)
	var names := {"bolt": "뇌운 조각 (번개 띠)", "comet": "잉걸불 (불덩이 + 궤적 불꽃)", "frost": "서리 결정 (시안 혜성 + 눈꽃 착탄)", "feather": "별 깃털 (금빛 깃털 띠)", "essence": "공허 정수병 (보라 띠 3개)"}
	for i in RelicProjFx.KINDS.size():
		var kind: String = RelicProjFx.KINDS[i]
		lab.set("_target", i)
		var target: VDUnit = knight if kind == "feather" else enemies[i % enemies.size()]
		var tm: Vector2 = RelicProjFx.timing(kind)
		lab.call("_fire_relic", target)
		await _wait(maxf(tm.x * 0.55, 0.05))
		await _shot("11_relic_%s_fly" % kind, "유물 투사체 %s: 비행 중" % names[kind])
		await _wait(maxf(tm.x * 0.45, 0.02) + 0.06)
		await _shot("11_relic_%s_hit" % kind, "유물 투사체 %s: 착탄" % names[kind])
		await _settle(maxf(tm.y - tm.x, 0.4) + 0.5)
	var mark: Node2D = lab.get("_origin_mark")
	if mark:
		mark.visible = false

	# ---- 12 몬스터 피격 파티클 (VDTouchHit: 노란 별 섬광 + 번개)
	lab.set("_mode", "hit")
	lab.call("_hit_unit", enemies[0], true)
	lab.call("_hit_unit", enemies[2], false)
	await _wait(0.08)
	await _shot("12_touch_hit_a", "몬스터 피격 파티클: 노란 별 섬광 + 내리치는 번개 (강타 / 보통)")
	await _wait(0.12)
	await _shot("12_touch_hit_b", "몬스터 피격 파티클 (0.2초)")
	await _settle(1.0)

	# ---- 13 기사 검기 (VDSwordSlash 셀 초승달)
	var from := _chest(knight)
	var to := _chest(enemies[0])
	var dir := (to - from).normalized()
	var reach := 110.0
	VDSwordSlash.spawn(fx, from + dir * reach * 0.25, reach * 0.75 / 0.42, dir.angle(), dir.x < 0.0)
	await _wait(0.13)
	await _shot("13_sword_slash_a", "기사 검기: 셀 초승달 (4프레임)")
	await _wait(0.13)
	await _shot("13_sword_slash_b", "기사 검기 (8프레임)")
	await _settle(0.8)

	# ---- 14 상태 표시 (vd_unit.gd _draw_overlay): 화상 불꽃 점 · 둔화 얼음 고리 · 기절 별 · 가드 고리 · 마나 READY 별
	enemies[0].burn_timer = 3.0
	enemies[1].slow_timer = 3.0
	enemies[2].stun(3.0)
	knight.guard_timer = 3.0
	knight.shield = knight.max_hp * 0.4
	healer.mana_gain = 10.0
	healer.mana = VDData.MAX_MANA
	# 전투에서는 VDBattle 이 매 틱 tick_status 를 불러 오버레이를 다시 그린다. 여기선 시간을 줄이지 않고(dt 0) 다시 그리기만
	for k in 18:
		for u in enemies + [knight, healer]:
			u.tick_status(0.0)
		await get_tree().process_frame
	await _shot("14_status_overlays", "상태 표시: 화상 불꽃 점(적1) · 둔화 얼음 고리(적2) · 기절 별(적3) · 기사 가드 고리+보호막 · 힐러 마나 READY 별")
	enemies[0].burn_timer = 0.0
	enemies[1].slow_timer = 0.0
	knight.guard_timer = 0.0
	knight.shield = 0.0
	healer.mana = 0.0
	healer.mana_gain = 0.0

	# ---- 15 궁극기 카드 불꽃 (연구실 flame 모드)
	lab.call("_open", "flame")
	await _real(1.4)
	var ui: CanvasLayer = lab.get("_ui")
	if ui:
		ui.visible = false
	await _real(0.1)
	await _shot("15_card_flame", "궁극기 준비 카드 불꽃: 카드 둘레 황금 불꽃 + 불티 (card_ult_flame.gdshader)")

	var f := FileAccess.open(OUT + "shots.txt", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	print("[audit] done")
	get_tree().quit(0)


func _ally(id: String, cell: Vector2i) -> VDUnit:
	var u := VDUnit.new()
	u.setup(VDData.HEROES[id], id, 0, cell)
	lab.get("units_root").add_child(u)
	u.snap_to_cell()
	return u


## 적·아군 전부가 보이게 카메라를 가운데로
func _frame() -> void:
	var sum := Vector2.ZERO
	var n := 0
	for u in enemies + [knight, healer]:
		sum += u.position
		n += 1
	cam.position = sum / n + Vector2(0, -30)
	cam.base_zoom = Vector2(1.45, 1.45)


func _chest(u: VDUnit) -> Vector2:
	return u.position + Vector2(0, u._top * 0.55)


## 연출이 끝나길 기다린 뒤 남은 이펙트를 치운다 (다음 장면에 섞이지 않게)
func _settle(sec: float) -> void:
	await _wait(sec)
	for n in fx.get_children() + ground.get_children():
		n.queue_free()
	await _wait(0.05)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String, desc: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	_log.append("%s.png\t%s" % [name, desc])
	print("[audit] shot ", name)
