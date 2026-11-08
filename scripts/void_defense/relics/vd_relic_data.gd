## 유물(Relic) 데이터 — 설계안 docs/전투_유물시스템_설계안.md.
## 유물은 전부 1칸. 발동 조건(trigger)과 효과(effect), 배치 문법(grammar), 소켓(ports)을 데이터로 둔다.
## 트리거: cooldown(초마다) / counter(아군 평타 N회마다) / event(특정 영웅 공격 시, 적 처치 시) / threshold(아군 HP 비율 도달, 전투당 1회)
##         chain(소켓이 닿은 유물이 발동하면 같이 발동) / aura(스스로 발동하지 않고 소켓 이웃만 강화)
## 소켓: ports = 소켓이 있는 변(0..5, 회전 전 기준). 소켓이 닿은 이웃 유물은 port_effect(haste: 재사용 대기·카운트 단축, power: 위력)를 받고,
##       chain 유물은 소켓으로 이어진 유물이 발동할 때 같이 발동한다. 보드 위에서 우클릭으로 60°씩 회전한다.
class_name VDRelicData
extends RefCounted

## 성좌판 10칸: 평평한 윗변(flat-top) 육각형, odd-q 오프셋 좌표 (q 열, r 행). 홀수 열은 반 칸 아래로 처진다.
## 시안대로 오른쪽에 세로로 두 줄(1열이 화면에서는 왼쪽). 위에서부터 차례로 해금한다.
const BOARD_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 3), Vector2i(1, 3),
	Vector2i(0, 4), Vector2i(1, 4),
]
const START_UNLOCKED := 4        # 첫 전투에서 열려 있는 칸
const RELIC_EVERY := 3           # 구역을 이만큼 클리어할 때마다 유물 보상(칸 해금 + N택1) 한 번
const UNLOCK_PER_CLEAR := 1      # 유물 보상마다 추가로 여는 칸
const CORRUPT_CHANCE := 0.35     # 구역 클리어 시 빈 칸 하나가 침식될 확률 (보스 방은 확정)
const CORRUPT_MAX := 2           # 동시에 존재할 수 있는 침식 칸
const CORRUPT_PENALTY := 0.25    # 침식 칸 하나에 인접할 때마다 효과 −25%
const PURIFY_COST := 20          # 정화에 드는 공허 정수
const PICK_COUNT := 3            # 유물 보상: N택1
const STARTING_TRAY: Array[String] = ["thunder_shard", "ember", "resonance"]   # 런 시작 시 보관함에 들어 있는 유물
const HASTE_PER_COUNT := 0.25    # 가속이 이만큼 모일 때마다 카운터형의 필요 횟수 −1

## 소켓 방향 0..5 (논리 좌표: N, NE, SE, S, SW, NW). 화면에서는 1열이 왼쪽에 있어 좌우가 뒤집혀 보이므로 이름은 화면 기준.
const DIR_NAMES := ["위", "왼쪽 위", "왼쪽 아래", "아래", "오른쪽 아래", "오른쪽 위"]

const TAG_COLOR := {
	"번개": Color(0.45, 0.85, 1.0),
	"화염": Color(1.0, 0.55, 0.3),
	"서리": Color(0.7, 0.9, 1.0),
	"수호": Color(0.95, 0.85, 0.5),
	"정수": Color(0.8, 0.55, 1.0),
}

