## 캐릭터 아이템 (슬롯 3칸). 아직 효과는 없다: 시안에 그려진 아이콘 3종을 자리만 잡아 둔 것.
## 슬롯 내용은 카드(분대 영웅 id)·턴테이블(로스터 번호)별로 들고 있고, 처음엔 시안의 예시 배치를 그대로 채운다.
## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 preload 해서 쓴다.
extends RefCounted

const Layout := preload("res://scripts/void_defense/vd_battle_ui_layout.gd")

const SLOTS := 3
const ITEMS := {
	"item_heart": {"name": "하트 탄환", "desc": "시안 예시 아이템 — 효과 미정."},
	"item_bloom": {"name": "붉은 꽃잎", "desc": "시안 예시 아이템 — 효과 미정."},
	"item_skull": {"name": "망자의 동전", "desc": "시안 예시 아이템 — 효과 미정."},
}


## 시안 배치: 카드 i(0~3, HERO_ORDER 순)와 좌측 턴테이블 앞 캐릭터.
static func mock_slots(card: Variant) -> Array[String]:
	var out: Array[String] = []
	for j in SLOTS:
		out.append(Layout.MOCK_ITEMS.get([card, j], ""))
	return out


static func tooltip(id: String) -> String:
	if not ITEMS.has(id):
		return "빈 아이템 슬롯"
	return "%s\n%s" % [ITEMS[id]["name"], ITEMS[id]["desc"]]
