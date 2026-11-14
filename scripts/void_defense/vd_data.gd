## VOID DEFENSE 그레이박스 — 상수·데이터·좌표 변환.
## 수치는 데모(GridDefenseGame_share.html)의 UNIT_TYPES / createEnemy / getScalingMultiplier 를 기준으로 가져왔다.
class_name VDData
extends RefCounted
const GameFonts := preload("res://scripts/game_fonts.gd")

## 타일 크기 배율: 캐릭터 크기는 그대로 두고 칸만 키워 유닛 사이를 띄운다 (1.0 은 오밀조밀했다, 2026-11-07).
## 칸 크기를 기준으로 잡은 픽셀 상수(보드 옆면 높이, 카메라 포커스 거리 등)도 이 배율을 곱한다.
const TILE_SCALE := 1.3
const TILE_W := 128.0 * TILE_SCALE
const TILE_H := 64.0 * TILE_SCALE

## 스테이지·웨이브 (TrioChess 무리 → 서브웨이브 이식, 2026-11-08): 방 하나가 스테이지 하나이고, 그 안에서 웨이브가 차례로 밀려온다.
##   stage         : 몇 번째 방인지 (1부터)
##   wave_in_stage : 스테이지 안 몇 번째 웨이브인지 (1..waves_in_stage)
##   wave          : 전체 누적 웨이브 번호 — 적 스탯 배율(scaling)·증원·오염 같은 난이도 지표
## 웨이브 사이엔 회복·재배치 없이 SUBWAVE_DELAY 뒤 다음 웨이브가 균열에서 내려앉는다. 스테이지의 마지막 웨이브를 치우면 구역 클리어.
const WAVES_PER_STAGE := 3        # 스테이지 2부터
const FIRST_STAGE_WAVES := 2      # 첫 스테이지는 짧게
const BOSS_EVERY := 5             # 이 배수 스테이지의 마지막 웨이브에 공허 군주
const SUBWAVE_DELAY := 0.8        # 웨이브 전멸 → 다음 웨이브 (실제 초, TrioChess SUBWAVE_DELAY)
## 기믹 무리 (TrioChess GIMMICKS): 스테이지 GIMMICK_FROM_STAGE 부터 GIMMICK_CHANCE 확률로 스테이지의 웨이브 하나가 기믹 무리로 바뀐다.
## 보스 스테이지의 마지막 웨이브는 바뀌지 않는다.
const GIMMICK_FROM_STAGE := 2
const GIMMICK_CHANCE := 0.45

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
## 2026-11-13: 고유 스킬·궁극기가 너무 자주 나와 필요량을 2배(100 → 200)로 올렸다. 공격·피격·패링·유물로 차는 양은 그대로라 모든 충전 경로가 절반 속도가 된다.
const MAX_MANA := 200.0

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
const MAX_ULT := 200.0   # 2026-11-13: 100 → 200 (MAX_MANA 와 같은 이유)
const ULT_PER_HURT := 100.0
const ULTS := {
	"knight": {"name": "충격파", "desc": "모든 적에게 큰 피해를 주고 한 칸 밀어내며 0.5초간 공중에 띄운다. 떨어진 적은 잠시 기절한다.", "aim": "",
		"dmg": 2.0, "air": 0.5, "stun": 1.0, "gain": 18.0},
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
	## 머리·몸통·팔 파츠 리그 (VDRig.PARTS_ART + VDPartsAnim). 단단한 껍질의 근접 강타형: 느리게 들어 올려 세게 찍는다.
	"crab":   {"name": "공허 수정게", "color": Color(0.5, 0.24, 0.72), "hp": 150, "atk": 11, "range": 1, "atk_cd": 1.7, "move_cd": 1.1, "move_sec": 0.3, "armor": 0.2, "essence": 9, "tier": 1},
	## size 2: 2x2 칸을 차지하는 대형 적 (cell 은 footprint 의 최소 꼭짓점). 머리의 쌍포로 멀리서 포격한다.
	"longneck": {"name": "공허 망루", "color": Color(0.3, 0.24, 0.36), "hp": 300, "atk": 14, "range": 3, "atk_cd": 2.2, "move_cd": 2.1, "move_sec": 0.55, "armor": 0.2, "essence": 18, "tier": 1, "size": 2},
	## 중보스 (size 2 = 4칸, 파츠 + 본 리그: VDWraithAnim). 사거리가 아주 길고, 가끔 아군에게서 가장 먼 자리로 순간이동해 쏜다.
	## float: 타일에 묶이지 않고 방 위를 위빙하며 떠다닌다 (VDFloatMove) — 다른 유닛과 겹칠 수 있고, 칸은 떠 있는 위치에서 매 틱 구한다.
	## 스킬 공허 촉수 난타 (ENEMY_SKILLS). 3의 배수 + 1 스테이지의 마지막 웨이브에 나온다 (is_wraith_stage).
	"wraith": {"name": "공허 망령", "color": Color(0.45, 0.2, 0.7), "hp": 360, "atk": 13, "range": 7, "atk_cd": 2.1, "move_cd": 1.9, "move_sec": 0.5, "armor": 0.1, "essence": 24, "tier": 1, "size": 2, "float": true},
	## 보스 (size 2 = 4칸, 컨셉 assets/컨셉 원화/보스몹 컨셉.psd): 떠 있는 눈에서 원거리 광탄을 쏘고, [패링 공격]을 예고한다 (PARRY).
	## 5·15·25… 스테이지의 마지막 웨이브 (is_watcher_stage). 10·20… 은 공허 군주.
	"watcher": {"name": "공허 감시자", "color": Color(0.62, 0.3, 0.86), "hp": 520, "atk": 16, "range": 4, "atk_cd": 1.9, "move_cd": 1.7, "move_sec": 0.45, "armor": 0.1, "essence": 44, "boss": true, "tier": 2, "size": 2},
	## 첫 보스 (size 2 = 4칸, 원화 assets/컨셉 원화/첫 보스.png → 파츠 + 본 리그: VDGazerAnim). 눈 14개가 저마다 굴러다니는 초승달 몸에 날개.
	## 떠다니며(float) 큰 눈에서 광탄을 쏘고, [패링 공격] 월식 돌진: 2초 동안 날개를 격렬히 퍼덕이며 물러났다가 아래쪽 뿔로 들이받는다 (PARRY style "ram").
	## 5·25·45… 스테이지의 마지막 웨이브 (is_gazer_stage).
	"gazer": {"name": "공허 응시자", "color": Color(0.74, 0.42, 0.86), "hp": 500, "atk": 15, "range": 4, "atk_cd": 2.0, "move_cd": 1.7, "move_sec": 0.45, "armor": 0.1, "essence": 44, "boss": true, "tier": 2, "size": 2, "float": true, "zoom": 0.7},
	"boss":   {"name": "공허 군주", "color": Color(0.06, 0.03, 0.11), "hp": 400, "atk": 18, "range": 2, "atk_cd": 1.5, "move_cd": 1.3, "move_sec": 0.36, "essence": 40, "boss": true, "tier": 2},
	## 기믹 무리 전용 (TrioChess goblin/ninja/splitter/sprinter/hydra/illusionist 를 공허 몬스터로). 수치는 TrioChess 기준에
	## VD 잔재(35/8 → 90/6) 비율을 곱했다. 전용 원화가 올 때까지 기존 원화를 배율·틴트만 바꿔 쓴다 (VDRig.ENEMY_ALIAS).
	## 행동은 VDGimmicks: swarm 물량 · assassin 가장 먼 영웅 곁으로 도약 · splitter 사망 시 splitling 2 · sprinter 2칸 질주
	##                   hydra 2초 뒤 부활(동시 처치 필요) · illusion 은 illusionist 가 살아 있는 동안 무적
	"swarm":    {"name": "잔재 떼", "color": Color(0.2, 0.12, 0.26), "hp": 56, "atk": 5, "range": 1, "atk_cd": 0.85, "move_cd": 0.52, "move_sec": 0.14, "essence": 3},
	"assassin": {"name": "균열 암살자", "color": Color(0.5, 0.1, 0.5), "hp": 46, "atk": 10, "range": 1, "atk_cd": 0.9, "move_cd": 1.0, "move_sec": 0.2, "essence": 7},
	"splitter": {"name": "분열 잔재", "color": Color(0.18, 0.1, 0.24), "hp": 140, "atk": 7, "range": 1, "atk_cd": 1.35, "move_cd": 1.15, "move_sec": 0.3, "essence": 8},
	"splitling": {"name": "소잔재", "color": Color(0.22, 0.14, 0.28), "hp": 31, "atk": 4, "range": 1, "atk_cd": 0.9, "move_cd": 0.85, "move_sec": 0.2, "essence": 2},
	"sprinter": {"name": "공허 추적자", "color": Color(0.42, 0.16, 0.5), "hp": 72, "atk": 7, "range": 1, "atk_cd": 0.9, "move_cd": 0.76, "move_sec": 0.18, "essence": 6},
	"hydra":    {"name": "공허 촉수", "color": Color(0.3, 0.1, 0.4), "hp": 128, "atk": 8, "range": 1, "atk_cd": 1.2, "move_cd": 1.0, "move_sec": 0.25, "essence": 10},
	"illusionist": {"name": "공허 환술사", "color": Color(0.7, 0.2, 0.7), "hp": 205, "atk": 9, "range": 1, "atk_cd": 1.0, "move_cd": 0.9, "move_sec": 0.24, "essence": 14, "tier": 1},
	"illusion": {"name": "환영", "color": Color(0.5, 0.3, 0.6), "hp": 102, "atk": 9, "range": 1, "atk_cd": 1.0, "move_cd": 0.9, "move_sec": 0.24, "essence": 3, "ghostly": true},
}

