## 의뢰(= 런 1회) 데이터. 의뢰인 1명 = 스테이지 묶음 1개 (docs/네러티브_의뢰인01_왕관의_성.md).
## 전투 규칙은 기존 스테이지 1..N 을 그대로 쓰고, 여기에는 이름·대사·별명 같은 '의미'만 적는다.
## 등장인물(말하는 사람)도 여기 CAST 에 모은다: 이름·색·초상. 이름이 미정이라 역할로 부른다 (기획서 5장).
class_name CaseData
extends RefCounted

const CUTIN := "res://assets/textures/ult_cutin/"
const STANDING := "res://assets/textures/standing/"

## 말하는 사람. portrait: 대화 화면에 세우는 전신 그림, face: 그 그림에서 얼굴 중심(0..1, 말풍선 칩이 이 둘레를 오려 쓴다).
const CAST := {
	"chief": {"name": "반장", "color": Color(1.0, 0.42, 0.38), "portrait": STANDING + "char_02.png", "face": Vector2(0.47, 0.28), "face_r": 0.3},
	"knight": {"name": "기사", "color": Color(0.45, 0.66, 1.0), "portrait": CUTIN + "portrait_knight.png", "face": Vector2(0.5, 0.3), "face_r": 0.26},
	"gunner": {"name": "건너", "color": Color(1.0, 0.55, 0.74), "portrait": CUTIN + "portrait_gunner.png", "face": Vector2(0.52, 0.3), "face_r": 0.26},
	"mage": {"name": "마법사", "color": Color(0.74, 0.56, 1.0), "portrait": CUTIN + "portrait.png", "face": Vector2(0.5, 0.3), "face_r": 0.26},
	"healer": {"name": "힐러", "color": Color(0.62, 0.92, 0.6), "portrait": CUTIN + "portrait_healer.png", "face": Vector2(0.5, 0.3), "face_r": 0.26},
	"client": {"name": "하린", "color": Color(0.5, 0.92, 0.95), "portrait": "", "face": Vector2(0.5, 0.5), "face_r": 0.5},
	"boss": {"name": "1등의 왕관", "color": Color(1.0, 0.8, 0.3), "portrait": "", "face": Vector2(0.5, 0.5), "face_r": 0.5},
	"system": {"name": "접수 단말", "color": Color(0.5, 0.92, 0.95), "portrait": "", "face": Vector2(0.5, 0.5), "face_r": 0.5},
}

const CASES := {
	"harin": {
		"no": 1,
		"client": "윤하린",
		"age": "18세 · 학생회장",
		"title": "왕관의 성",
		"worry": "1등이 아니면, 아무것도 아닌 것 같아요.",
		"note": "제가 왜 여기 왔는지 잘 모르겠어요.\n그냥, 머릿속이 너무 시끄러워요.",
		"loading": "윤하린 님의 마음에 접속하는 중",
		"place_sub": "윤하린의 마음",
		# 방 = 기존 스테이지 1..5. enter: 도착 대사, clear: 클리어 리액션(여럿이면 무작위)
		"rooms": [
			{"name": "성문", "enter": ["chief", "자, 오늘 정리할 집은 여기예요. 신발은 벗고 들어가요."],
				"clear": [["chief", "이 정도면 한 방 끝. 정수는 하린 씨 마음 조각이에요. 주워 둬요."]]},
			{"name": "새벽 4시의 책상", "enter": ["mage", "공책이 여섯 권 펼쳐져 있네요. 다 오늘 거래요."],
				"clear": [["knight", "좋아, 책상 정리 끝! 다음!"], ["gunner", "형광펜이 네 가지 색이에요. 다 닳았고."]]},
			{"name": "게시판 앞 복도", "enter": ["gunner", "1등 옆에 이름이 있는데… 왜 본인은 2등 칸만 보고 있죠?"],
				"clear": [["chief", "저쪽은 다음에 봐요. 한 번에 다 못 치워요."], ["mage", "…복도가 좀 조용해졌네요."]]},
			{"name": "텅 빈 동아리방", "enter": ["healer", "여긴 먼지만 쌓였어요. …근데 이 기타는 줄이 새 거예요."],
				"clear": [["healer", "위에서 누가 계속 소리치고 있어요."], ["knight", "어디든 좋아. 다 치우면 되지!"]]},
			{"name": "왕좌의 방", "enter": ["chief", "제일 큰 응어리예요. 부수지 말고, 진정시켜요."],
				"clear": [["chief", "이거, 처음 1등 했을 때 받은 거래요. 그때는 그냥… 기뻤대요."]]},
		],
		# 엉킨 생각: 적 type → 별명 + 등장 한마디 (처음 만날 때 안내 띠로 소개)
		"tangles": {
			"normal": ["해야 하는데…", "아직 안 끝났잖아"],
			"fast": ["조급함", "빨리빨리! 벌써 늦었어!"],
			"skirmisher": ["수군거림", "회장이 저것도 못 해?"],
			"tank": ["완벽한 계획표", "5분 단위로 지켜."],
			"crab": ["굳은 다짐", "절대 안 놓을 거야."],
			"longneck": ["내려다보는 눈", "다 보고 있어."],
			"wraith": ["지난 실수", "그때 왜 그랬어?"],
		},
		"boss": {"name": "1등의 왕관", "alias": "2등은 꼴찌랑 똑같아",
			"shouts": ["아직 부족해!", "쉬면 다 따라잡혀!", "…날 벗으면, 넌 아무것도 아니잖아."]},
		# 의뢰 완료 뒤: 마지막 문 대화 → 기억 로그 3장
		"door": [
			["client", "…이 문은 제가 열어도 돼요?"],
			["healer", "그럼요. 여긴 하린 씨 집인걸요."],
		],
		"ending": [
			{"tag": "MEMORY LOG 01", "icon": "crown", "text": "낡은 소파와 기타.\n종이 왕관을 소파 위에 살며시 내려놓는다."},
			{"tag": "MEMORY LOG 02", "icon": "plan", "text": "아침, 책상.\n계획표 맨 아래에 연필로 한 줄.\n「토요일 — 합주」"},
			{"tag": "MEMORY LOG 03", "icon": "phone", "text": "\"이번 주에 떡볶이 먹을래? 할 얘기 있어.\"\n\"ㅇㅋㅋ 드디어!!\""},
		],
		"ending_line": ["chief", "다 치운 건 아니에요. 그래도 이제 걸려 넘어지진 않을 거예요."],
		"defeat_line": ["chief", "오늘 상담은 여기까지! 하린 씨, 다음 주에 또 봬요."],
		"revisit_line": ["client", "…또 와 주셨네요."],
		"postcard": "덕분에 토요일이 생겼어요.\n합주, 보러 오실래요?\n— 하린",
		# 유물 = 좋은 기억 (보상 카드를 고르면 한 줄이 뜬다)
		"memories": {
			"thunder_shard": "축제 기획 회의에서 내 아이디어에 다들 '오!' 했던 순간.",
			"ember": "첫 합주가 끝났을 때 손끝에 남아 있던 찌릿한 열기.",
			"frost_crystal": "시험 끝난 날, 친구랑 눈 맞으면서 먹은 아이스크림.",
			"essence_vial": "동아리 애들이 몰래 써 준 롤링페이퍼. '회장 고마워'.",
			"star_feather": "꼴찌로 들어온 운동회 날, 아빠가 해 준 말. '끝까지 뛰었네.'",
		},
	},
}
const CASE_ORDER := ["harin"]

