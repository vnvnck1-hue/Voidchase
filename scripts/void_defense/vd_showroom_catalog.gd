## VFX 쇼룸 목록: 게임 코드가 실제로 부르는 VFX 를 하나씩, 전투와 같은 호출로 재생하는 함수들 (2026-11-11 전수 조사).
## 항목 = {"id", "title", "cat", "used" (쓰이는 곳), "play": Callable(tile) -> float (한 번 재생 길이, 초)}
## 재생 함수는 칸(vd_showroom_tile.gd)이 가진 전투와 같은 이름의 층(ground_fx · fx_root · vfx · camera · shockwave · juice · dmg_log …)에 그린다.
## 스킬·궁극기·적 스킬은 VDBattle 에 묶여 있어(피해·AI·흐름) 그 함수의 연출 호출만 같은 순서·같은 값으로 옮겼다 — 전투 쪽 값을 바꾸면 여기도 맞춘다.
## 쓰이지 않는 것(VDVfx 의 slash · parry 시트, relic_burst 셰이더)은 넣지 않는다. 새 VFX 를 전투에 넣으면 여기에도 한 줄 넣는다.
extends Node

const CutinFx := preload("res://scripts/void_defense/vd_super_cutin_fx.gd")
const CardFlameFx := preload("res://scripts/void_defense/vd_card_flame_fx.gd")
const RelicProjFx := preload("res://scripts/void_defense/relics/vd_relic_proj_fx.gd")
const HitFx := preload("res://scripts/void_defense/vd_hit_fx.gd")
const CartoonHit := preload("res://scripts/void_defense/vd_cartoon_hit_fx.gd")
const KillFx := preload("res://scripts/void_defense/vd_kill_fx.gd")
const WipeFx := preload("res://scripts/screen_transition_fx.gd")
const ScreenTransition := preload("res://scripts/screen_transition.gd")
const EnemySkills := preload("res://scripts/void_defense/vd_enemy_skills.gd")

const CATS := ["타격·피격", "처치·소환", "아군 스킬", "궁극기", "적 스킬", "유물", "화면 효과", "UI·카드", "스프라이트 시트"]
const CAT_COLORS := {
	"타격·피격": Color(1.0, 0.5, 0.6), "처치·소환": Color(0.95, 0.6, 1.0), "아군 스킬": Color(0.55, 0.85, 1.0),
	"궁극기": Color(1.0, 0.85, 0.4), "적 스킬": Color(1.0, 0.45, 0.35), "유물": Color(0.6, 1.0, 0.75),
	"화면 효과": Color(0.7, 0.75, 1.0), "UI·카드": Color(0.95, 0.75, 0.55), "스프라이트 시트": Color(0.8, 0.8, 0.8),
}
const PINK := Color(1.0, 0.35, 0.8)
## 유물 투사체 종류 → 색을 빌려 올 유물 (연출 연구실과 같음)
const RELIC_OF := {"bolt": "thunder_shard", "comet": "ember", "frost": "frost_crystal", "feather": "star_feather", "essence": "essence_vial"}
const RELIC_TITLE := {"bolt": "뇌운 조각 · 번개 띠", "comet": "잉걸불 · 불덩이", "frost": "서리 결정 · 정지장 탄", "feather": "별 깃털 · 실드 패킷", "essence": "정수병 · 정수 띠"}
## 시트 이름 → (제목, 쓰이는 곳, 재생 배율, 바닥 납작)
const SHEETS := [
	["hit_light", "작은 스파크", "모든 일반 명중 · 총구 섬광 · 치명타 · 레이저 연타", 3.0, false],
	["gun_hit", "총탄 명중 스파크", "건너 일반 공격 · 다중 사격 · 집중 포화 명중", 0.9, false],
	["slam", "지면 강타", "기사 강습 착지 · 충격파 궁극기 · 군주 강하 · 보스 소환", 2.0, false],
	["dust", "착지 먼지", "이동 발걸음 · 착지 · 넉백 · 대형 적 발걸음", 2.2, false],
	["dash", "대시 자국", "기사 도약 · 건너 후퇴 · 공허 파편 이동 · 기믹 돌진", 1.6, false],
	["shockwave", "바닥 충격파 링", "소환 착지 · 스킬·궁극기 · 처치 · 레벨업 (바닥에 납작하게)", 1.4, true],
	["lightning", "궤도 빔 번개", "절대 영도 · 체인 마지막 일격 · 부활 · 레벨업 · 뇌운 착탄", 0.8, false],
	["heal", "나노 스캔 회복", "힐러 회복 · 생명의 축복 · 부활의 기도 · 별 깃털 착탄", 0.9, false],
	["orb", "플라즈마 탄 (반복)", "마법사 오브 탄 · 포자/망루 포탄 · 망루 섬광포 충전", 0.45, false],
	["portal", "텔레포트 패드 (반복)", "몬스터 소환 · 강적 예고 · 군주 공허 강하", 0.9, true],
	["magic_circle", "홀로그램 표지 링 (반복)", "마법사 절대 영도 · 힐러 축복·기도 · 강적 예고", 0.35, true],
]

var entries: Array = []


static func cat_color(c: String) -> Color:
	return CAT_COLORS.get(c, Color.WHITE)


func _init() -> void:
	VDSummonFx.load_saved()
	CutinFx.load_saved()
	CardFlameFx.load_saved()
	RelicProjFx.load_saved()
	HitFx.load_saved()
	CartoonHit.load_saved()
	KillFx.load_saved()
	WipeFx.load_saved()
	_build()


func _add(id: String, cat: String, title: String, used: String, play: Callable) -> void:
	entries.append({"id": id, "cat": cat, "title": title, "used": used, "play": play})


