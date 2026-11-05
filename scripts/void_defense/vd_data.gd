## VOID DEFENSE 그레이박스 — 상수·데이터·좌표 변환.
## 수치는 데모(GridDefenseGame_share.html)의 UNIT_TYPES / createEnemy / getScalingMultiplier 를 기준으로 가져왔다.
class_name VDData
extends RefCounted

const ALLY_MAX_A := 3      # 아군 배치 구역: 방 로컬 a 0..3 (입구 쪽)
const ENEMY_MIN_A := 8     # 적 스폰 구역:   방 로컬 a 8..9 (안쪽)
const TILE_W := 128.0
const TILE_H := 64.0
const WAVES_PER_STAGE := 5

## 아군 4인. atk_cd / move_cd 는 초 단위 간격(데모는 ms). start 는 방 로컬 (a, c).
## mana: 기본 공격(힐러는 치유 포함) 한 번에 차는 마나(데모 manaPerAttack). MAX_MANA 가 차면 SKILLS 의 액티브 스킬을 자동 시전.
## 데모보다 전투가 짧아(방마다 적 3~10) 2~4번 공격에 차도록 올렸고, 남은 마나는 다음 방으로 이어진다.
const HEROES := {
	"knight": {"name": "기사", "color": Color(0.36, 0.56, 0.95), "hp": 200, "atk": 30, "range": 1, "atk_cd": 1.2, "move_cd": 0.9, "start": Vector2i(3, 2), "mana": 34},
	"gunner": {"name": "건너", "color": Color(0.95, 0.47, 0.66), "hp": 120, "atk": 40, "range": 3, "atk_cd": 1.0, "move_cd": 1.0, "start": Vector2i(1, 1), "mana": 25},
	"mage":   {"name": "마법사", "color": Color(0.62, 0.42, 0.92), "hp": 100, "atk": 55, "range": 3, "atk_cd": 1.5, "move_cd": 1.6, "start": Vector2i(1, 4), "mana": 50},
	"healer": {"name": "힐러", "color": Color(0.56, 0.86, 0.52), "hp": 110, "atk": 20, "range": 2, "atk_cd": 1.2, "move_cd": 1.2, "start": Vector2i(2, 3), "healer": true, "mana": 34},
}
const MAX_MANA := 100.0

## 액티브 스킬. 데모 ACTIVE_SKILLS(warrior/ranger/mage)를 기사·건너·마법사에 옮기고, 힐러 것은 새로 만들었다.
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
const HERO_ORDER := ["gunner", "mage", "knight", "healer"]

## 적 기본 스탯. 방에 등장할 때 기존 웨이브 배율이 체력과 공격력에 적용된다.
const ENEMIES := {
	"normal": {"name": "공허 잔재", "color": Color(0.13, 0.09, 0.19), "hp": 70, "atk": 6, "range": 1, "atk_cd": 1.4, "move_cd": 1.2, "essence": 5},
	"fast":   {"name": "공허 파편", "color": Color(0.32, 0.12, 0.42), "hp": 45, "atk": 6, "range": 1, "atk_cd": 0.9, "move_cd": 0.3, "move_sec": 0.16, "essence": 6},
	"skirmisher": {"name": "공허 포자", "color": Color(0.66, 0.22, 0.54), "hp": 60, "atk": 9, "range": 4, "atk_cd": 1.75, "move_cd": 1.2, "essence": 7},
	"tank":   {"name": "공허 결정체", "color": Color(0.26, 0.22, 0.48), "hp": 170, "atk": 5, "range": 1, "atk_cd": 2.25, "move_cd": 1.8, "armor": 0.35, "essence": 10},
	"boss":   {"name": "공허 군주", "color": Color(0.06, 0.03, 0.11), "hp": 400, "atk": 18, "range": 2, "atk_cd": 1.5, "move_cd": 1.3, "essence": 40, "boss": true},
}

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


## 초반 세 방에서 특수 적을 하나씩 소개하고, 네 번째 방에서 세 역할을 섞는다.
static func wave_enemies(wave: int) -> Array[String]:
	var list: Array[String] = []
	list.resize(mini(3 + int(wave * 0.5), 10))
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


static func diamond(center: Vector2, inset := 0.0) -> PackedVector2Array:
	var hw := TILE_W * 0.5 - inset
	var hh := TILE_H * 0.5 - inset * 0.5
	return PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0), center + Vector2(0, -hh),
	])