## 다음 의뢰 예고 (허브의 잠긴 카드).
const NEXT_TEASER := {"no": 2, "note": "밤마다 같은 무대에 서는 꿈을 꿔요.\n막이 오르면 목소리가…", "status": "접수 대기 · 준비 중"}

## 분대 프로필 (허브 [분대] 탭): 좋아하는 것 / 싫어하는 것 / 한마디.
const PROFILES := {
	"knight": {"role": "전열 · 가로막기", "like": "갓 지은 밥, 큰 소리로 하는 인사", "hate": "애매한 대답", "line": "\"일단 들어가 보자. 치우다 보면 보여!\""},
	"gunner": {"role": "후열 · 연사", "like": "숫자, 영수증 정리", "hate": "틀린 그림 찾기에서 지는 것", "line": "\"지우개 자국이 세 군데. 많이 고쳐 썼네요.\""},
	"mage": {"role": "후열 · 광역", "like": "조용한 새벽, 식은 홍차", "hate": "알람 소리", "line": "\"…시끄러운 건 질색이라서요.\""},
	"healer": {"role": "지원 · 회복", "like": "햇볕에 말린 이불", "hate": "\"괜찮아요\"라는 거짓말", "line": "\"다 치우진 않아도 돼요. 걸려 넘어지지 않을 만큼만.\""},
}

## 로딩 화면 팁 (무작위 한 줄).
const TIPS := [
	"궁극기 게이지가 차면 분대 카드가 타오릅니다. 카드를 누르거나 Z · X · C · V.",
	"기사를 앞줄에 세우면 뒷줄이 오래 버팁니다.",
	"기억 조각(유물)은 성좌판에 끼워야 발동합니다.",
	"보스가 별을 띄우며 노리면, 강조된 영웅의 궁극기 키로 받아칠 수 있습니다.",
	"전멸해도 괜찮아요. 시간의 결정은 남고, 상담은 다음 회기로 이어집니다.",
	"배치 단계에 분대 카드를 누르면 스킬창이 열립니다.",
	"증폭 패널 위에 선 영웅은 공격과 치유가 강해집니다.",
]


static func get_case(id: String) -> Dictionary:
	return CASES.get(id, {})


static func room_count(id: String) -> int:
	return (CASES[id]["rooms"] as Array).size()


static func cast(who: String) -> Dictionary:
	return CAST.get(who, CAST["system"])


static func random_tip() -> String:
	return TIPS[randi() % TIPS.size()]