func _build() -> void:
	# 타격·피격
	_add("hit_burst", "타격·피격", "피격 파티클 · 별 섬광", "모든 명중의 vfx.spawn(\"burst\") — 마법사 평타 · 스킬 명중 · 처치 일격 (보통/강타)", _p_hit_burst)
	_add("cartoon_hit", "타격·피격", "카툰 피격", "카툰 피격을 켜면 아군 평타 명중 (vd_cartoon_hit_fx · 연출 연구실에서 켜기)", _p_cartoon_hit)
	_add("hit_element", "타격·피격", "속성 피격 색", "피격 몸 번쩍임 색: 물리 · 번개 · 화염 · 서리 · 정수 (VDUnit.hit_flash)", _p_hit_element)
	_add("knight_slash", "타격·피격", "기사 검기", "기사 일반 공격 (VDSwordSlash)", _p_knight_slash)
	_add("gunner_shot", "타격·피격", "건너 총구 섬광 · 에너지 볼트", "건너 일반 공격 (hit_light + VDGunBolt 비주얼 셰이더 + gun_hit)", _p_gunner_shot)
	_add("mage_orb", "타격·피격", "마법사 오브 탄 · 꼬리", "마법사 일반 공격 (orb 투사체 + juice.trail)", _p_mage_orb)
	_add("enemy_shells", "타격·피격", "적 포자탄 · 망루 포탄", "공허 포자 · 공허 망루 일반 공격 (유도 orb + 그을음)", _p_enemy_shells)
	_add("enemy_hit", "타격·피격", "적의 아군 타격", "몬스터가 영웅을 때릴 때 (분홍 hit_light)", _p_enemy_hit)
	_add("crit", "타격·피격", "치명타 CRITICAL!", "치명타: 큰 스파크 · 줌 펀치 · 히트스탑 · 글자", _p_crit)
	_add("wall_bump", "타격·피격", "넉백 · 벽꿍 · 충돌", "기사 세 번째 평타 강타 · 결정체/군주 넉백 (VDImpact)", _p_wall_bump)
	_add("dmg_numbers", "타격·피격", "피해 숫자 · 상태 글자", "모든 피해 (VDDamageLog): 연타 열기 색 · 강타 큰 숫자 · 회복/기절 글자", _p_dmg_numbers)
	# 처치·소환
	_add("kill", "처치·소환", "몬스터 사망 · 콤보", "적 처치: 별 섬광 · 녹아내림 · 체액 · 쇼크웨이브 · DOUBLE!/TRIPLE!", _p_kill)
	_add("kill_boss", "처치·소환", "보스 사망", "보스·대형 처치: 바닥 링 · 큰 쇼크웨이브 · 슬로모션", _p_kill_boss)
	_add("summon", "처치·소환", "몬스터 소환", "웨이브 시작 · 증원 (VDSummonFx 포털 → 낙하 → 착지)", _p_summon)
	_add("summon_boss", "처치·소환", "보스 소환", "보스·대형 적 등장 (큰 포털 · 지면 강타)", _p_summon_boss)
	_add("champion", "처치·소환", "강적 예고 · 착지", "강적(챔피언) 웨이브 (붉은 포털 · 표지 링 · 번개 착지)", _p_champion)
	_add("heavy_step", "처치·소환", "대형 적 발걸음", "공허 군주 · 망루가 한 칸 내딛을 때 (juice.heavy_step)", _p_heavy_step)
	# 아군 스킬
	_add("skill_knight", "아군 스킬", "기사 · 용맹한 강습", "기사 고유 스킬: 도약 → 착지 강타 · 바닥 충격파 · 화면 쇼크웨이브", _p_skill_knight)
	_add("skill_gunner", "아군 스킬", "건너 · 다중 사격", "건너 고유 스킬: 후퇴 대시 → 가까운 적 셋에 강탄", _p_skill_gunner)
	_add("skill_mage", "아군 스킬", "마법사 · 절대 영도", "마법사 고유 스킬: 표지 링 · 충격파 → 모든 적 빙결 번개", _p_skill_mage)
	_add("skill_healer", "아군 스킬", "힐러 · 생명의 축복", "힐러 고유 스킬: 아군 전체 회복 (나노 스캔 + 링)", _p_skill_healer)
	_add("ready", "아군 스킬", "마나 가득 READY!", "마나가 막 찬 영웅 (juice.ready_burst)", _p_ready)
	_add("level_up", "아군 스킬", "레벨업", "영웅 레벨업: 금빛 폭발 · 번개 기둥 · LEVEL UP!", _p_level_up)
	_add("heal_glow", "아군 스킬", "회복 빛 · 부활", "VDUnit.heal 초록 빛 · revive 튀어 오름", _p_heal_glow)
	# 궁극기
	for hid in VDData.HERO_ORDER:
		_add("cutin_" + hid, "궁극기", "초궁극기 컷인 · " + VDData.HEROES[hid]["name"], "궁극기 시전 전면 컷인 (vd_super_cutin) — " + VDData.ULTS[hid]["name"], _p_cutin.bind(hid))
	_add("ult_pose", "궁극기", "궁극기 시전 포즈", "컷인 뒤 시전자 회전 점프 · 별 스파크 · 착지 충격파 · 무대 어둡게 (VDUltCinematic.intro)", _p_ult_pose)
	_add("ult_knight", "궁극기", "기사 · 충격파", "기사 궁극기: 큰 강타 · 화면 쇼크웨이브 · 밀어내기", _p_ult_knight)
	_add("ult_gunner", "궁극기", "건너 · 집중 포화", "건너 궁극기: 부채꼴 난사 예광", _p_ult_gunner)
	_add("ult_mage", "궁극기", "마법사 · 체인 라이트닝", "마법사 궁극기: 튕기는 번개 선 → 하늘 번개", _p_ult_mage)
	_add("ult_healer", "궁극기", "힐러 · 부활의 기도", "힐러 궁극기: 쓰러진 아군 부활 (번개 · 회복 · 링 · 부활!)", _p_ult_healer)
	_add("ult_aim", "궁극기", "조준 대상 강조", "궁극기 조준 중 대상 외곽선·물들임 (unit_target_outline)", _p_ult_aim)
	# 적 스킬
	_add("void_beam", "적 스킬", "망루 · 공허 섬광포", "공허 망루 스킬: 경고 마름모 · 충전 구슬 → 레이저 10연타 → 폭발 · 그을음", _p_void_beam)
	_add("void_descent", "적 스킬", "군주 · 공허 강하", "공허 군주 스킬: 포털 → 사라짐 → 대상 옆에 내려찍기", _p_void_descent)
	_add("parry_fail", "적 스킬", "보스 · 패링 공격 예고 (팟칭)", "공허 감시자·군주의 패링 공격: 눈에서 별이 터지는 예고 + 대상 카드 강조 → 못 받아치면 일격 (VDParry · VDParryCard)", _p_parry.bind(false))
	_add("parry_ok", "적 스킬", "패링 성공 · 반격", "예고된 영웅의 궁극기 키로 받아침: 별 폭발 · PARRY! · 카드 빛 치솟음 · 금빛 반격 (VDParry)", _p_parry.bind(true))
	_add("telegraph", "적 스킬", "공격 경고 마름모", "적 스킬 · 파편 도약 대상 발밑 (juice.telegraph)", _p_telegraph)
	# 유물
	for kind in RelicProjFx.KINDS:
		_add("relic_" + kind, "유물", RELIC_TITLE[kind], "성좌판 유물 투사체 (VDRelicFx.%s)" % kind, _p_relic.bind(kind))
	# 화면 효과
	_add("screen_wave", "화면 효과", "화면 쇼크웨이브", "명중·처치·강타의 화면 일렁임: light · heavy · kill · boss · slam (VDShockwave)", _p_screen_wave)
	_add("screen_glitch", "화면 효과", "화면 글리치", "아군 피격(hit) · 성좌판 침식(corrupt) · 패배(defeat) (VDScreenGlitch)", _p_screen_glitch)
	_add("hurt_glitch", "화면 효과", "피격 카드 글리치", "아군이 맞을 때 그 영웅 카드 테두리 가시 · 흔들림 + 화면 글리치 (VDHurtGlitch)", _p_hurt_glitch)
	for i in ScreenTransition.PRESET_NAMES.size():
		_add("wipe_%d" % i, "화면 효과", "화면 전환 · " + ScreenTransition.PRESET_NAMES[i],
			["씬을 바꿀 때 그래픽 와이프 (screen_transition)", "씬을 바꿀 때 그래픽 와이프 (screen_transition)",
				"씬을 바꿀 때 번개가 대각선으로 치고 모서리의 어두운 판이 닫혔다가 되감기며 열림 (screen_transition_lightning, 화면 컨셉_4.psd 원화)",
				"번개가 치고 두 판이 움찔했다가 가위처럼 쾅 맞물림 → 섬광과 함께 튕겨 열림 (screen_transition_strike · lightning_wipe)",
				"번개가 화면을 베어 어긋나고 칼날 띠가 엇갈려 꽂힘 → 띠가 빠져나가며 장면이 출렁 (screen_transition_strike · lightning_wipe)",
				"환자의 머릿속으로: 장면이 색 단계로 끊기며 방사형으로 늘어나고 디지털 집중선이 꽂혀 빛줄기 터널이 되고, 터널 끝의 빛에서 새 장면이 열림 (warp_dive.tres VisualShader)",
				"워프 다이브의 카툰 버전: 집중선이 꽂히고 톱니 터널이 닫힘 → 번쩍 → 톱니 구멍이 터지듯 열림 (warp_rush.tres VisualShader)"][i], _p_wipe.bind(i))
	_add("fog_reveal", "화면 효과", "입장 안개 열림", "전투 입장 때 하프톤 안개가 가운데부터 열림 (VDFogReveal)", _p_fog_reveal)
	_add("ult_flash", "화면 효과", "궁극기 섬광 · 무대 어둡게", "궁극기·스킬 시전 순간 무대 딤 + 흰 섬광 (VDUltCinematic.spotlight · screen_flash)", _p_ult_flash)
	# UI·카드
	_add("card_flame", "UI·카드", "궁극기 카드 오버차지", "궁극기 게이지가 찬 분대 카드 둘레 에너지 줄기 (card_ult_flame 셰이더)", _p_card_flame)
	_add("card_pop", "UI·카드", "카드 톡 · 쓰러짐", "스킬 시전·레벨업 때 카드 톡 · 영웅이 쓰러지면 카드 흑백 (VDBattleFrame)", _p_card_pop)
	_add("banner", "UI·카드", "배너", "웨이브 정리 · 치료 성공 · 스테이지 알림 (VDBanner)", _p_banner)
	_add("pop_world", "UI·카드", "전장 팝 글자", "READY! · CRITICAL! · 강타! · 스킬 이름 · 콤보 (juice.pop_world)", _p_pop_world)
	# 스프라이트 시트
	for s in SHEETS:
		_add("sheet_" + s[0], "스프라이트 시트", s[1] + "  (" + s[0] + ")", s[2], _p_sheet.bind(s[0], s[3], s[4]))


# ---------------------------------------------------------------- 무대 도우미

## 적 n 마리를 적 구역 가운데부터 한 칸 건너 세운다
func _foes(t, n: int, ids := ["normal", "fast", "skirmisher", "tank"]) -> Array[VDUnit]:
	var out: Array[VDUnit] = []
	var cells: Array[Vector2i] = t.enemy_cells()
	var used: Array[Vector2i] = []
	for c in cells:
		if out.size() >= n:
			break
		var near := false
		for u in used:
			if maxi(absi(u.x - c.x), absi(u.y - c.y)) < 2:
				near = true
		if near:
			continue
		used.append(c)
		out.append(t.spawn_unit(ids[out.size() % ids.size()], c))
	return out


## 아군 구역에서 적 구역에 가장 가까운 칸 (k 번째)
func _ally_cell(t, k := 0) -> Vector2i:
	var e: Array[Vector2i] = t.enemy_cells()
	var center := Vector2(e[0]) if not e.is_empty() else Vector2.ZERO
	var a: Array[Vector2i] = t.ally_cells()
	a.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
		return Vector2(x).distance_squared_to(center) < Vector2(y).distance_squared_to(center))
	var picked: Array[Vector2i] = []
	for c in a:
		var near := false
		for p in picked:
			if maxi(absi(p.x - c.x), absi(p.y - c.y)) < 2:
				near = true
		if not near:
			picked.append(c)
	return picked[mini(k, picked.size() - 1)] if not picked.is_empty() else Vector2i.ZERO


func _hero(t, id: String, k := 0) -> VDUnit:
	return t.spawn_unit(id, _ally_cell(t, k), 0)


## 유닛들이 다 보이게
func _frame(t, units: Array, zoom := 1.5) -> void:
	var cells := []
	for u in units:
		cells.append(u.cell)
	t.look_at_cells(cells, zoom)


func _snd(t, name: String, pitch_var := 0.06, db := 0.0, pitch := 1.0) -> void:
	t.audio.play(name, pitch_var, db, pitch)


# ---------------------------------------------------------------- 타격·피격

func _p_hit_burst(t) -> float:
	var foes := _foes(t, 3)
	_frame(t, foes, 1.9)
	_hit_burst_run(t, foes, t.run)
	return 2.0


func _hit_burst_run(t, foes: Array[VDUnit], my: int) -> void:
	for i in 6:
		await t.after(0.3)
		if not t.alive(my):
			return
		var u: VDUnit = foes[i % foes.size()]
		var heavy := i % 2 == 1
		t.vfx.spawn("burst", t.fx_root, t.chest(u), 0.6 if heavy else 0.35, 0.0, PINK)
		u.hit_punch(0.9 if heavy else 0.5)
		u.hit_flash()
		t.camera.shake(0.45 if heavy else 0.32)
		_snd(t, "knight_hit", 0.08, -6.0 if heavy else -10.0)


