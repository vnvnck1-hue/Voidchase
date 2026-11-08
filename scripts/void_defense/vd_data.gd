## VOID DEFENSE 그레이박스 — 상수·데이터·좌표 변환.
## 수치는 데모(GridDefenseGame_share.html)의 UNIT_TYPES / createEnemy / getScalingMultiplier 를 기준으로 가져왔다.
class_name VDData
extends RefCounted

const ALLY_MAX_A := 3      # 아군 배치 구역: 방 로컬 a 0..3 (입구 쪽)
const ENEMY_MIN_A := 8     # 적 스폰 구역:   방 로컬 a 8..9 (안쪽)
## 타일 크기 배율: 캐릭터 크기는 그대로 두고 칸만 키워 유닛 사이를 띄운다 (1.0 은 오밀조밀했다, 2026-11-07).
## 칸 크기를 기준으로 잡은 픽셀 상수(보드 옆면 높이, 카메라 포커스 거리 등)도 이 배율을 곱한다.
const TILE_SCALE := 1.3
const TILE_W := 128.0 * TILE_SCALE
const TILE_H := 64.0 * TILE_SCALE
const WAVES_PER_STAGE := 5

## 아군 4인. atk_cd / move_cd 는 초 단위 간격(데모는 ms). start 는 방 로컬 (a, c).
## move_sec: 한 칸 걷는 시간(기본 0.25). move_cd 와 함께 캐릭터마다 걸음이 다르다: 건너 날렵 > 기사 성큼 > 힐러 > 마법사 느릿.
## mana: 기본 공격(힐러는 치유 포함) 한 번에 차는 마나(데모 manaPerAttack). MAX_MANA 가 차면 SKILLS 의 액티브 스킬을 자동 시전.
## 데모보다 전투가 짧아(방마다 적 3~10) 2~4번 공격에 차도록 올렸고, 남은 마나는 다음 방으로 이어진다.
const HEROES := {
	"knight": {"name": "기사", "color": Color(0.36, 0.56, 0.95), "hp": 200, "atk": 30, "range": 1, "atk_cd": 1.2, "move_cd": 0.75, "move_sec": 0.2, "start": Vector2i(3, 2), "mana": 34},
	"gunner": {"name": "건너", "color": Color(0.95, 0.47, 0.66), "hp": 120, "atk": 40, "range": 3, "atk_cd": 1.0, "move_cd": 0.55, "move_sec": 0.16, "start": Vector2i(1, 1), "mana": 25},
	"mage":   {"name": "마법사", "color": Color(0.62, 0.42, 0.92), "hp": 100, "atk": 55, "range": 3, "atk_cd": 1.5, "move_cd": 1.5, "move_sec": 0.36, "start": Vector2i(1, 4), "mana": 50},
	"healer": {"name": "힐러", "color": Color(0.56, 0.86, 0.52), "hp": 110, "atk": 20, "range": 2, "atk_cd": 1.2, "move_cd": 1.0, "move_sec": 0.28, "start": Vector2i(2, 3), "healer": true, "mana": 34},
}
const MAX_MANA := 100.0

