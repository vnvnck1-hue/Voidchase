## 유물(Relic) 1차 데이터 — 설계안 docs/전투_유물시스템_설계안.md 의 MVP 를 5종으로 줄인 것.
## 유물은 전부 1칸. 발동 조건(trigger)과 효과(effect), 배치 문법(grammar)을 데이터로 둔다.
## 트리거: cooldown(초마다) / counter(아군 평타 N회마다) / event(특정 영웅 공격 시, 적 처치 시) / threshold(아군 HP 비율 도달, 전투당 1회)
class_name VDRelicData
extends RefCounted

## 성좌판 10칸: 평평한 윗변(flat-top) 육각형, odd-q 오프셋 좌표 (q 열, r 행). 홀수 열은 반 칸 아래로 처진다.
## 목업처럼 오른쪽에 세로로 두 줄. 위에서부터 차례로 해금한다.
const BOARD_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 3), Vector2i(1, 3),
	Vector2i(0, 4), Vector2i(1, 4),
]
const START_UNLOCKED := 4        # 첫 전투에서 열려 있는 칸
const UNLOCK_PER_CLEAR := 1      # 구역 클리어마다 추가로 여는 칸
const CORRUPT_CHANCE := 0.35     # 구역 클리어 시 빈 칸 하나가 침식될 확률 (보스 방은 확정)
const CORRUPT_MAX := 2           # 동시에 존재할 수 있는 침식 칸
const CORRUPT_PENALTY := 0.25    # 침식 칸 하나에 인접할 때마다 효과 −25%
const PURIFY_COST := 20          # 정화에 드는 공허 정수
const PICK_COUNT := 3            # 구역 클리어 보상: N택1
const STARTING_TRAY: Array[String] = ["thunder_shard", "ember"]   # 런 시작 시 보관함에 들어 있는 유물

const TAG_COLOR := {
	"번개": Color(0.45, 0.85, 1.0),
	"화염": Color(1.0, 0.55, 0.3),
	"서리": Color(0.7, 0.9, 1.0),
	"수호": Color(0.95, 0.85, 0.5),
	"정수": Color(0.8, 0.55, 1.0),
}

## 수치는 영웅 공격력(30~55)과 적 체력(70~400 × 웨이브 배율)을 기준으로 잡았다.
const RELICS := {
	"thunder_shard": {
		"name": "뇌운 조각", "glyph": "雷", "tag": "번개",
		"desc": "아군이 평타를 4번 때릴 때마다 가장 가까운 적에게 번개 35.",
		"grammar": "인접한 유물 하나당 피해 +20%.",
		"trigger": {"type": "counter", "event": "ally_attack", "count": 4},
		"effect": {"type": "lightning", "damage": 35.0},
	},
	"ember": {
		"name": "잉걸불", "glyph": "炎", "tag": "화염",
		"desc": "4초마다 무작위 적에게 화상 (3초 동안 초당 8).",
		"grammar": "비어 있는 이웃 칸 하나당 재사용 대기 −10% (최대 −50%).",
		"trigger": {"type": "cooldown", "sec": 4.0},
		"effect": {"type": "burn", "dps": 8.0, "sec": 3.0},
	},
	"frost_crystal": {
		"name": "서리 결정", "glyph": "氷", "tag": "서리",
		"desc": "마법사의 공격에 서리가 깃든다: 맞은 적 둔화 40%, 2초.",
		"grammar": "바로 위 칸에 유물이 있으면 둔화 시간 2배.",
		"trigger": {"type": "event", "event": "hero_attack", "hero": "mage"},
		"effect": {"type": "slow", "mult": 1.4, "sec": 2.0},
	},
	"star_feather": {
		"name": "별 깃털", "glyph": "羽", "tag": "수호",
		"desc": "아군 체력이 50% 아래로 떨어지면 그 아군에게 최대 체력 25% 보호막 (전투당 1회).",
		"grammar": "성좌판 최상단 줄에서만 작동한다.",
		"trigger": {"type": "threshold", "hp_ratio": 0.5},
		"effect": {"type": "shield", "ratio": 0.25},
	},
	"essence_vial": {
		"name": "공허 정수병", "glyph": "壺", "tag": "정수",
		"desc": "적을 처치할 때마다 정수 +2, 처치한 영웅 마나 +10.",
		"grammar": "인접한 유물 하나당 정수 +1 추가.",
		"trigger": {"type": "event", "event": "enemy_killed"},
		"effect": {"type": "essence", "amount": 2, "mana": 10.0},
	},
}
const RELIC_ORDER: Array[String] = ["thunder_shard", "ember", "frost_crystal", "star_feather", "essence_vial"]


static func def(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func color_of(id: String) -> Color:
	return TAG_COLOR.get(def(id).get("tag", ""), Color.WHITE)


## odd-q 오프셋 좌표의 이웃 6칸 (flat-top). 홀수 열은 아래로 반 칸 밀려 있어 대각 이웃의 행이 다르다.
static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var odd := (c.x & 1) == 1
	var out: Array[Vector2i] = [Vector2i(c.x, c.y - 1), Vector2i(c.x, c.y + 1)]
	if odd:
		out.append_array([Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1), Vector2i(c.x - 1, c.y), Vector2i(c.x - 1, c.y + 1)])
	else:
		out.append_array([Vector2i(c.x + 1, c.y - 1), Vector2i(c.x + 1, c.y), Vector2i(c.x - 1, c.y - 1), Vector2i(c.x - 1, c.y)])
	return out


## 셀 중심의 로컬 픽셀 좌표 (flat-top, 반지름 r).
static func cell_pos(c: Vector2i, r: float) -> Vector2:
	return Vector2(1.5 * r * c.x, sqrt(3.0) * r * (c.y + 0.5 * (c.x & 1)))


## rot = 0 이면 flat-top(평평한 변이 위), PI/6 이면 pointy-top(꼭짓점이 위, 목업 모양).
static func hex_points(center: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + rot
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