func _p_cartoon_hit(t) -> float:
	var foes := _foes(t, 3)
	var h := _hero(t, "knight")
	_frame(t, foes, 1.9)
	_cartoon_run(t, foes, h, t.run)
	return 2.2


func _cartoon_run(t, foes: Array[VDUnit], h: VDUnit, my: int) -> void:
	for i in 6:
		await t.after(0.32)
		if not t.alive(my):
			return
		var u: VDUnit = foes[i % foes.size()]
		var heavy := i % 2 == 1
		CartoonHit.spawn(t.fx_root, t.chest(u), u.position - h.position, heavy)
		u.hit_punch(0.9 if heavy else 0.5)
		u.hit_flash()
		t.camera.shake(0.3)
		_snd(t, "knight_hit", 0.08, -8.0)


func _p_hit_element(t) -> float:
	var foes := _foes(t, 4)
	_frame(t, foes, 1.8)
	_element_run(t, foes, t.run)
	return 2.4


func _element_run(t, foes: Array[VDUnit], my: int) -> void:
	var els := ["", "번개", "화염", "서리", "정수"]
	for i in els.size():
		await t.after(0.4)
		if not t.alive(my):
			return
		var u: VDUnit = foes[i % foes.size()]
		var col: Color = HitFx.element_color(els[i]) if els[i] != "" else PINK
		t.vfx.spawn("burst", t.fx_root, t.chest(u), 0.45, 0.0, col)
		u.hit_punch(0.7)
		u.hit_flash(els[i])
		t.dmg_log.spawn_status(t.chest(u) + Vector2(0, -40), els[i] if els[i] != "" else "물리", col, u)


## 영웅 하나 + 적 하나 (근접이면 붙여 세운다)
func _duel(t, hid: String, eid := "normal") -> Array[VDUnit]:
	var h := _hero(t, hid)
	var cells: Array[Vector2i] = t.enemy_cells()
	var best: Vector2i = cells[0]
	if VDData.HEROES[hid]["range"] <= 1:
		var d := 1 << 30
		for c in cells:
			var m := absi(c.x - h.cell.x) + absi(c.y - h.cell.y)
			if m >= 1 and m < d:
				d = m
				best = c
	var e: VDUnit = t.spawn_unit(eid, best)
	h.face(e.position.x - h.position.x)
	return [h, e]


func _p_knight_slash(t) -> float:
	var p := _duel(t, "knight")
	_frame(t, p, 2.2)
	_slash_run(t, p[0], p[1], t.run)
	return 2.0


func _slash_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	for i in 3:
		await t.after(0.5)
		if not t.alive(my):
			return
		var from: Vector2 = t.chest(h)
		var to: Vector2 = t.chest(e)
		var dir := (to - from).normalized()
		h.attack_anim(to)
		var reach := clampf(from.distance_to(to), 60.0, 120.0)
		VDSwordSlash.spawn(t.fx_root, from + dir * reach * 0.25, reach * 0.75 / 0.42, dir.angle(), dir.x < 0.0)
		t.vfx.spawn("hit_light", t.fx_root, to, 2.7, randf_range(-0.6, 0.6), Color(0.9, 0.95, 1.0))
		e.hit_punch(0.6)
		e.hit_flash()
		_snd(t, "knight_hit", 0.08, -6.0)


func _p_gunner_shot(t) -> float:
	var p := _duel(t, "gunner")
	_frame(t, p, 1.8)
	_gun_run(t, p[0], p[1], t.run)
	return 2.0


func _gun_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	for i in 4:
		await t.after(0.4)
		if not t.alive(my):
			return
		var from: Vector2 = t.chest(h)
		var to: Vector2 = t.chest(e)
		var dir := (to - from).normalized()
		h.attack_anim(to)
		var muzzle := from + dir * 40.0
		t.vfx.spawn("gun_flash", t.fx_root, muzzle, 1.2, dir.angle())
		VDGunBolt.fire(t.fx_root, muzzle, to)
		_snd(t, "gun", 0.05)
		await t.after(VDGunBolt.FLIGHT)
		if not t.alive(my):
			return
		t.vfx.spawn("gun_hit", t.fx_root, to, 0.55, randf() * TAU)
		e.hit_punch(0.4)
		e.hit_flash()


func _p_mage_orb(t) -> float:
	var p := _duel(t, "mage")
	_frame(t, p, 1.8)
	_orb_run(t, p[0], p[1], t.run)
	return 2.0


func _orb_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	for i in 3:
		await t.after(0.5)
		if not t.alive(my):
			return
		var from: Vector2 = t.chest(h)
		var to: Vector2 = t.chest(e)
		h.attack_anim(to)
		t.juice.trail(t.vfx.projectile("orb", t.fx_root, from + Vector2(0, -10), to, 0.22, 0.2, Color(0.85, 0.6, 1.0), 8.0), Color(0.75, 0.5, 1.0), 10.0)
		await t.after(0.22)
		if not t.alive(my):
			return
		t.vfx.spawn("burst", t.fx_root, to, 0.45, 0.0, Color(0.85, 0.55, 1.0))
		e.hit_punch(0.5)
		e.hit_flash()
		_snd(t, "mage_hit", 0.05, -4.0)


func _p_enemy_shells(t) -> float:
	var h := _hero(t, "knight")
	var foes := _foes(t, 2, ["skirmisher", "longneck"])
	_frame(t, [h] + foes, 1.5)
	_shell_run(t, h, foes, t.run)
	return 2.6


func _shell_run(t, h: VDUnit, foes: Array[VDUnit], my: int) -> void:
	for i in 4:
		await t.after(0.45)
		if not t.alive(my):
			return
		var u: VDUnit = foes[i % foes.size()]
		var to: Vector2 = t.chest(h)
		u.attack_anim(to)
		if u.id == "skirmisher":
			var muzzle: Vector2 = t.chest(u) + Vector2(u._facing * 21.0, 0.0)
			t.vfx.spawn("hit_light", t.fx_root, muzzle, 1.0, (to - muzzle).angle(), PINK)
			t.juice.trail(t.vfx.projectile("orb", t.fx_root, muzzle, to, 0.3, 0.14, PINK, 8.0), PINK, 7.0)
			await t.after(0.3)
			if not t.alive(my):
				return
			t.vfx.spawn("burst", t.fx_root, to, 0.35, 0.0, PINK)
			t.juice.scorch(h.position + Vector2(randf_range(-10, 10), 4), PINK, 18.0)
		else:
			var tint := Color(1.0, 0.3, 0.38)
			for side in [-1.0, 1.0]:
				var muzzle := u.position + Vector2(u._facing * 18.0 + side * 22.0, u._top * 0.9)
				t.vfx.spawn("hit_light", t.fx_root, muzzle, 1.2, (to - muzzle).angle(), tint)
				t.juice.trail(t.vfx.projectile("orb", t.fx_root, muzzle, to, 0.4, 0.16, tint, 8.0), tint, 8.0)
			await t.after(0.4)
			if not t.alive(my):
				return
			t.vfx.spawn("burst", t.fx_root, to, 0.5, 0.0, Color(1.0, 0.35, 0.4))
			t.vfx.spawn("dust", t.ground_fx, h.position, 1.2, 0.0, Color(1, 0.8, 0.8, 0.8))
			t.juice.scorch(h.position + Vector2(randf_range(-10, 10), 4), Color(1.0, 0.35, 0.4), 26.0)
		h.hit_punch(0.5)
		h.hit_flash()


func _p_enemy_hit(t) -> float:
	var p := _duel(t, "knight", "fast")
	_frame(t, p, 2.2)
	_enemy_hit_run(t, p[0], p[1], t.run)
	return 1.8


func _enemy_hit_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	for i in 3:
		await t.after(0.45)
		if not t.alive(my):
			return
		e.attack_anim(h.position)
		t.vfx.spawn("hit_light", t.fx_root, t.chest(h), 1.8, randf() * TAU, Color(1.0, 0.55, 0.75))
		h.hit_punch(0.5)
		h.hit_flash()
		t.dmg_log.spawn(t.chest(h) + Vector2(0, -16), 6 + i, false, h)
		_snd(t, "enemy_attack", 0.12)


func _p_crit(t) -> float:
	var p := _duel(t, "knight", "tank")
	_frame(t, p, 2.0)
	_crit_run(t, p[0], p[1], t.run)
	return 2.0


func _crit_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	h.attack_anim(e.position)
	var at: Vector2 = t.chest(e)
	t.vfx.spawn("hit_light", t.fx_root, at, 3.3, randf() * TAU, Color(1.0, 0.8, 0.5))
	t.camera.hitstop(0.07)
	t.camera.punch(0.035)
	t.camera.shake(0.2)
	t.juice.pop_world(at + Vector2(randf_range(-24, 24), -96), "CRITICAL!", Color(1.0, 0.55, 0.3), 24.0, 0.2)
	t.dmg_log.spawn(at + Vector2(0, -16), 87, true, e)
	e.hit_punch(1.0)
	e.hit_flash()
	_snd(t, "knight_hit", 0.05, -3.0, 1.4)


func _p_wall_bump(t) -> float:
	var p := _duel(t, "knight", "normal")
	_frame(t, p, 2.0)
	_bump_run(t, p[0], p[1], t.run)
	return 2.0