## 수치는 영웅 공격력(30~55)과 적 체력(90~400 × 웨이브 배율)을 기준으로 잡았다.
const RELICS := {
	"thunder_shard": {
		"name": "뇌운 조각", "glyph": "雷", "tag": "번개",
		"desc": "아군이 평타를 3번 때릴 때마다 가장 가까운 적에게 번개 35.",
		"grammar": "인접한 유물 하나당 피해 +20%. 소켓 1변(위): 소켓 이웃 가속 +15%.",
		"trigger": {"type": "counter", "event": "ally_attack", "count": 3},
		"effect": {"type": "lightning", "damage": 35.0},
		"ports": [0], "port_effect": {"haste": 0.15},
	},
	"ember": {
		"name": "잉걸불", "glyph": "炎", "tag": "화염",
		"desc": "3.5초마다 무작위 적에게 화상 (3초 동안 초당 8).",
		"grammar": "비어 있는 이웃 칸 하나당 재사용 대기 −10% (최대 −50%). 소켓 1변(아래): 소켓 이웃 위력 +20%.",
		"trigger": {"type": "cooldown", "sec": 3.5},
		"effect": {"type": "burn", "dps": 8.0, "sec": 3.0},
		"ports": [3], "port_effect": {"power": 0.2},
	},
	"frost_crystal": {
		"name": "서리 결정", "glyph": "氷", "tag": "서리",
		"desc": "마법사의 공격에 서리가 깃든다: 맞은 적 둔화 40%, 2초.",
		"grammar": "바로 위 칸에 유물이 있으면 둔화 시간 2배. 소켓 2변(왼쪽 위·오른쪽 위): 소켓 이웃 가속 +10%.",
		"trigger": {"type": "event", "event": "hero_attack", "hero": "mage"},
		"effect": {"type": "slow", "mult": 1.4, "sec": 2.0},
		"ports": [1, 5], "port_effect": {"haste": 0.1},
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
	# ---- 체인·소켓 유물 (2026-11-06)
	"resonance": {
		"name": "공명 수정", "glyph": "共", "tag": "번개",
		"desc": "소켓이 닿은 유물이 발동할 때마다 같이 발동: 가장 가까운 적에게 번개 20.",
		"grammar": "소켓 3변(위·왼쪽 아래·오른쪽 아래). 소켓 이웃 위력 +10%.",
		"trigger": {"type": "chain"},
		"effect": {"type": "lightning", "damage": 20.0},
		"ports": [0, 2, 4], "port_effect": {"power": 0.1},
	},
	"metronome": {
		"name": "박자 톱니", "glyph": "齒", "tag": "정수",
		"desc": "스스로는 발동하지 않는다. 소켓(위·아래)이 닿은 유물의 재사용 대기 −30%, 필요 횟수 −1.",
		"grammar": "회전해서 두 유물 사이에 끼운다.",
		"trigger": {"type": "aura"},
		"effect": {"type": "none"},
		"ports": [0, 3], "port_effect": {"haste": 0.3},
	},
	"ember_pouch": {
		"name": "불씨 주머니", "glyph": "囊", "tag": "화염",
		"desc": "소켓 이웃이 발동하면 불타는 적의 화상을 2초 더 (없으면 무작위 적에게 화상 2초, 초당 6).",
		"grammar": "소켓 1변(아래). 소켓 이웃 위력 +15%.",
		"trigger": {"type": "chain"},
		"effect": {"type": "burn", "dps": 6.0, "sec": 2.0, "prefer_burning": true},
		"ports": [3], "port_effect": {"power": 0.15},
	},
	"frost_mirror": {
		"name": "서리 거울", "glyph": "鏡", "tag": "서리",
		"desc": "소켓 이웃이 발동하면 둔화 중인 모든 적에게 얼음 12.",
		"grammar": "소켓 2변(왼쪽 위·오른쪽 위). 소켓 이웃 가속 +15%.",
		"trigger": {"type": "chain"},
		"effect": {"type": "frost_shatter", "damage": 12.0},
		"ports": [1, 5], "port_effect": {"haste": 0.15},
	},
}
const RELIC_ORDER: Array[String] = ["thunder_shard", "ember", "frost_crystal", "star_feather", "essence_vial", "resonance", "metronome", "ember_pouch", "frost_mirror"]


static func def(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func color_of(id: String) -> Color:
	return TAG_COLOR.get(def(id).get("tag", ""), Color.WHITE)


static func ports_of_def(id: String) -> Array:
	return def(id).get("ports", [])


static func port_effect_of(id: String) -> Dictionary:
	return def(id).get("port_effect", {})


## odd-q 오프셋 좌표의 이웃 6칸 (flat-top). 홀수 열은 아래로 반 칸 밀려 있어 대각 이웃의 행이 다르다.
static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in 6:
		out.append(neighbor_in(c, d))
	return out


## 방향 d(0..5 = N, NE, SE, S, SW, NW)의 이웃 칸.
static func neighbor_in(c: Vector2i, d: int) -> Vector2i:
	var odd := (c.x & 1) == 1
	match posmod(d, 6):
		0:
			return c + Vector2i(0, -1)
		1:
			return c + (Vector2i(1, 0) if odd else Vector2i(1, -1))
		2:
			return c + (Vector2i(1, 1) if odd else Vector2i(1, 0))
		3:
			return c + Vector2i(0, 1)
		4:
			return c + (Vector2i(-1, 1) if odd else Vector2i(-1, 0))
		_:
			return c + (Vector2i(-1, 0) if odd else Vector2i(-1, -1))


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
