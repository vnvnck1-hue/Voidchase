# 코덱스 요청 — 새 재화 5종 컨셉 원화 (v1)

작성일: 2026-11-11. 목적: 공허 정수 말고 새로 넣을 재화 후보 5종의 **컨셉 원화**. 사용자가 원화를 보고 어느 재화를 어떤 모양으로 넣을지 고른다. 아직 게임 리소스(아이콘 컷)가 아니라 **디자인 시안 시트**다.

Mode: built-in image_gen. 결과는 이 폴더(`docs/currency_concepts_v1/`)에 아래 파일 이름으로 저장.

참고 이미지 (첨부):
- `docs/essence_physics/0_settled.png` — 실제 게임 화면. 바닥의 보라 결정이 지금의 **공허 정수** 드롭. 새 재화는 이것과 색·실루엣이 한눈에 구분돼야 한다.
- `assets/컨셉 원화/화면 컨셉_2 복사.jpg` — 화면 컨셉. 굵은 검은 외곽선, 2~3톤 셀 음영, 채도 높은 팝 컬러, 보라·남색 우주 배경, SF 톤.
- `assets/textures/relic_ui/icon_money_swirl.png` — 기존 UI 아이콘 톤.

세계관: SF 판타지. 메이드 상담사들이 의뢰인의 마음속(공허에 침식된 기억의 방)에 들어가 공허 잔재를 치운다. 판타지 금화·마법진·룬 같은 중세 판타지 기호는 쓰지 않는다 (데이터 파편·홀로그램·에너지 코어·정밀 부품 같은 SF 기호).

## 시트 구성 (5장 공통)

16:9 가로 한 장, 어두운 남보라 단색 배경(투명 아님), 글자·라벨 없음. 한 장 안에:
1. **디자인 3안 (A·B·C)** — 위쪽에 큰 크기로 나란히. 같은 재화의 서로 다른 실루엣·색 해석.
2. 각 안 아래에 작게: **HUD 아이콘** (정면, 단순화) + **바닥 드롭** (등각 타일 위에 놓인 모습, 작은 크기) + **흡수 순간** (빛나며 흩어지는 상태).
3. 화면 구석에 비교용으로 지금의 보라 공허 정수 결정 하나를 작게.

## 재화 5종

| 파일 | 재화 | 역할 | 얻는 곳 | 디자인 방향 |
|---|---|---|---|---|
| `01_memory_shard.png` | 기억 조각 | 런 재화(희귀). 인장·유물 고정 리롤 | 정예·기믹 무리·보스 | 흰색·금색 데이터 파편, 별처럼 반짝임, 안에 흐릿한 추억 장면(사진 조각·필름 프레임) 비침. 따뜻하고 귀함 |
| `02_time_crystal.png` | 시간의 결정 | 영구 재화. 로비 상담소 강화·메이드 해금 | 런 종료 정산, 보스 소량 | 하늘색·청록 모래시계/시계 톱니가 결정 안에 갇힌 형태, 차분하고 단단함. 정수보다 크고 묵직 |
| `03_void_alloy.png` | 공허 합금 | 장비 재료 | 결정체·망루 등 갑옷 적 | 무광 짙은 쇳빛 + 주황·형광 노랑 발열선, 볼트·육각 너트·정밀 부품 덩어리. 공업적, 각짐 |
| `04_purifier.png` | 정화액 | 침식 칸 정화 전용 | 오염 타일 위 처치, 침식 근원 | 민트·하늘 물빛 액체가 든 캡슐/앰플, 안에 거품, 맑고 시원함. 오염(자홍·보라)과 정반대 색 |
| `05_instant_pickups.png` | 즉시 효과 드롭 | 줍는 순간 발동 (회복 구슬 / 궁극기 게이지 조각 / 잠깐 가속) | 일반 처치 낮은 확률 | 이 시트는 A·B·C 대신 **세 종류**를 나란히: 분홍 하트 회복 구슬, 노랑 번개 게이지 조각, 연두 화살표 가속 칩. 같은 패밀리로 보이게 공통 외형(둥근 캡슐 테두리) |

## Final prompt (재화마다 Subject 만 바꿔 5번)

Use case: game concept art sheet for a collectible currency pickup. Style must match the attached game screenshots exactly: bold near-black outlines, flat 2–3-tone cel shading, small crisp white highlights, saturated pop colors, cute chibi-tactics game look, sci-fi (data shards, holograms, energy cores, precision parts — NO medieval fantasy coins, runes or magic circles). 16:9 landscape sheet on a plain dark indigo-violet background, no text, no labels, no UI frames, no watermark.

Layout: top row — three large design variations (A, B, C) of the same item side by side, each a distinct silhouette and color interpretation. Under each variation, small: a simplified front-facing HUD icon version, the item lying on a small isometric lavender floor tile (as a dropped pickup, matching the floor tiles in the screenshot), and the item bursting into light at the moment it is collected. In one corner, small, for scale comparison: the existing purple void-essence crystal from the screenshot. The new item must be instantly distinguishable from that purple crystal by color and silhouette.

Subject: <재화별 영어 설명>