## 기믹 무리 (TrioChess waves.gd GIMMICKS + 안내문). pack 이 그 웨이브의 구성 전부다.
const GIMMICKS := {
	"swarm_raid":    {"name": "잔재 떼 습격", "hint": "작고 빠른 잔재가 떼로 몰려옵니다. 광역기로 쓸어버리세요.",
		"pack": ["skirmisher", "skirmisher", "swarm", "swarm", "swarm", "swarm", "swarm", "swarm"]},
	"assassin_raid": {"name": "균열 암살자 습격", "hint": "암살자는 가장 먼 영웅 곁으로 균열을 타고 뛰어듭니다. 후열을 지키세요.",
		"pack": ["skirmisher", "assassin", "assassin", "assassin"]},
	"splitter_raid": {"name": "분열 잔재 습격", "hint": "분열 잔재는 쓰러지면 둘로 갈라집니다. 소잔재까지 마무리하세요.",
		"pack": ["skirmisher", "splitter", "splitter", "splitter", "splitter"]},
	"sprinter_raid": {"name": "공허 추적자 습격", "hint": "추적자는 두 칸씩 질주해 붙습니다. 다가오기 전에 쓰러뜨리세요.",
		"pack": ["skirmisher", "sprinter", "sprinter", "sprinter"]},
	"hydra":         {"name": "공허 촉수", "hint": "촉수는 2초 뒤 더 강해져 되살아납니다. 네 머리를 동시에 꺾어야 합니다.",
		"pack": ["hydra", "hydra", "hydra", "hydra"]},
	"illusionist":   {"name": "공허 환술사", "hint": "환술사가 살아 있는 동안 환영은 무적입니다. 진짜를 먼저 찾으세요.",
		"pack": ["illusionist", "illusion", "illusion", "illusion", "illusion"]},
}
const GIMMICK_ORDER := ["swarm_raid", "assassin_raid", "splitter_raid", "sprinter_raid", "hydra", "illusionist"]