## 고유 스킬(액티브). 데모 ACTIVE_SKILLS(warrior/ranger/mage)를 기사·건너·마법사에 옮기고, 힐러 것은 새로 만들었다.
## 마나가 차면 자동 시전, 전투는 멈추지 않는다 (짧은 히트스톱·무대 살짝 어둡게만).
## 배율은 시전자의 현재 공격력 기준, 시간은 초.
const SKILLS := {
	"knight": {"name": "용맹한 강습", "desc": "가장 멀리 떨어진 적에게 도약해 착지한다. 착지 지점 주변에 피해·기절, 잠시 받는 피해 감소.",
		"dmg": 1.65, "impact_atk": 1.2, "impact_hp": 0.35, "impact_hp_boss": 0.08, "stun": 1.05, "guard": 2.1, "guard_reduce": 0.5},
	"gunner": {"name": "다중 사격", "desc": "적에게서 먼 쪽으로 한 칸 물러난 뒤 가장 가까운 적 3명에게 강력한 탄환을 쏜다.",
		"dmg": 2.5, "targets": 3},
	"mage":   {"name": "절대 영도", "desc": "모든 적을 1초 동안 얼리고 냉기 피해를 준다.",
		"dmg": 1.5, "freeze": 1.0},
	"healer": {"name": "생명의 축복", "desc": "살아 있는 아군 전체를 회복한다 (최대 체력 20% + 공격력 2배).",
		"heal_hp": 0.2, "heal_atk": 2.0},
}
## 궁극기 (TrioChess ULTIMATES). 고유 스킬(SKILLS)과 따로, 영웅별 궁극기 게이지(MAX_ULT)가 차면 플레이어가 분대 카드를 탭해 쓴다.
## 시전 때 전투가 멈추는 연출(VDUltCinematic)은 궁극기에만 있다. 수치 기준은 TrioChess defs.gd.
## aim: "" 바로 시전 · "cone" 필드를 눌러 방향 조준(부채꼴) · "enemy" 적 하나를 눌러 첫 대상 지정.
## gain: 기본 공격(힐러는 치유) 한 번에 차는 게이지. 피격으로도 찬다 (잃은 체력 비율 × ULT_PER_HURT).
## 남은 게이지는 다음 방으로 이어진다.
const MAX_ULT := 100.0
const ULT_PER_HURT := 100.0
const ULTS := {
	"knight": {"name": "충격파", "desc": "모든 적에게 큰 피해를 주고 한 칸 밀어내며 기절시킨다.", "aim": "",
		"dmg": 2.0, "stun": 1.0, "gain": 18.0},
	"gunner": {"name": "집중 포화", "desc": "조준한 방향의 부채꼴에 1초간 탄환을 난사해 적마다 7회 공격한다.", "aim": "cone",
		"length": 6.0, "half_angle": PI / 7.0, "hits": 7, "tick_dmg": 0.7, "channel": 1.0, "gain": 16.0},
	"mage":   {"name": "체인 라이트닝", "desc": "고른 적에게서 시작해 적 사이를 튕기는 번개. 마지막 적은 하늘 번개에 맞아 감전(기절)된다.", "aim": "enemy",
		"bounces": 5, "dmg": 1.45, "finish_stun": 1.0, "gain": 24.0},
	"healer": {"name": "부활의 기도", "desc": "가장 먼저 쓰러진 아군을 체력 50%로 일으킨다. 쓰러진 아군이 없으면 전원을 크게 회복한다.", "aim": "",
		"revive_hp": 0.5, "heal_hp": 0.35, "gain": 18.0},
}
const HERO_ORDER := ["gunner", "mage", "knight", "healer"]

## 적 기본 스탯. 방에 등장할 때 기존 웨이브 배율이 체력과 공격력에 적용된다.
const ENEMIES := {
	"normal": {"name": "공허 잔재", "color": Color(0.13, 0.09, 0.19), "hp": 90, "atk": 6, "range": 1, "atk_cd": 1.4, "move_cd": 1.2, "move_sec": 0.3, "essence": 5},
	"fast":   {"name": "공허 파편", "color": Color(0.32, 0.12, 0.42), "hp": 58, "atk": 6, "range": 1, "atk_cd": 0.9, "move_cd": 0.3, "move_sec": 0.16, "essence": 6},
	"skirmisher": {"name": "공허 포자", "color": Color(0.66, 0.22, 0.54), "hp": 78, "atk": 9, "range": 4, "atk_cd": 1.75, "move_cd": 1.0, "move_sec": 0.24, "essence": 7},
	"tank":   {"name": "공허 결정체", "color": Color(0.26, 0.22, 0.48), "hp": 210, "atk": 5, "range": 1, "atk_cd": 2.25, "move_cd": 1.8, "move_sec": 0.45, "armor": 0.35, "essence": 10, "tier": 1},
	## size 2: 2x2 칸을 차지하는 대형 적 (cell 은 footprint 의 최소 꼭짓점). 머리의 쌍포로 멀리서 포격한다.
	"longneck": {"name": "공허 망루", "color": Color(0.3, 0.24, 0.36), "hp": 300, "atk": 14, "range": 3, "atk_cd": 2.2, "move_cd": 2.1, "move_sec": 0.55, "armor": 0.2, "essence": 18, "tier": 1, "size": 2},
	"boss":   {"name": "공허 군주", "color": Color(0.06, 0.03, 0.11), "hp": 400, "atk": 18, "range": 2, "atk_cd": 1.5, "move_cd": 1.3, "move_sec": 0.36, "essence": 40, "boss": true, "tier": 2},
}