## VDImpact.push 의 벽꿍 갈래 (넉백 먼지 → 막힌 자리 스파크 · 글자 · 화면 쇼크웨이브)
func _bump_run(t, h: VDUnit, e: VDUnit, my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	h.attack_anim(e.position)
	t.juice.pop_world(t.chest(e) + Vector2(0, -80), "강타!", Color(0.6, 0.8, 1.0), 22.0, 0.15)
	t.vfx.spawn("dust", t.ground_fx, e.position, 1.1, 0.0, Color(1, 1, 1, 0.75))
	var away := (e.position - h.position).normalized()
	var start := e.position
	var tw := e.create_tween()
	tw.tween_property(e, "position", start + away * 40.0, 0.09)
	await t.after(0.09)
	if not t.alive(my):
		return
	var col := Color(1.0, 0.75, 0.35)
	var at: Vector2 = t.chest(e) + away * 30.0
	t.juice.pop_world(at + Vector2(0, -70), "벽꿍!", col, 26.0, 0.2)
	t.vfx.spawn("hit_light", t.fx_root, at, 2.7, randf() * TAU, col)
	t.shockwave.add(at, "heavy")
	t.camera.hitstop(0.08)
	t.camera.shake(0.35)
	t.dmg_log.spawn(t.chest(e) + Vector2(0, -16), 21, true, e)
	e.stun(0.6)
	e.hit_punch(0.9)
	_snd(t, "knight_hit", 0.05, -2.0, 0.8)


func _p_dmg_numbers(t) -> float:
	var foes := _foes(t, 2)
	_frame(t, foes, 2.0)
	_numbers_run(t, foes, t.run)
	return 2.6


func _numbers_run(t, foes: Array[VDUnit], my: int) -> void:
	# 같은 대상을 끊김 없이 때리면 숫자 색이 크림 → 노랑 → 주황 → 붉은 분홍으로 달아오른다
	for i in 8:
		await t.after(0.16)
		if not t.alive(my):
			return
		t.dmg_log.spawn(t.chest(foes[0]) + Vector2(0, -16), 12 + i * 3, i == 7, foes[0])
	t.dmg_log.spawn_status(t.chest(foes[1]) + Vector2(0, -30), "+24", Color(0.55, 1.0, 0.6), foes[1])
	await t.after(0.3)
	if t.alive(my):
		t.dmg_log.spawn_status(t.chest(foes[1]) + Vector2(0, -50), "기절!", Color(1.0, 0.85, 0.4), foes[1])


# ---------------------------------------------------------------- 처치·소환

func _p_kill(t) -> float:
	var foes := _foes(t, 4)
	_frame(t, foes, 1.6)
	_kill_run(t, foes, t.run)
	return 3.2


## 실제 전투와 같은 사망: 마지막 일격 burst → take_damage(몸이 녹아내림, VDUnit._die) → KillFx.play → 콤보 글자
func _kill_run(t, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	for u in foes:
		if not t.alive(my):
			return
		_kill_one(t, u)
		await t.after(0.35)


func _kill_one(t, u: VDUnit) -> void:
	if not is_instance_valid(u) or not u.alive:
		return
	var at: Vector2 = t.chest(u)
	t.vfx.spawn("burst", t.fx_root, at, 0.6, 0.0, PINK)
	u.take_damage(u.hp + 99999.0)
	_snd(t, "boss_die" if u.is_boss else "enemy_die", 0.05)
	KillFx.play(u, at, t.vfx, t.fx_root, t.ground_fx, t.camera, t.goo, t.shockwave)
	t.juice.on_kill(at)


func _p_kill_boss(t) -> float:
	var u: VDUnit = t.spawn_unit("boss", t.enemy_cells()[0])
	_frame(t, [u], 1.4)
	_boss_kill_run(t, u, t.run)
	return 2.8


func _boss_kill_run(t, u: VDUnit, my: int) -> void:
	await t.after(0.6)
	if t.alive(my):
		_kill_one(t, u)


func _p_summon(t) -> float:
	var cells: Array[Vector2i] = t.enemy_cells()
	t.look_at_cells(cells.slice(0, 5), 1.6)
	_summon_run(t, cells, ["normal", "fast", "skirmisher"], t.run)
	return VDUnit.appear_duration() + 0.9


func _summon_run(t, cells: Array[Vector2i], ids: Array, my: int) -> void:
	for i in ids.size():
		if not t.alive(my):
			return
		_summon_one(t, ids[i], cells[i * 2])
		await t.after(maxf(VDSummonFx.g("interval"), 0.01))


## vd_fx_lab.gd _spawn 과 같게 (전투 vd_battle.gd 웨이브 소환)
func _summon_one(t, id: String, cell: Vector2i) -> VDUnit:
	var u: VDUnit = t.spawn_unit(id, cell)
	var foot := u.position
	var heavy := u.is_boss or u.size > 1
	u.appear(VDSummonFx.play_impact.bind(t.vfx, t.ground_fx, t.fx_root, t.camera, foot, heavy))
	_snd(t, "boss_spawn" if heavy else "enemy_spawn", 0.12)
	VDSummonFx.play_portal(t.vfx, t.ground_fx, foot, heavy)
	return u


func _p_summon_boss(t) -> float:
	var cell: Vector2i = t.enemy_cells()[0]
	t.look_at_cells([cell], 1.4)
	_summon_one(t, "boss", cell)
	return VDUnit.appear_duration() + 1.0


func _p_champion(t) -> float:
	var cell: Vector2i = t.enemy_cells()[0]
	t.look_at_cells([cell], 1.4)
	_champion_run(t, cell, t.run)
	return 3.6


func _champion_run(t, cell: Vector2i, my: int) -> void:
	var foot := VDData.to_screen(Vector2(cell))
	VDSummonFx.play_champion_warn(t.vfx, t.ground_fx, t.camera, foot)
	await t.after(maxf(VDSummonFx.g("portal_sec"), 0.01) * 1.6 + VDSummonFx.g("champ_lead"))
	if not t.alive(my):
		return
	var u: VDUnit = t.spawn_unit("tank", cell)
	u.appear(func() -> void:
		if is_instance_valid(u):
			VDSummonFx.play_champion_impact(t.vfx, t.ground_fx, t.fx_root, t.camera, u.position, u._top))
	_snd(t, "boss_spawn", 0.1)


func _p_heavy_step(t) -> float:
	var cells: Array[Vector2i] = t.enemy_cells()
	var u: VDUnit = t.spawn_unit("boss", cells[0])
	_frame(t, [u], 1.4)
	_step_run(t, u, cells[0], t.run)
	return 2.6


func _step_run(t, u: VDUnit, home: Vector2i, my: int) -> void:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		await t.after(0.55)
		if not t.alive(my):
			return
		var to: Vector2i = home + d if d.x + d.y > 0 else home
		u.move_to_cell(to, 0.36)
		t.juice.heavy_step(u, 0.36)


# ---------------------------------------------------------------- 아군 스킬 (vd_skills.gd 의 연출 호출 그대로)

## 시전 순간 공통 (VDSkills.cast + VDBattle.cast_skill): 스킬 이름 · 몸 빛 · 펀치 · 무대 살짝 어둡게
func _cast_common(t, u: VDUnit, sk_name: String) -> void:
	u.cast_pulse()
	t.dmg_log.spawn_status(t.chest(u) + Vector2(0, -30), sk_name + "!", u.color.lightened(0.35), u)
	t.vfx.spawn("burst", t.fx_root, t.chest(u), 0.4, 0.0, u.color.lightened(0.3))
	t.camera.hitstop(0.13)
	t.camera.punch(0.04)
	t.camera.shake(0.12)


func _p_skill_knight(t) -> float:
	var h := _hero(t, "knight")
	var foes := _foes(t, 3)
	_frame(t, [h] + foes, 1.4)
	_skill_knight_run(t, h, foes, t.run)
	return 2.0


func _skill_knight_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	var target: VDUnit = foes[foes.size() - 1]
	var land := target.cell + Vector2i(-1, 0)
	_cast_common(t, u, VDData.SKILLS["knight"]["name"])
	_snd(t, "whoosh", 0.03, 3.5, 0.7)
	t.vfx.spawn("dash", t.ground_fx, u.position, 1.3, 0.0, Color(0.7, 0.85, 1.0), Vector2.ONE, VDData.to_screen(Vector2(land)).x < u.position.x)
	u.leap_to(land, VDSkills.LEAP_SEC, VDSkills.LEAP_HEIGHT)
	await t.after(VDSkills.LEAP_SEC)
	if not t.alive(my):
		return
	var foot := VDData.to_screen(Vector2(land))
	t.vfx.spawn("slam", t.fx_root, foot, 1.4, 0.0, Color(0.7, 0.85, 1.0))
	t.vfx.spawn("shockwave", t.ground_fx, foot, 0.75, 0.0, Color(0.55, 0.75, 1.0), Vector2(1.0, 0.5))
	t.shockwave.add(foot, "slam")
	t.vfx.spawn("dust", t.ground_fx, foot, 1.8, 0.0, Color(1, 1, 1, 0.8))
	_snd(t, "boss_slam", 0.03, -1.5, 0.8)
	t.camera.shake(0.9)
	t.camera.hitstop(0.09)
	for e in foes:
		e.stun(0.8)
		var at: Vector2 = t.chest(e)
		t.vfx.spawn("hit_light", t.fx_root, at, 3.0, randf() * TAU, Color(0.85, 0.92, 1.0))
		t.dmg_log.spawn(at + Vector2(0, -16), 48, true, e)
		e.hit_punch(0.8)
		e.hit_flash()


func _p_skill_gunner(t) -> float:
	var h := _hero(t, "gunner")
	var foes := _foes(t, 3)
	_frame(t, [h] + foes, 1.4)
	_skill_gunner_run(t, h, foes, t.run)
	return 1.8


func _skill_gunner_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	_cast_common(t, u, VDData.SKILLS["gunner"]["name"])
	var back := u.cell + Vector2i(-1, 0)
	t.vfx.spawn("dash", t.ground_fx, u.position, 1.0, 0.0, Color.WHITE, Vector2.ONE, VDData.to_screen(Vector2(back)).x > u.position.x)
	u.move_to_cell(back, 0.16)
	await t.after(0.18)
	for e in foes:
		if not t.alive(my):
			return
		var from: Vector2 = t.chest(u)
		var to: Vector2 = t.chest(e)
		var dir := (to - from).normalized()
		u.face(to.x - from.x)
		t.vfx.spawn("gun_flash", t.fx_root, from + dir * 40.0, 1.8, dir.angle())
		VDGunBolt.fire(t.fx_root, from + dir * 40.0, to, 0.09, 1.35)
		_snd(t, "gun", 0.05, 4.0)
		t.camera.shake(0.4)
		await t.after(0.09)
		if not t.alive(my):
			return
		t.vfx.spawn("gun_hit", t.fx_root, to, 0.8, randf() * TAU)
		t.dmg_log.spawn(to + Vector2(0, -16), 64, true, e)
		e.hit_punch(0.7)
		e.hit_flash()
		await t.after(0.02)


func _p_skill_mage(t) -> float:
	var h := _hero(t, "mage")
	var foes := _foes(t, 4)
	_frame(t, [h] + foes, 1.3)
	_skill_mage_run(t, h, foes, t.run)
	return 2.2


func _skill_mage_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	_cast_common(t, u, VDData.SKILLS["mage"]["name"])
	_snd(t, "mage_cast", 0.03, 3.0)
	t.vfx.loop("magic_circle", t.ground_fx, u.position, 0.6, 0.28, 0.0, Color(0.5, 0.8, 1.0), Vector2(1.0, 0.5), 0.3, 2.0)
	t.vfx.spawn("shockwave", t.ground_fx, u.position, 2.2, 0.0, Color(0.55, 0.85, 1.0), Vector2(1.0, 0.5), false, 0.8)
	await t.after(0.3)
	if not t.alive(my):
		return
	_snd(t, "frost", 0.03)
	t.camera.shake(0.7)
	t.camera.hitstop(0.07)
	for e in foes:
		e.stun(1.0, true)
		t.vfx.spawn("lightning", t.fx_root, e.position + Vector2(0, e._top * 0.6), 0.35, 0.0, Color(0.6, 0.85, 1.0))
		var at: Vector2 = t.chest(e)
		t.vfx.spawn("burst", t.fx_root, at, 0.45, randf() * TAU, Color(0.6, 0.85, 1.0))
		t.dmg_log.spawn(at + Vector2(0, -16), 55, true, e)
		e.hit_flash("서리")


func _p_skill_healer(t) -> float:
	var team: Array[VDUnit] = []
	for i in 3:
		team.append(_hero(t, ["healer", "knight", "gunner"][i], i))
	for u in team:
		u.hp = u.max_hp * 0.4
	_frame(t, team, 1.6)
	_skill_healer_run(t, team, t.run)
	return 2.0


func _skill_healer_run(t, team: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	var u: VDUnit = team[0]
	_cast_common(t, u, VDData.SKILLS["healer"]["name"])
	_snd(t, "heal", 0.03, 3.0)
	t.vfx.loop("magic_circle", t.ground_fx, u.position, 0.8, 0.32, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.35, 1.5)
	for a in team:
		var before := a.hp
		a.heal(a.max_hp * 0.35)
		t.vfx.spawn("heal", t.fx_root, t.chest(a), 0.65, 0.0, Color(0.8, 1.0, 0.8))
		t.vfx.loop("magic_circle", t.ground_fx, a.position, 0.5, 0.16, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 2.0)
		t.dmg_log.spawn_status(t.chest(a), "+%d" % int(a.hp - before), Color(0.55, 1.0, 0.6), a)


func _p_ready(t) -> float:
	var team: Array[VDUnit] = []
	for i in 3:
		team.append(_hero(t, ["mage", "knight", "gunner"][i], i))
	_frame(t, team, 1.7)
	_ready_run(t, team, t.run)
	return 2.0


func _ready_run(t, team: Array[VDUnit], my: int) -> void:
	for u in team:
		await t.after(0.4)
		if not t.alive(my):
			return
		t.juice.ready_burst(u)


func _p_level_up(t) -> float:
	var u := _hero(t, "gunner")
	_frame(t, [u], 2.2)
	_level_run(t, u, t.run)
	return 1.8


## VDBattle._on_leveled 와 같게
func _level_run(t, u: VDUnit, my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	var at: Vector2 = t.chest(u)
	t.vfx.spawn("burst", t.fx_root, at, 0.8, 0.0, Color(1.0, 0.9, 0.5))
	t.vfx.spawn("lightning", t.fx_root, u.position + Vector2(0, u._top * 0.9), 0.7, 0.0, Color(1.0, 0.92, 0.6))
	t.vfx.spawn("shockwave", t.ground_fx, u.position, 0.7, 0.0, Color(1.0, 0.85, 0.4), Vector2(1.0, 0.5))
	t.juice.pop_world(at + Vector2(0, -90), "LEVEL UP!", Color(1.0, 0.85, 0.35), 26.0, 0.5)
	t.dmg_log.spawn_status(at + Vector2(0, -40), "Lv.2", Color(1.0, 0.95, 0.6), u)
	_snd(t, "chime", 0.0, -2.0, 1.25)
	u._bar_kick = 1.0
	u.cast_pulse()


func _p_heal_glow(t) -> float:
	var a := _hero(t, "knight")
	var b := _hero(t, "gunner", 1)
	a.hp = a.max_hp * 0.3
	_frame(t, [a, b], 2.0)
	_heal_glow_run(t, a, b, t.run)
	return 2.4


func _heal_glow_run(t, a: VDUnit, b: VDUnit, my: int) -> void:
	await t.after(0.3)
	if not t.alive(my):
		return
	a.heal(a.max_hp * 0.5)
	t.vfx.spawn("heal", t.fx_root, t.chest(a), 0.65, 0.0, Color(0.8, 1.0, 0.8))
	b.take_damage(b.hp + 9999.0)
	await t.after(0.9)
	if not t.alive(my):
		return
	b.revive(0.5)
	t.vfx.spawn("heal", t.fx_root, t.chest(b), 1.0, 0.0, Color(1.0, 1.0, 0.8))


# ---------------------------------------------------------------- 궁극기

func _p_cutin(t, hid: String) -> float:
	_foes(t, 3)
	t.look_at_cells(t.enemy_cells().slice(0, 4), 1.4)
	VDUltCinematic.SuperCutin.prewarm()
	var c = VDUltCinematic.SuperCutin.new()
	t.scratch.add_child(c)
	var h: Dictionary = VDData.HEROES[hid]
	c.play(VDData.ULTS[hid]["name"], h["name"], h["color"], t.audio if t.big else null, VDUltCinematic.SUPER_CUTIN[hid] if t.big else "", hid)
	return CutinFx.duration() + 0.3


func _p_ult_pose(t) -> float:
	var u := _hero(t, "mage")
	var foes := _foes(t, 2)
	_frame(t, [u], 2.0)
	_pose_run(t, u, foes, t.run)
	return 2.0


## VDUltCinematic.intro 의 컷인 뒤 부분 (시전자만 남기고 어둡게 → 웅크림 → 회전 점프 → 별 스파크 → 착지 충격파)
func _pose_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.3)
	if not t.alive(my):
		return
	var col := u.color
	_dim(t, [t.board] + foes, 0.38, 0.9)
	_snd(t, "whoosh", 0.0, 0.0, 0.6)
	u._cast_glow = 1.0
	var chest: Vector2 = t.chest(u)
	var pose := u.create_tween()
	pose.tween_callback(func() -> void: _punch(u, Vector2(1.3, 0.75), 0.25))
	pose.tween_property(u, "pose_lift", 55.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pose.parallel().tween_property(u, "pose_spin", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pose.tween_callback(func() -> void:
		var c2 := Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.8)
		t.vfx.spawn("burst", t.fx_root, chest + Vector2(0, -55), 0.55, randf() * TAU, col.lightened(0.3))
		t.vfx.spawn("hit_light", t.fx_root, chest + Vector2(0, -55), 1.6, randf() * TAU, c2)
		_star_sparks(t.fx_root, chest + Vector2(0, -55), col, 12)
		_snd(t, "chime", 0.0, 1.5, 0.7))
	pose.tween_property(u, "pose_lift", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pose.tween_callback(func() -> void:
		u.pose_spin = 0.0
		_punch(u, Vector2(1.45, 0.6), 0.4)
		t.vfx.spawn("shockwave", t.fx_root, u.position, 0.9, 0.0, Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.8), Vector2(1.0, 0.5)))
	t.vfx.spawn("shockwave", t.fx_root, u.position, 0.5, 0.0, Color(col, 0.7), Vector2(1.0, 0.5), false, 0.5)


## 무대 어둡게: 들어갔다가 hold 뒤 돌아온다 (VDUltCinematic._set_dim 처럼 modulate)
func _dim(t, nodes: Array, dim: float, hold: float) -> void:
	var tw: Tween = t.create_tween()
	var k := 1.0 - dim
	tw.tween_method(func(v: float) -> void:
		for n in nodes:
			if is_instance_valid(n):
				n.modulate = Color(v, v, v, n.modulate.a), 1.0, k, 0.18)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float) -> void:
		for n in nodes:
			if is_instance_valid(n):
				n.modulate = Color(v, v, v, n.modulate.a), k, 1.0, 0.3)


func _punch(u: VDUnit, sc: Vector2, dur: float) -> void:
	if not is_instance_valid(u):
		return
	u.scale = sc
	u.create_tween().tween_property(u, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## VDUltCinematic._star_sparks 와 같은 별 스파크
func _star_sparks(parent: Node, at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var s := Polygon2D.new()
		var pts := PackedVector2Array()
		var r := randf_range(7.0, 12.0)
		for k in 10:
			var a := TAU * k / 10.0 - PI * 0.5
			pts.append(Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
		s.polygon = pts
		s.color = col.lightened(randf_range(0.2, 0.6))
		s.position = at
		parent.add_child(s)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(70.0, 150.0)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", at + dir + Vector2(0, 40), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", randf_range(-3.0, 3.0), 0.5)
		tw.tween_property(s, "scale", Vector2.ONE * 0.2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(s.queue_free)


func _p_ult_knight(t) -> float:
	var u := _hero(t, "knight")
	var foes := _foes(t, 4)
	_frame(t, [u] + foes, 1.3)
	_ult_knight_run(t, u, foes, t.run)
	return 1.8


func _ult_knight_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	u.cast_pulse()
	_punch(u, Vector2(1.5, 0.55), 0.5)
	t.vfx.spawn("slam", t.fx_root, u.position, 2.2, 0.0, Color(1.0, 0.85, 0.6))
	t.vfx.spawn("shockwave", t.ground_fx, u.position, 3.4, 0.0, Color(1.6, 1.3, 0.6), Vector2(1.0, 0.5), false, 0.8)
	t.shockwave.add(u.position, "slam", 1.4)
	t.vfx.spawn("dust", t.ground_fx, u.position, 2.4, 0.0, Color(1, 1, 1, 0.8))
	_snd(t, "boss_slam", 0.03, 1.0, 0.8)
	t.camera.shake(1.0)
	t.camera.hitstop(0.1)
	for e in foes:
		e.stun(1.0)
		var d := e.cell - u.cell
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		if VDMap.in_room(t.room, e.cell + step):
			e.move_to_cell(e.cell + step, 0.16)
		var at: Vector2 = t.chest(e)
		t.vfx.spawn("hit_light", t.fx_root, at, 3.3, randf() * TAU, Color(1.0, 0.85, 0.55))
		t.dmg_log.spawn(at + Vector2(0, -16), 120, true, e)
		e.hit_flash()


func _p_ult_gunner(t) -> float:
	var u := _hero(t, "gunner")
	var foes := _foes(t, 3)
	_frame(t, [u] + foes, 1.4)
	_ult_gunner_run(t, u, foes, t.run)
	return 1.8


func _ult_gunner_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.3)
	if not t.alive(my):
		return
	var ud: Dictionary = VDData.ULTS["gunner"]
	var aim: Vector2 = t.chest(foes[0])
	u.cast_pulse()
	u.face(aim.x - u.position.x)
	var hits := int(ud["hits"])
	var step := float(ud["channel"]) / hits
	var dir := VDUlts.cone_dir(u, aim)
	for k in hits:
		if not t.alive(my):
			return
		var from: Vector2 = t.chest(u)
		for s in 3:
			var ang := dir.angle() + randf_range(-1.0, 1.0) * float(ud["half_angle"])
			var far := VDData.to_screen(VDUlts.cell_f(u) + Vector2.from_angle(ang) * float(ud["length"]) * randf_range(0.6, 1.0))
			far.y += u._top * 0.45
			VDGunBolt.fire(t.fx_root, from, far, 0.1, 0.9)
		t.vfx.spawn("gun_flash", t.fx_root, from + (VDData.to_screen(VDUlts.cell_f(u) + dir) - u.position).normalized() * 40.0, 1.6, randf() * TAU)
		_snd(t, "gun", 0.08, 3.0)
		t.camera.shake(0.18)
		for e in foes:
			t.vfx.spawn("gun_hit", t.fx_root, t.chest(e), 0.7, randf() * TAU)
			t.dmg_log.spawn(t.chest(e) + Vector2(0, -16), 18, true, e)
			e.hit_flash()
		await t.after(step)


func _p_ult_mage(t) -> float:
	var u := _hero(t, "mage")
	var foes := _foes(t, 4)
	_frame(t, [u] + foes, 1.3)
	_ult_mage_run(t, u, foes, t.run)
	return 2.4


func _ult_mage_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.3)
	if not t.alive(my):
		return
	u.cast_pulse()
	var prev: Vector2 = t.chest(u) + Vector2(0, -20)
	_snd(t, "lightning", 0.03, 2.0)
	for i in foes.size():
		var e: VDUnit = foes[i]
		var to: Vector2 = t.chest(e)
		VDUlts.bolt(t.fx_root, prev, to, Color(0.75, 0.85, 1.0), 0.16)
		prev = to
		if i == foes.size() - 1:
			await t.after(VDUlts.SKY_STRIKE_BEAT)
			if not t.alive(my):
				return
			t.vfx.spawn("lightning", t.fx_root, e.position + Vector2(0, e._top * 0.6), 0.9, 0.0, Color(0.7, 0.85, 1.0))
			t.vfx.spawn("shockwave", t.ground_fx, e.position, 0.8, 0.0, Color(0.6, 0.8, 1.6), Vector2(1.0, 0.5))
			t.shockwave.add(t.chest(e), "kill")
			_snd(t, "lightning", 0.03, 4.0, 0.8)
			t.camera.shake(0.6)
			t.camera.hitstop(0.08)
			e.stun(1.0)
			t.vfx.spawn("burst", t.fx_root, to, 0.5, randf() * TAU, Color(0.7, 0.85, 1.0))
			t.dmg_log.spawn(to + Vector2(0, -16), 150, true, e)
			e.hit_flash("번개")
		else:
			t.camera.shake(0.15)
			t.vfx.spawn("hit_light", t.fx_root, to, 1.4, randf() * TAU, Color(0.7, 0.85, 1.0))
			t.dmg_log.spawn(to + Vector2(0, -16), 100, true, e)
			e.hit_flash("번개")
			await t.after(VDUlts.CHAIN_STEP)
			if not t.alive(my):
				return


func _p_ult_healer(t) -> float:
	var u := _hero(t, "healer")
	var fallen := _hero(t, "knight", 1)
	fallen.take_damage(fallen.hp + 9999.0)
	_frame(t, [u, fallen], 1.8)
	_ult_healer_run(t, u, fallen, t.run)
	return 2.4


func _ult_healer_run(t, u: VDUnit, target: VDUnit, my: int) -> void:
	await t.after(0.8)
	if not t.alive(my):
		return
	u.cast_pulse()
	_snd(t, "heal", 0.03, 4.0)
	t.vfx.loop("magic_circle", t.ground_fx, u.position, 1.0, 0.45, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 1.2)
	target.revive(0.5)
	var p := target.position
	t.vfx.spawn("lightning", t.fx_root, p + Vector2(0, target._top * 0.6), 0.9, 0.0, Color(1.0, 0.92, 0.55))
	t.vfx.spawn("heal", t.fx_root, t.chest(target), 1.0, 0.0, Color(1.0, 1.0, 0.8))
	t.vfx.spawn("shockwave", t.ground_fx, p, 1.1, 0.0, Color(1.4, 1.3, 0.7), Vector2(1.0, 0.5))
	t.vfx.loop("magic_circle", t.ground_fx, p, 1.2, 0.3, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 2.0)
	t.dmg_log.spawn_status(t.chest(target) + Vector2(0, -24), "부활!", Color(1.0, 0.92, 0.5), target)
	t.camera.shake(0.4)


func _p_ult_aim(t) -> float:
	var u := _hero(t, "mage")
	var foes := _foes(t, 3)
	_frame(t, [u] + foes, 1.5)
	_aim_run(t, foes, t.run)
	return 3.0


func _aim_run(t, foes: Array[VDUnit], my: int) -> void:
	for e in foes:
		await t.after(0.3)
		if not t.alive(my):
			return
		e.set_target_highlight(true)
	var t0 := Time.get_ticks_msec()
	while t.alive(my) and Time.get_ticks_msec() - t0 < 2000:
		var k := 0.5 + 0.5 * sin((Time.get_ticks_msec() - t0) * 0.008)
		for e in foes:
			if is_instance_valid(e):
				e.set_target_pulse(k)
		await t.after(0.03)


# ---------------------------------------------------------------- 적 스킬 (vd_enemy_skills.gd 의 연출 호출 그대로)

## 적 스킬 시작 알림 (_announce): 이름 글자 · 줌 펀치 · 흔들림 · 바닥 링 · 몸 빛
func _announce(t, u: VDUnit, sk_name: String, col: Color) -> void:
	t.juice.pop_world(u.position + Vector2(0, u._top - 46.0), sk_name + "!", col.lightened(0.15), 27.0, 0.5)
	t.camera.punch(0.035)
	t.camera.shake(0.3)
	t.camera.slowmo(0.3, 0.5)
	u._cast_glow = 1.0
	t.vfx.spawn("shockwave", t.ground_fx, u.position, 0.55 * u.size, 0.0, Color(col, 0.85), Vector2(1.0, 0.5))
	t.vfx.spawn("burst", t.fx_root, t.chest(u), 0.45, 0.0, col.lightened(0.2))
	_snd(t, "rise", 0.0, 0.0, 0.55)


## 패링 공격 (VDParry.begin → _strike / _success 의 연출 호출 그대로. 조각은 VDParry.fx_* 를 전투와 같이 쓴다)
func _p_parry(t, ok: bool) -> float:
	var h := _hero(t, "knight")
	var u: VDUnit = t.spawn_unit("watcher", t.enemy_cells()[0])
	u.face(h.position.x - u.position.x)
	h.face(u.position.x - h.position.x)
	_frame(t, [h, u], 1.1)
	var frame = t.ensure_frame()
	for hid in VDData.HERO_ORDER:
		frame.set_hero(hid, 0.8, 0.5, false, true, "")
		frame.parry_mark(hid, false)
	_parry_run(t, u, h, frame, ok, t.run)
	return 3.4


func _parry_run(t, u: VDUnit, h: VDUnit, frame, ok: bool, my: int) -> void:
	var d: Dictionary = VDData.PARRY["watcher"]
	var window := float(d["window"])
	await t.after(0.4)
	if not t.alive(my):
		return
	u.windup(h.position, window)
	u._cast_glow = 1.0
	t.juice.pop_world(u.position + Vector2(0, u._top - 54.0), String(d["name"]) + "!", VDParry.HOT.lightened(0.25), 27.0, 0.5)
	t.juice.telegraph(h, window, VDParry.GOLD)
	var tele := VDParry.fx_telegraph(t, u)
	var mark := VDParry.fx_mark(t, h)
	frame.parry_mark(h.id, true)
	var hold := window * (0.62 if ok else 1.0)
	tele.create_tween().tween_property(tele, "urgency", hold / window, hold)
	await t.after(hold)
	if is_instance_valid(mark):
		mark.queue_free()
	if not t.alive(my):
		if is_instance_valid(tele):
			tele.queue_free()
		frame.parry_mark(h.id, false)
		return
	tele.close(true)
	u.release_windup()
	if not ok:
		frame.parry_mark(h.id, false)
		u.attack_anim(h.position)
		VDParry.fx_strike(t, u, h)
		h.hit_punch(1.0)
		h.hit_flash("")
		t.dmg_log.spawn_status(t.chest(h) + Vector2(0, -50), "기절!", Color(1.0, 0.85, 0.4), h)
		return
	frame.parry_mark(h.id, false, true)
	var clash := VDParry.fx_clash(t, u, h)
	h.attack_anim(u.position)
	h.cast_pulse()
	await t.after(VDParry.COUNTER_DELAY)
	if not t.alive(my):
		return
	VDParry.fx_counter(t, clash, u)
	u.hit_punch(1.0)
	u.hit_flash("")
	t.dmg_log.spawn_status(t.chest(u) + Vector2(0, -56), "무력화!", Color(1.0, 0.93, 0.45), u)


func _p_void_beam(t) -> float:
	var h := _hero(t, "knight")
	var u: VDUnit = t.spawn_unit("longneck", t.enemy_cells()[0])
	u.face(h.position.x - u.position.x)
	_frame(t, [h, u], 1.4)
	_beam_run(t, u, h, t.run)
	var sk: Dictionary = VDData.ENEMY_SKILLS["longneck"]
	return float(sk["charge"]) + float(sk["dur"]) + 1.0


func _beam_run(t, u: VDUnit, target: VDUnit, my: int) -> void:
	var sk: Dictionary = VDData.ENEMY_SKILLS["longneck"]
	var col := EnemySkills.LASER_COL
	var charge := float(sk["charge"])
	await t.after(0.3)
	if not t.alive(my):
		return
	_announce(t, u, sk["name"], col)
	u.windup(target.position, charge)
	t.juice.telegraph(target, charge, col)
	var muzzle := func() -> Vector2: return u.position + Vector2(u._facing * 18.0, u._top * 0.9)
	var orb: Sprite2D = t.vfx.loop("orb", t.fx_root, muzzle.call(), charge + 0.1, 0.06, 0.0, col, Vector2.ONE, 0.1, 6.0)
	if orb:
		orb.create_tween().tween_property(orb, "scale", orb.scale * 3.2, charge).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.after(charge)
	if not t.alive(my):
		return
	u.release_windup()
	var beam := EnemySkills.Beam.new()
	beam.col = col
	beam.material = VDVfx.add_material()
	beam.follow = func() -> Array:
		if not is_instance_valid(u) or not is_instance_valid(target):
			return [Vector2.ZERO, Vector2.ZERO]
		return [muzzle.call(), t.chest(target)]
	t.fx_root.add_child(beam)
	beam.create_tween().tween_property(beam, "k", 1.0, 0.08)
	t.vfx.spawn("hit_light", t.fx_root, muzzle.call(), 2.4, 0.0, col)
	_snd(t, "lightning", 0.0, 6.0, 0.75)
	t.camera.punch(0.03)
	t.camera.shake(0.35)
	var hits := int(sk["hits"])
	for i in hits:
		var last := i == hits - 1
		var at: Vector2 = t.chest(target) + Vector2(randf_range(-10, 10), randf_range(-12, 8))
		t.vfx.spawn("hit_light", t.fx_root, at, 1.5 if last else 1.1, randf() * TAU, col.lightened(0.2))
		t.dmg_log.spawn(at + Vector2(0, -16), 9, last, target)
		target.hit_flash()
		if last:
			t.vfx.spawn("burst", t.fx_root, at, 0.55, 0.0, col)
			t.juice.scorch(target.position + Vector2(randf_range(-8, 8), 4), col, 28.0)
			t.camera.shake(0.45)
			_snd(t, "explode", 0.05, 0.0, 1.1)
		else:
			t.camera.shake(0.12)
		await t.after(float(sk["dur"]) / hits)
		if not t.alive(my):
			return
	var tw := beam.create_tween()
	tw.tween_property(beam, "k", 0.0, 0.16)
	tw.tween_callback(beam.queue_free)


func _p_void_descent(t) -> float:
	var h := _hero(t, "gunner")
	var u: VDUnit = t.spawn_unit("boss", t.enemy_cells()[2])
	_frame(t, [h, u], 1.2)
	_descent_run(t, u, h, t.run)
	return 2.6


func _descent_run(t, u: VDUnit, target: VDUnit, my: int) -> void:
	var sk: Dictionary = VDData.ENEMY_SKILLS["boss"]
	var col := EnemySkills.DESCENT_COL
	var charge := float(sk["charge"])
	var hang := float(sk["hang"])
	var vanish := EnemySkills.VANISH_SEC
	var drop := EnemySkills.DROP_SEC
	await t.after(0.3)
	if not t.alive(my):
		return
	_announce(t, u, sk["name"], col)
	_snd(t, "boss_roar", 0.0, -5.0, 1.3)
	u.windup(target.position, charge)
	t.juice.telegraph(target, charge + vanish + hang + drop, col)
	t.vfx.loop("portal", t.ground_fx, u.position, charge + vanish, 0.45, 0.0, Color(0.55, 0.25, 1.0), Vector2(1.0, 0.5), 0.12, 4.0)
	await t.after(charge)
	if not t.alive(my):
		return
	u.release_windup()
	var land := target.cell + Vector2i(1, 0)
	var land_foot := u.foot_at(land)
	t.vfx.spawn("burst", t.fx_root, t.chest(u), 0.6, 0.0, col)
	t.vfx.spawn("lightning", t.fx_root, u.position + Vector2(0, u._top * 0.9), 0.5, 0.0, col.lightened(0.3))
	_snd(t, "whoosh", 0.03, 3.0, 0.6)
	t.vfx.loop("portal", t.ground_fx, land_foot, vanish + hang + drop + 0.1, 0.55, 0.0, Color(0.85, 0.4, 1.0), Vector2(1.0, 0.5), 0.1, -5.0)
	u.teleport_drop(land, target.position.x, vanish, hang, drop, EnemySkills.DROP_HEIGHT, func() -> void:
		if not t.alive(my) or not is_instance_valid(u):
			return
		var foot := u.position
		t.vfx.spawn("slam", t.fx_root, foot, 1.9, 0.0, col.lightened(0.2))
		t.vfx.spawn("shockwave", t.ground_fx, foot, 1.0, 0.0, Color(col, 0.9), Vector2(1.0, 0.45))
		t.shockwave.add(foot, "slam", 1.2)
		t.vfx.spawn("dust", t.ground_fx, foot, 2.2, 0.0, Color(0.9, 0.8, 1.0, 0.9))
		t.vfx.spawn("burst", t.ground_fx, foot, 0.22, 0.0, Color(1.0, 0.8, 1.0, 0.85), Vector2(1.6, 0.5))
		t.juice.scorch(foot, col, 46.0)
		_snd(t, "boss_slam", 0.03, 2.0, 0.75)
		t.camera.shake(0.85)
		t.camera.hitstop(0.1)
		t.camera.punch(0.05)
		var at: Vector2 = t.chest(target)
		t.vfx.spawn("hit_light", t.fx_root, at, 3.0, randf() * TAU, col.lightened(0.3))
		t.dmg_log.spawn(at + Vector2(0, -16), 40, true, target)
		target.stun(0.7)
		target.hit_flash()
		t.dmg_log.spawn_status(at + Vector2(0, -50), "기절!", Color(1.0, 0.85, 0.4), target))


func _p_telegraph(t) -> float:
	var team: Array[VDUnit] = [_hero(t, "knight"), _hero(t, "healer", 1)]
	_frame(t, team, 1.8)
	t.juice.telegraph(team[0], 1.2)
	t.juice.telegraph(team[1], 1.6, EnemySkills.DESCENT_COL)
	return 2.0


# ---------------------------------------------------------------- 유물 (vd_fx_lab.gd 유물 투사체와 같게: 화면 오른쪽 위 성좌판 자리에서)

func _p_relic(t, kind: String) -> float:
	var foes := _foes(t, 3)
	var ally := _hero(t, "knight")
	_frame(t, [ally] + foes, 1.5)
	_relic_run(t, kind, ally, foes, t.run)
	return RelicProjFx.timing(kind).y + 0.5


func _relic_run(t, kind: String, ally: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.15)
	if not t.alive(my):
		return
	var col := VDRelicData.color_of(RELIC_OF[kind])
	var origin: Vector2 = t.screen_to_world(Vector2(t.DESIGN.x - 230.0, 190.0))
	var target: VDUnit = ally if kind == "feather" else foes[randi() % foes.size()]
	var chest: Vector2 = t.chest(target)
	var track := func() -> Vector2: return t.chest(target) if is_instance_valid(target) else chest
	var fx: VDRelicFx
	match kind:
		"bolt":
			fx = VDRelicFx.bolt(t.fx_root, origin, chest, col, track)
		"comet":
			fx = VDRelicFx.comet(t.fx_root, origin, chest, col, track)
		"frost":
			fx = VDRelicFx.frost(t.fx_root, origin, chest, col, track)
		"feather":
			fx = VDRelicFx.feather(t.fx_root, origin, chest, col, track)
		"essence":
			fx = VDRelicFx.essence(t.fx_root, chest, origin, col)   # 쓰러진 적 → 슬롯
	fx.impact.connect(func() -> void:
		if t.alive(my) and is_instance_valid(target):
			_relic_hit(t, kind, target, col))


## 착탄 반응 (VDRelicRuntime 과 비슷하게, 피해 없이)
func _relic_hit(t, kind: String, target: VDUnit, col: Color) -> void:
	var chest: Vector2 = t.chest(target)
	if target.team == 1:
		target.hit_flash({"bolt": "번개", "comet": "화염", "frost": "서리"}.get(kind, ""))
	match kind:
		"bolt":
			t.vfx.spawn("lightning", t.fx_root, target.position + Vector2(0, target._top * 0.6), 0.45, 0.0, col)
			target.hit_punch(0.9)
			t.camera.shake(0.45)
			t.camera.hitstop(0.03)
		"comet":
			t.vfx.spawn("burst", t.fx_root, chest, 0.35, randf() * TAU, col)
			target.hit_punch(0.6)
		"frost":
			target.hit_punch(0.5)
		"feather":
			t.vfx.spawn("heal", t.fx_root, chest, 0.6, 0.0, col)


# ---------------------------------------------------------------- 화면 효과

func _p_screen_wave(t) -> float:
	var foes := _foes(t, 3)
	_frame(t, foes, 1.4)
	_wave_run(t, foes, t.run)
	return 4.4


func _wave_run(t, foes: Array[VDUnit], my: int) -> void:
	var kinds: Array = t.shockwave.KINDS.keys()
	for i in kinds.size():
		await t.after(0.3)
		if not t.alive(my):
			return
		var u: VDUnit = foes[i % foes.size()]
		t.shockwave.add(t.chest(u), kinds[i])
		t.dmg_log.spawn_status(t.chest(u) + Vector2(0, -40), kinds[i], Color(0.8, 0.85, 1.0), u)
		u.hit_punch(0.6)
		await t.after(float(t.shockwave.KINDS[kinds[i]]["life"]))


func _p_screen_glitch(t) -> float:
	_foes(t, 3)
	t.look_at_cells(t.enemy_cells().slice(0, 4), 1.4)
	_glitch_run(t, t.ensure_screen_glitch(), t.run)
	return 5.6


func _glitch_run(t, sg, my: int) -> void:
	for kind in ["hit", "corrupt", "defeat"]:
		await t.after(0.5)
		if not t.alive(my):
			return
		sg.kick(1.0, kind)
		if kind == "defeat":
			sg.burst_rect(Rect2(0, 370, 1920, 340), 0.6)
		await t.after({"hit": 0.6, "corrupt": 1.3, "defeat": 2.6}[kind])


func _p_hurt_glitch(t) -> float:
	var h := _hero(t, "knight")
	_frame(t, [h], 1.6)
	var hg = t.ensure_hurt_glitch()
	for hid in VDData.HERO_ORDER:
		t._frame.set_hero(hid, 0.7, 0.4, false, true, "")
	_hurt_run(t, hg, h, t.run)
	return 2.4


func _hurt_run(t, hg, h: VDUnit, my: int) -> void:
	var i := 0
	for hid in VDData.HERO_ORDER:
		await t.after(0.5)
		if not t.alive(my):
			return
		hg.kick(0.4 + 0.2 * i, hid)
		h.hit_flash()
		i += 1


func _p_wipe(t, preset: int) -> float:
	_foes(t, 3)
	t.look_at_cells(t.enemy_cells().slice(0, 4), 1.4)
	_wipe_run(t, preset, t.run)
	return ScreenTransition.in_dur(preset) + ScreenTransition.out_dur(preset) + 0.6


func _wipe_run(t, preset: int, my: int) -> void:
	await t.after(0.3)
	if not t.alive(my):
		return
	var w := ScreenTransition.new()
	w.layer_override = 35
	w.preset_override = preset
	w.use_time_scale = true
	t.scratch.add_child(w)
	w.start()
	await w.covered
	if t.alive(my) and is_instance_valid(w):
		w.reveal(0)


func _p_fog_reveal(t) -> float:
	_foes(t, 3)
	t.look_at_cells(t.enemy_cells().slice(0, 4), 1.4)
	var layer := CanvasLayer.new()
	layer.layer = 7
	t.scratch.add_child(layer)
	VDFogReveal.play(layer, {}, t.DESIGN.x / t.DESIGN.y, 0.3)
	return VDFogReveal.DUR + 0.8


func _p_ult_flash(t) -> float:
	var u := _hero(t, "knight")
	var foes := _foes(t, 3)
	_frame(t, [u] + foes, 1.4)
	_flash_run(t, u, foes, t.run)
	return 1.8


func _flash_run(t, u: VDUnit, foes: Array[VDUnit], my: int) -> void:
	await t.after(0.4)
	if not t.alive(my):
		return
	u.cast_pulse()
	_dim(t, [t.board] + foes, 0.38, 0.6)
	await t.after(0.8)
	if not t.alive(my):
		return
	# VDUltCinematic.screen_flash(0.12, 0.2)
	var layer := CanvasLayer.new()
	layer.layer = 10
	t.scratch.add_child(layer)
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.12)
	f.size = t.DESIGN
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.2)
	tw.tween_callback(f.queue_free)


# ---------------------------------------------------------------- UI·카드

func _p_card_flame(t) -> float:
	_foes(t, 2)
	t.look_at_cells(t.enemy_cells().slice(0, 3), 1.4)
	var frame = t.ensure_frame()
	for hid in VDData.HERO_ORDER:
		frame.set_hero(hid, 0.8, 0.5, false, true, "", 1.0, true)
		frame.reignite(hid)
	return CardFlameFx.g("flare_sec") + 2.5


func _p_card_pop(t) -> float:
	_foes(t, 2)
	t.look_at_cells(t.enemy_cells().slice(0, 3), 1.4)
	var frame = t.ensure_frame()
	for hid in VDData.HERO_ORDER:
		frame.set_hero(hid, 0.8, 0.6, false, true, "")
	_card_pop_run(t, frame, t.run)
	return 3.0


func _card_pop_run(t, frame, my: int) -> void:
	for hid in VDData.HERO_ORDER:
		await t.after(0.35)
		if not t.alive(my):
			return
		frame.pop_card(hid, 0.7)
	await t.after(0.3)
	if not t.alive(my):
		return
	var last: String = VDData.HERO_ORDER[VDData.HERO_ORDER.size() - 1]
	frame.set_hero(last, 0.0, 0.0, false, false, "")
	frame.card_down(last)


func _p_banner(t) -> float:
	_foes(t, 3)
	t.look_at_cells(t.enemy_cells().slice(0, 4), 1.4)
	var banner := VDBanner.new()
	t.ensure_hud().add_child(banner)
	var d := banner.play("웨이브 정리", "다음 방으로", Color(0.85, 0.7, 1.0))
	_free_later(t, banner, d + 0.3)
	return d + 0.6


func _free_later(t, n: Node, sec: float) -> void:
	await t.after(sec)
	if is_instance_valid(n):
		n.queue_free()


func _p_pop_world(t) -> float:
	var team: Array[VDUnit] = [_hero(t, "knight"), _hero(t, "gunner", 1)]
	var foes := _foes(t, 2)
	_frame(t, team + foes, 1.6)
	_pop_run(t, team, foes, t.run)
	return 2.4


func _pop_run(t, team: Array[VDUnit], foes: Array[VDUnit], my: int) -> void:
	var words := [[team[0], "READY!", Color(1.0, 0.92, 0.45)], [foes[0], "CRITICAL!", Color(1.0, 0.55, 0.3)],
		[foes[1], "강타!", Color(0.6, 0.8, 1.0)], [team[1], "DOUBLE!", Color(1.0, 0.7, 0.45)]]
	for w in words:
		await t.after(0.35)
		if not t.alive(my):
			return
		var u: VDUnit = w[0]
		t.juice.pop_world(u.position + Vector2(0, u._top - 56.0), w[1], w[2], 24.0, 0.35)


# ---------------------------------------------------------------- 스프라이트 시트

func _p_sheet(t, sheet: String, scl: float, flat: bool) -> float:
	var cell: Vector2i = t.enemy_cells()[0]
	var at := VDData.to_screen(Vector2(cell))
	t.look_at(at - Vector2(0, 30), 1.6)
	var stretch := Vector2(1.0, 0.5) if flat else Vector2.ONE
	var info: Dictionary = VDVfx.LIB[sheet]
	if info.get("loop", false):
		t.vfx.loop(sheet, t.ground_fx if flat else t.fx_root, at, 1.8, scl, 0.0, Color.WHITE, stretch, 0.25, 2.0 if flat else 0.0)
		return 2.0
	# 한 번 재생이 0.15~0.5초로 짧아 칸이 비어 보이지 않게 잇달아 세 번
	var one := float(info["frames"]) / float(info["fps"])
	_sheet_run(t, sheet, at, scl, flat, stretch, one, t.run)
	return one * 3.0 + 0.6


func _sheet_run(t, sheet: String, at: Vector2, scl: float, flat: bool, stretch: Vector2, one: float, my: int) -> void:
	for i in 3:
		if not t.alive(my):
			return
		t.vfx.spawn(sheet, t.ground_fx if flat else t.fx_root, at, scl, 0.0, Color.WHITE, stretch)
		await t.after(one + 0.2)