## 영웅 성장 (TrioChess main.gd grant_exp/_level_up 이식): 처치한 영웅이 EXP_PER_KILL × (1 + 적 tier) 를 받고,
## 나머지 살아 있는 영웅은 그 EXP_SHARE 배를 나눠 받는다 (VD 추가: 처치가 드문 힐러·기사가 굶지 않게).
## 레벨 L → L+1 에 exp_need(L) 가 필요하고 남는 경험치는 이월된다. 레벨업마다 체력·공격력이 오르고 SP 1 — 스킬창(VDSkillWindow)에서 쓴다.
## 레벨 속도: 첫 시험(2026-11-08)에서 EXP_SHARE 0.35 · 필요치 40L 로는 두 스테이지 만에 Lv4~5 가 되어 TrioChess(지역 10무리에 Lv5~6)의
## 두 배쯤 빨랐다. 나눠 받는 비율을 줄이고 필요치를 올려 스테이지 둘에 Lv3 안팎이 되게 했다.
## 2026-11-09: 그래도 너무 빠르다는 사용자 요청으로 필요치를 3배(50L → 150L): 같은 경험치로 레벨업이 3배 늦다.
const EXP_PER_KILL := 25
const EXP_SHARE := 0.25
const LEVEL_HP := 15
const LEVEL_ATK := 8
const LEVEL_HEAL := 30
const SP_PER_LEVEL := 1
const SKILL_MAX := 5             # 스킬 최대 레벨 (TrioChess BOOK_MAX)
const SKILL_SLOTS := 4