## 적 특수 스킬 (VDEnemySkills). first: 전투 시작 후 첫 시전까지(초), cd: 이후 재사용 대기(초). 피해는 atk 배수.
const ENEMY_SKILLS := {
	## 공허 망루 공허 섬광포: charge 초 충전 → dur 초 동안 레이저를 쏘며 hits 번 연타. 사정거리 range 안에 아군이 있을 때만.
	"longneck": {"name": "공허 섬광포", "first": 4.0, "cd": 8.0, "charge": 0.6, "dur": 1.5, "hits": 10, "dmg": 0.5, "range": 4},
	## 공허 군주 공허 강하: 체력이 가장 낮은 아군 옆으로 순간이동해 내려찍는다. 대상 피해 dmg, 주변 1칸 splash, 대상 기절 stun.
	"boss": {"name": "공허 강하", "first": 5.0, "cd": 9.0, "charge": 0.5, "hang": 0.28, "dmg": 2.2, "splash": 1.0, "stun": 0.7},
}

## 사망 슬로모션 [실시간 초, 시간 배율]. 적은 ENEMIES 의 tier(0 기본 · 1 중간급 · 2 보스급), 아군은 중간급과 같다.
const DEATH_SLOWMO := [[0.18, 0.4], [0.4, 0.3], [0.9, 0.2]]
const ALLY_DEATH_TIER := 1

static var _font: Font


## 한글 표시용 시스템 폰트 (Godot 기본 폰트는 한글 글리프가 없다).
static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"])
		_font = sf
	return _font


## 데모 getScalingMultiplier 그대로.
static func scaling(wave: int) -> float:
	if wave <= 10:
		return 1.0 + (wave - 1) * 0.15
	if wave <= 20:
		return 2.35 + (wave - 10) * 0.25
	if wave <= 30:
		return 4.85 + (wave - 20) * 0.4
	return 8.85 * pow(1.15, wave - 30)


## 어려운 웨이브: 보스 웨이브이거나 대형 적(공허 망루)이 확정으로 나오는 웨이브 (wave_enemies 와 같은 규칙).
static func is_hard_wave(wave: int) -> bool:
	return wave % WAVES_PER_STAGE == 0 or (wave >= 5 and wave % 3 == 0)


## 초반 세 방에서 특수 적을 하나씩 소개하고, 네 번째 방에서 세 역할을 섞는다.
static func wave_enemies(wave: int) -> Array[String]:
	var list: Array[String] = []
	list.resize(mini(4 + int(wave * 0.6), 10))   # 3+0.5w -> 4+0.6w: 유물이 돌 시간 (2026-11-06)
	list.fill("normal")
	var boss_wave := wave % WAVES_PER_STAGE == 0
	var specialists := ["fast", "skirmisher", "tank"]
	match wave:
		1, 2, 3:
			list[0] = specialists[wave - 1]
		4:
			for i in specialists.size():
				list[i] = specialists[i]
		_:
			list[0] = specialists[(wave - 5) % specialists.size()]
			if not boss_wave:
				for i in range(1, list.size()):
					var roll := randf()
					if roll < 0.16:
						list[i] = "fast"
					elif roll < 0.30:
						list[i] = "skirmisher"
				if wave >= 10 and list[0] != "tank":
					list[1] = "tank"
				# 대형 적 공허 망루: 6구역에서 처음 나오고 이후 3구역마다 한 마리
				if wave % 3 == 0:
					list[list.size() - 1] = "longneck"
	if boss_wave:
		list.append("boss")
	return list


## world 셀 (x, y) → 화면 좌표 (셀 중심).
static func to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## 화면 좌표 → world 셀 (가장 가까운 셀 중심).
static func to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 크기 as / bs 인 정사각 footprint (최소 꼭짓점 a / b) 사이의 축별 빈 칸 수. (0, 0) 이면 겹친다.
static func rect_gap(a: Vector2i, as_: int, b: Vector2i, bs: int) -> Vector2i:
	return Vector2i(maxi(0, maxi(b.x - (a.x + as_ - 1), a.x - (b.x + bs - 1))),
		maxi(0, maxi(b.y - (a.y + as_ - 1), a.y - (b.y + bs - 1))))


## footprint 끼리의 맨해튼 거리 (가장 가까운 두 칸 사이). 크기 1 이면 manhattan 과 같다.
static func rect_dist(a: Vector2i, as_: int, b: Vector2i, bs: int) -> int:
	var g := rect_gap(a, as_, b, bs)
	return g.x + g.y


## cells: 한 변의 칸 수 (대형 유닛 발밑은 2).
static func diamond(center: Vector2, inset := 0.0, cells := 1) -> PackedVector2Array:
	var hw := TILE_W * 0.5 * cells - inset
	var hh := TILE_H * 0.5 * cells - inset * 0.5
	return PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0), center + Vector2(0, -hh),
	])