static func exp_need(level: int) -> int:
	return level * 150


## 영웅별 스킬 4칸 (TrioChess 스킬북 테이블에서 역할에 맞는 것을 고르고, 고유 스킬·궁극기 숙련을 앞 두 칸에 두었다).
## fx 는 레벨당 수치이고 레벨 × fx 가 더해진다 (VDGrowth.fx). 칸 순서가 스킬창의 줄 순서다.
##   active_mult  고유 스킬 피해·회복 배율 +      active_stun / active_freeze  고유 스킬 기절·빙결 초 +     active_count  다중 사격 대상 + (내림)
##   ult_dmg      궁극기 피해·회복 배율 +         ult_stun  충격파 기절 +    ult_bounces  체인 튕김 + (내림)   ult_revive  부활 체력 비율 +
##   dmg_reduce   받는 피해 -  (최대 0.75)        bonus_hp  최대 체력 +      atk_speed  공격 간격 ÷ (1+x)     crit  치명타 확률 +
##   dmg_bonus    평타 피해 +                     freeze_chance  평타 빙결 확률 +(0.6초)   heal_bonus  회복량 +   mana_mult  마나 획득 +
const HERO_SKILLS := {
	"knight": [
		{"id": "assault_mastery", "name": "강습 숙련", "desc": "용맹한 강습 피해 +25%, 기절 +0.2초", "fx": {"active_mult": 0.25, "active_stun": 0.2}},
		{"id": "quake_mastery", "name": "충격파 숙련", "desc": "충격파 피해 +20%, 기절 +0.15초", "fx": {"ult_dmg": 0.2, "ult_stun": 0.15}},
		{"id": "iron_wall", "name": "철벽", "desc": "받는 피해 -5%", "fx": {"dmg_reduce": 0.05}},
		{"id": "vitality", "name": "생명력", "desc": "최대 체력 +30", "fx": {"bonus_hp": 30.0}},
	],
	"gunner": [
		{"id": "volley_mastery", "name": "다중 사격 숙련", "desc": "다중 사격 피해 +10%, 3·5레벨에 대상 +1", "fx": {"active_mult": 0.1, "active_count": 0.4}},
		{"id": "barrage_mastery", "name": "집중 포화 숙련", "desc": "집중 포화 피해 +20%", "fx": {"ult_dmg": 0.2}},
		{"id": "rapid_fire", "name": "속사", "desc": "공격 속도 +6%", "fx": {"atk_speed": 0.06}},
		{"id": "critical", "name": "치명타", "desc": "치명타 확률 +6%", "fx": {"crit": 0.06}},
	],
	"mage": [
		{"id": "frost_mastery", "name": "절대 영도 숙련", "desc": "절대 영도 피해 +25%, 빙결 +0.2초", "fx": {"active_mult": 0.25, "active_freeze": 0.2}},
		{"id": "storm_lord", "name": "번개 군주", "desc": "체인 라이트닝 피해 +15%, 2·4레벨에 튕김 +1", "fx": {"ult_dmg": 0.15, "ult_bounces": 0.5}},
		{"id": "arcane", "name": "마력 증폭", "desc": "평타 피해 +7%", "fx": {"dmg_bonus": 0.07}},
		{"id": "freeze", "name": "빙결", "desc": "평타 빙결 확률 +7% (0.6초)", "fx": {"freeze_chance": 0.07}},
	],
	"healer": [
		{"id": "blessing_mastery", "name": "축복 숙련", "desc": "생명의 축복 회복량 +25%", "fx": {"active_mult": 0.25}},
		{"id": "prayer_mastery", "name": "기도 숙련", "desc": "부활 체력 +10%, 전체 회복 +15%", "fx": {"ult_revive": 0.1, "ult_dmg": 0.15}},
		{"id": "grace", "name": "은총", "desc": "회복량 +10%", "fx": {"heal_bonus": 0.1}},
		{"id": "mana_flow", "name": "마나 순환", "desc": "마나 획득 +12%", "fx": {"mana_mult": 0.12}},
	],
}

## 적 특수 스킬 (VDEnemySkills). first: 전투 시작 후 첫 시전까지(초), cd: 이후 재사용 대기(초). 피해는 atk 배수.
const ENEMY_SKILLS := {
	## 공허 망루 공허 섬광포: charge 초 충전 → dur 초 동안 레이저를 쏘며 hits 번 연타. 사정거리 range 안에 아군이 있을 때만.
	"longneck": {"name": "공허 섬광포", "first": 4.0, "cd": 8.0, "charge": 0.6, "dur": 1.5, "hits": 10, "dmg": 0.5, "range": 4},
	## 공허 군주 공허 강하: 체력이 가장 낮은 아군 옆으로 순간이동해 내려찍는다. 대상 피해 dmg, 주변 1칸 splash, 대상 기절 stun.
	## 공허 망령 공허 촉수 난타: charge 초 예비 → 촉수 tentacles 개가 뻗어 나와 각자 jabs 번씩 찌른다 (한 번에 atk × dmg).
	## min_range: 가장 가까운 아군이 이 칸 수보다 가까우면 쓰지 않는다 — 먼저 그만큼 물러난 뒤(VDFloatMove.back_off) 쓴다.
	## blink_*: 순간이동 — 아군에게서 가장 먼 자리로 옮긴 뒤 곧바로 쏜다 (스킬과 따로 도는 재사용 대기).
	##          옮긴 뒤 blink_skill 확률로 쏘는 대신 촉수 난타를 바로 쓴다.
	## dodge: 강한 공격(영웅 궁극기, 또는 최대 체력의 dodge_ratio 이상인 고유 스킬 피해)을 맞는 순간 이 확률로 순간이동해 피한다.
	##        기절·시전 중에는 피하지 못한다.
	"wraith": {"name": "공허 촉수 난타", "first": 6.0, "cd": 10.0, "charge": 0.55, "tentacles": 7, "jabs": 3, "dmg": 0.22, "range": 16, "min_range": 3,
		"blink_first": 3.0, "blink_cd": 7.0, "blink_skill": 0.5, "dodge": 0.75, "dodge_ratio": 0.1},
	"boss": {"name": "공허 강하", "first": 5.0, "cd": 9.0, "charge": 0.5, "hang": 0.28, "dmg": 2.2, "splash": 1.0, "stun": 0.7},
}

## 패링 공격 (VDParry): 보스가 영웅 하나를 노려 예고(눈에서 별이 터진다)하고, window 초(게임 시간) 뒤 일격이 들어간다.
## 그 전에 노려진 영웅의 궁극기 단축키(카드 탭)를 누르면 받아친다 — 궁극기 게이지와 상관없다.
##   first / cd : 전투 시작 후 첫 예고까지 / 이후 간격 (초).   eye : 예고 별이 놓이는 높이 (비주얼 키 대비 비율).
##   실패: 대상에게 atk × dmg 피해 + stun 초 기절.
##   성공: 보스에게 영웅 atk × counter + 보스 최대 체력 × counter_hp 피해, stagger 초 무력화(기절), 영웅 궁극기 게이지 + ult_gain.
const PARRY := {
	"watcher": {"name": "섬멸 일섬", "first": 5.0, "cd": 8.5, "window": 1.05, "eye": 0.73, "dmg": 2.6, "stun": 1.0,
		"counter": 3.0, "counter_hp": 0.05, "stagger": 2.4, "ult_gain": 30.0},
	## press: 입력을 받는 시간 — 일격 직전 이만큼만 (없으면 예고 내내). 그 전에 누르면 "너무 빨라!" 와 함께 0.5초 잠긴다.
	##        0.45초 = 날개를 치켜들고 멈칫하는 순간(VDGazerAnim coil)부터 돌진까지. 열릴 때 대상 머리 위에 "지금!".
	## style "ram": 예고 동안 대상에게서 물러났다가(VDFloatMove.retreat) 일격 순간 뿔로 돌진한다 (VDParry._ram_dash). eye_x: 예고 별의 가로 치우침(px, 바라보는 쪽).
	"gazer": {"name": "월식 돌진", "first": 6.0, "cd": 10.0, "window": 2.0, "press": 0.45, "eye": 0.67, "eye_x": 50.0, "dmg": 2.8, "stun": 1.0,
		"counter": 3.0, "counter_hp": 0.05, "stagger": 2.6, "ult_gain": 30.0, "style": "ram"},
	"boss": {"name": "공허 참격", "first": 8.0, "cd": 11.0, "window": 1.05, "eye": 0.62, "dmg": 2.2, "stun": 0.8,
		"counter": 3.0, "counter_hp": 0.05, "stagger": 2.0, "ult_gain": 30.0},
}

## 공허 응시자의 공격 패턴 다섯 가지 (VDGazerSkills). 평타(눈 광탄)와 따로, first 초 뒤부터 gap 초 간격으로 하나씩 돌려 쓴다
## (다섯 개를 섞어 한 바퀴 돌고 다시 섞는다 — 같은 패턴이 연달아 나오지 않는다). 피해는 atk 배수.
##   ram     월식 돌진 (패링 1): PARRY["gazer"] 그대로 — 날아올라 물러났다가 뿔로 내리꽂는다.
##   beam    만안 섬광 (패링 2): 제자리에서 두 팔을 벌려 눈에 빛을 모았다가 광선을 쏜다. 받아치면 광선이 되돌아간다.
##   barrage 깃털 폭우: 날개를 치켜들고 깃털 shots 발을 gap 초 간격으로 쏜다. 바닥 경고 원이 fall 초 뒤 터진다 (반경 radius px).
##   gale    날개 폭풍: 치켜든 날개를 내리쳐 range 칸 안의 영웅을 전부 air 초 띄운다.
##   sweep   초승달 선회: 톱날처럼 돌며 경고선을 따라 dash 초 만에 가로지른다. 선 가까이(width px) 있으면 피해 + stun 초 기절.
const GAZER := {
	"first": 3.5, "gap": [3.0, 4.4], "order": ["barrage", "ram", "gale", "beam", "sweep"],
	"beam": {"name": "만안 섬광", "window": 1.8, "press": 0.42, "eye": 0.67, "eye_x": 50.0, "dmg": 2.4, "stun": 0.8,
		"counter": 2.6, "counter_hp": 0.04, "stagger": 2.2, "ult_gain": 30.0, "style": "beam"},
	"barrage": {"name": "깃털 폭우", "charge": 0.7, "shots": 9, "gap": 0.12, "fall": 0.6, "dmg": 0.5, "radius": 64.0},
	"gale": {"name": "날개 폭풍", "charge": 0.95, "dmg": 0.6, "air": 0.6, "range": 7},
	"sweep": {"name": "초승달 선회", "charge": 0.9, "dash": 0.4, "dmg": 1.3, "stun": 0.4, "width": 84.0, "reach": 300.0},
}

## 사망 슬로모션 [실시간 초, 시간 배율]. 적은 ENEMIES 의 tier(0 기본 · 1 중간급 · 2 보스급), 아군은 중간급과 같다.
const DEATH_SLOWMO := [[0.18, 0.4], [0.4, 0.3], [0.9, 0.2]]
const ALLY_DEATH_TIER := 1

## UI 본문 글꼴 (scripts/game_fonts.gd 의 "본문" 역할). 설정 [글꼴 바꾸기] 로 바꾸면 이 객체 안의 글꼴만 바뀐다.
## 기본값은 시스템 맑은 고딕 (Godot 기본 폰트는 한글 글리프가 없다).
static func font() -> Font:
	return GameFonts.body()


## 적 체력 배율 — 공격력은 아래 atk_scaling (TrioChess defs.gd scaling: 1.07^(wave-1), 기본 배율은 1). 누적 웨이브 기준이라
## 스테이지(웨이브 3개)마다 약 ×1.23, 보스 스테이지 다섯마다 약 ×2.8. 이전 데모 공식(웨이브당 +15%)은 웨이브가 방마다 셋이 되며 너무 가팔라 바꿨다.
const SCALE_RATE := 1.07


static func scaling(wave: int) -> float:
	return pow(SCALE_RATE, maxi(1, wave) - 1)


## 적 공격력 배율 (2026-11-12 분리). 체력과 같은 지수 배율을 쓰면 적 수 증가(3→9)와 곱해져 받는 피해가
## 5스테이지 ×2.4 → 10스테이지 ×6.7 → 15스테이지 ×18 로 치솟아, 선형으로 크는 영웅 체력(레벨당 +15)이 어느 순간 한꺼번에 녹았다.
## 공격력은 웨이브마다 기본값의 ATK_RATE 씩 더하는 선형: 스테이지마다 +15%p (5스테이지 ×1.65, 10스테이지 ×2.4, 15스테이지 ×3.15).
const ATK_RATE := 0.05


static func atk_scaling(wave: int) -> float:
	return 1.0 + ATK_RATE * (maxi(1, wave) - 1)


static func waves_in_stage(stage: int) -> int:
	return FIRST_STAGE_WAVES if stage <= 1 else WAVES_PER_STAGE


static func is_boss_stage(stage: int) -> bool:
	return stage % BOSS_EVERY == 0


## 보스 스테이지 가운데 공허 감시자가 나오는 곳: 15, 35, 55 … (10, 20 … 은 공허 군주, 5, 25 … 는 공허 응시자).
static func is_watcher_stage(stage: int) -> bool:
	return is_boss_stage(stage) and (stage / BOSS_EVERY) % 4 == 3


## 첫 보스 공허 응시자가 나오는 곳: 5, 25, 45 …
static func is_gazer_stage(stage: int) -> bool:
	return is_boss_stage(stage) and (stage / BOSS_EVERY) % 4 == 1


## 대형 적(공허 망루)이 마지막 웨이브에 확정으로 나오는 스테이지 (wave_enemies 와 같은 규칙).
static func is_longneck_stage(stage: int) -> bool:
	return stage >= 3 and stage % 3 == 0 and not is_boss_stage(stage)


## 중보스 공허 망령이 마지막 웨이브에 확정으로 나오는 스테이지: 4, 7, 13, 16 … (망루 다음 스테이지, 보스 스테이지 제외).
static func is_wraith_stage(stage: int) -> bool:
	return stage >= 4 and stage % 3 == 1 and not is_boss_stage(stage)


## 어려운 스테이지: 보스 또는 대형 적이 확정인 스테이지 (석판 솟는 소리 선택용).
static func is_hard_stage(stage: int) -> bool:
	return is_boss_stage(stage) or is_longneck_stage(stage) or is_wraith_stage(stage)


## 스테이지의 기믹 무리 추첨: "" 이면 없음. 결과는 [기믹 id, 몇 번째 웨이브] 이고 보스 스테이지의 마지막 웨이브는 피한다.
static func roll_gimmick(stage: int) -> Array:
	if stage < GIMMICK_FROM_STAGE or randf() >= GIMMICK_CHANCE:
		return ["", 0]
	var n := waves_in_stage(stage)
	var wi := 1 + randi() % n
	if is_boss_stage(stage) and wi == n:
		wi = 1
	return [GIMMICK_ORDER[randi() % GIMMICK_ORDER.size()], wi]


## 스테이지 stage 의 wi 번째 웨이브 구성. gimmick 이 있으면 그 무리 그대로.
## 일반 웨이브: 수는 스테이지와 웨이브 순서에 따라 3~9 (TrioChess 3 + 0.5w 를 스테이지 단위로),
## 첫 두 스테이지에서 특수 적(파편·포자·결정체, 2스테이지에 수정게)을 하나씩 소개하고, 그 뒤로는 섞어 낸다.
## 스테이지의 마지막 웨이브가 가장 세다: 결정체가 끼고(4스테이지↑), 3의 배수 스테이지엔 공허 망루, 보스 스테이지엔 공허 군주.
static func wave_enemies(stage: int, wi: int, gimmick := "") -> Array[String]:
	var list: Array[String] = []
	if gimmick != "" and GIMMICKS.has(gimmick):
		for t in GIMMICKS[gimmick]["pack"]:
			list.append(String(t))
		return list
	var n := waves_in_stage(stage)
	var last := wi >= n
	list.resize(clampi(3 + int(stage * 0.5) + (wi - 1), 3, 9))
	list.fill("normal")
	var specialists := ["fast", "skirmisher", "tank", "crab"]
	if stage == 1:
		list[0] = specialists[wi - 1]
	elif stage == 2:
		for i in mini(wi, specialists.size()):
			list[i] = specialists[(i + 2) % specialists.size()]
	else:
		list[0] = specialists[(stage * n + wi) % specialists.size()]
		for i in range(1, list.size()):
			var roll := randf()
			if roll < 0.16:
				list[i] = "fast"
			elif roll < 0.30:
				list[i] = "skirmisher"
			elif roll < 0.36:
				list[i] = "crab"
		if last and stage >= 4 and list[0] != "tank":
			list[1] = "tank"
		if last and is_longneck_stage(stage):
			list[list.size() - 1] = "longneck"
		if last and is_wraith_stage(stage):
			list[list.size() - 1] = "wraith"
	if last and is_boss_stage(stage):
		list.append("gazer" if is_gazer_stage(stage) else ("watcher" if is_watcher_stage(stage) else "boss"))
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
