# 판타지 성향 VFX 점검 (2026-11-09)

게임 컨셉이 사이파이로 정해지면서, 전투(VOID DEFENSE)·HUD에 남아 있는 **판타지(마법·신성·원소 마법) 느낌의 연출**을 전부 훑어 목록으로 만들었다.
스크린샷은 `docs/fantasy_vfx_audit/` 에 있고, 한눈에 보는 콘택트 시트는 `sheet_1.png`(마법진·회복·번개) · `sheet_2.png`(포털·구슬·유물) · `sheet_3.png`(깃털·정수·피격·검기·상태·카드) 세 장이다.
캡처 러너: `tools/test/FantasyVfxCapture.tscn` (창 필요, 서브 모니터). 각 장면은 전투 코드의 `vfx` 호출을 그대로 옮겨 재생했다.

조사 범위: `scripts/void_defense/**` 85개 스크립트, `shaders/*.gdshader` 17개, `assets/vfx/void_defense/` 시트 16장, 연출 연구실 모드 7종, 유물 투사체 5종, 상태 표시(`vd_unit.gd _draw_overlay`).

## 판정 요약

| 판정 | 뜻 |
|---|---|
| **교체** | 형태 자체가 마법/신성/원소 마법이라 사이파이와 충돌. 소스(시트·셰이더)를 바꿔야 한다 |
| **리스타일** | 현상(전기·폭발·검기)은 사이파이에도 있으니 색·재질·모양만 바꾸면 된다 |
| **유지** | 이미 사이파이거나 컨셉과 무관 |

---

## A. 교체 — 명백한 판타지

### 1. 룬 마법진 `magic_circle` (시트 `vr_magic_circle.png`) — 시트 1 · 1~4, 8번
- 육망성 + 룬 문자가 둘린 전형적인 마법진. 바닥에 납작하게 깔고 돌린다.
- 쓰는 곳 (8곳):
  - 힐러 **일반 회복마다** 발밑 — [vd_battle.gd:1561](../scripts/void_defense/vd_battle.gd:1561)
  - 힐러 스킬 생명의 축복: 시전자 큰 것 + 아군마다 작은 것 — [vd_skills.gd:196](../scripts/void_defense/vd_skills.gd:196), [vd_skills.gd:202](../scripts/void_defense/vd_skills.gd:202)
  - 마법사 스킬 절대 영도 (푸른색) — [vd_skills.gd:169](../scripts/void_defense/vd_skills.gd:169)
  - 힐러 궁극기 부활의 기도 (금색, 시전자 + 부활 자리) — [vd_ults.gd:257](../scripts/void_defense/vd_ults.gd:257), [vd_ults.gd:268](../scripts/void_defense/vd_ults.gd:268)
  - 강적 소환 예고 (자홍, 역회전) — [vd_summon_fx.gd:154](../scripts/void_defense/vd_summon_fx.gd:154) (`champ_circle_col` 이름도 "강적 마법진 색")
- 사이파이 대안: 홀로그램 타깃 링(얇은 원 + 눈금 + 회전하는 호), 육각 그리드 프로젝션, 스캔라인이 도는 원형 HUD. 셰이더로 그리면 색·크기 조절도 지금 호출 그대로 받을 수 있다.

### 2. 회복 반짝임 `heal` (시트 `vr_heal_sparkles.png`) — 시트 1 · 1, 2, 4' / 시트 3 · 15'
- 연두색 물방울·하트 모양 덩어리가 떠오르는 RPG 힐 이펙트.
- 쓰는 곳 (7곳): 힐러 일반 회복 [vd_battle.gd:1562](../scripts/void_defense/vd_battle.gd:1562), 생명의 축복 [vd_skills.gd:201](../scripts/void_defense/vd_skills.gd:201), 부활의 기도 [vd_ults.gd:266](../scripts/void_defense/vd_ults.gd:266)·[vd_ults.gd:275](../scripts/void_defense/vd_ults.gd:275), 구역 클리어 회복 [vd_battle.gd:1145](../scripts/void_defense/vd_battle.gd:1145), 유물 별 깃털 보호막 [vd_relic_runtime.gd:241](../scripts/void_defense/relics/vd_relic_runtime.gd:241), 연구실 [vd_fx_lab.gd:406](../scripts/void_defense/vd_fx_lab.gd:406)
- 대안: 나노봇 입자가 몸을 훑고 올라가는 스캔, 육각 셀이 패치처럼 붙었다 사라짐, 수직 스캔 바 + 숫자.

### 3. 하늘 낙뢰 `lightning` (시트 `vr_lightning_bolt.png`) — 시트 1 · 3', 4', 5, 6, 7 / 시트 2 · 9', 10, 12'
- 하늘에서 내리꽂히는 번개. 신벌·소환·부활 같은 "하늘에서 내려오는 힘" 문법이라 판타지 색이 강하다. 가장 많이 재사용되는 시트다.
- 쓰는 곳 (9곳):
  - 마법사 **절대 영도** 적중 — 얼음 스킬인데 번개 시트를 쓴다 [vd_skills.gd:187](../scripts/void_defense/vd_skills.gd:187)
  - 체인 라이트닝 마지막 적 [vd_ults.gd:209](../scripts/void_defense/vd_ults.gd:209)
  - 부활의 기도 (금색) [vd_ults.gd:265](../scripts/void_defense/vd_ults.gd:265)
  - 영웅 전투불능 (붉은색) [vd_battle.gd:1065](../scripts/void_defense/vd_battle.gd:1065)
  - 레벨업 (금색 기둥) [vd_battle.gd:1692](../scripts/void_defense/vd_battle.gd:1692)
  - 강적 착지 [vd_summon_fx.gd:164](../scripts/void_defense/vd_summon_fx.gd:164)
  - 보스 공허 강하 [vd_enemy_skills.gd:239](../scripts/void_defense/vd_enemy_skills.gd:239)
  - 유물 뇌운 조각 착탄 [vd_relic_runtime.gd:190](../scripts/void_defense/relics/vd_relic_runtime.gd:190), 연구실 [vd_fx_lab.gd:393](../scripts/void_defense/vd_fx_lab.gd:393)
- 대안: 궤도 위성 레이저(위에서 내려오는 가는 빔 + 착탄 링), EMP 아크(수평으로 튀는 전기), 레벨업·부활은 데이터 업로드식 수직 스캔 기둥.

### 4. 소용돌이 포털 `portal` (시트 `vr_portal_swirl.png`) — 시트 1 · 8 / 시트 2 · 9, 10
- 보라색 마법 소용돌이. "차원 균열" 이름은 사이파이로도 읽히지만 그림은 마법 포털이다.
- 쓰는 곳 (4곳): 적 소환 예고 [vd_summon_fx.gd:145](../scripts/void_defense/vd_summon_fx.gd:145), 강적 예고 [vd_summon_fx.gd:153](../scripts/void_defense/vd_summon_fx.gd:153), 보스 공허 강하 사라짐·내려옴 [vd_enemy_skills.gd:222](../scripts/void_defense/vd_enemy_skills.gd:222), [vd_enemy_skills.gd:241](../scripts/void_defense/vd_enemy_skills.gd:241)
- 대안: 드롭 포드 착륙 표지(바닥에 깜빡이는 육각/사각 마커 + 경고선), 텔레포트 패드(동심원 링이 위로 올라가는 홀로그램), 픽셀이 재구성되는 디지털 소환.

### 5. 유물 잉걸불 — 불덩이 + 궤적 불꽃 + BURN! (시트 2 · 13, 13')
- 파이어볼 그 자체. `VDRelicFx.comet` + 궤적 불꽃 셰이더 `vfx/flame/flame_trail.tres` + 리본, 착탄 "BURN!" 글자, 적 몸 옆 **화상 불꽃 점** ([vd_unit.gd:1098](../scripts/void_defense/vd_unit.gd:1098)).
- 유물 이름·태그도 판타지: 잉걸불(炎)·불씨 주머니(囊), 태그 "화염" — [vd_relic_data.gd](../scripts/void_defense/relics/vd_relic_data.gd)
- 대안: 소이탄/플라즈마 탄(흰 코어 + 청록 꼬리, 착탄 뒤 그을음), 열선(레이저 + 과열 글로우). 화상 → "과열" 상태(몸에 열 왜곡/붉은 스캔라인).

### 6. 유물 서리 결정 — 시안 혜성 + 결정 띠 + 눈꽃 착탄 + FREEZE! (시트 2 · 14, 14')
- 얼음 마법. 착탄 링이 눈꽃(6광선), 둔화 상태는 **발밑 얼음빛 고리** ([vd_unit.gd:1101](../scripts/void_defense/vd_unit.gd:1101)). 절대 영도의 빙결(몸이 얼음빛으로 물듦, [vd_unit.gd:854](../scripts/void_defense/vd_unit.gd:854))도 같은 계열.
- 유물: 서리 결정(氷)·서리 거울(鏡), 태그 "서리".
- 대안: 극저온 냉각제 분사(흰 가스 + 성에 입자), 스태시스 필드(몸을 감싸는 격자 큐브/정지 홀로그램). 글자는 "STASIS"/"LOCK".

### 7. 유물 별 깃털 — 금빛 깃털 띠 + GUARD! (시트 3 · 15, 15')
- 수호 천사 모티프(별 깃털 羽, 태그 "수호"). 금빛 깃털이 아군에게 날아가 회복 반짝임으로 터진다.
- 대안: 지원 드론이 쏘는 실드 패킷(육각 배리어 조각이 몸을 감쌈), 에너지 배리어 전개. 보호막 띠(HP 바 위 하늘색 띠)는 그대로 둬도 된다.

### 8. 궁극기 준비 카드 황금 불꽃 (`shaders/card_ult_flame.gdshader`) — 시트 3 · 20
- 분대 카드 둘레에 타오르는 황금 불꽃 + 불티. 성화/신성 느낌. 마녀산장 `card_burn_glow` 에서 가져온 것.
- 조절값 [vd_card_flame_fx.gd](../scripts/void_defense/vd_card_flame_fx.gd), 연구실 "궁극기 카드 불꽃".
- 대안: 과부하 네온 테두리(흐르는 광선 + 글리치 깜빡임), 홀로그램 스캔라인, 카드 둘레 에너지 게이지가 차오르며 색이 변하는 식. 지금 셰이더의 SDF 거리장 구조는 그대로 쓰고 불 혀 대신 전류/스캔 패턴을 넣으면 된다.

---

## B. 리스타일 — 현상은 남기고 모양·색만 사이파이로

### 9. 에너지 구슬 `orb` (시트 `vr_energy_orb.png`) — 시트 2 · 11
- 스테인드글라스 무늬의 보라 마법 구슬. 마법사 평타 [vd_battle.gd:1918](../scripts/void_defense/vd_battle.gd:1918), 포자·보스 탄 [vd_battle.gd:1923](../scripts/void_defense/vd_battle.gd:1923)·[vd_battle.gd:1932](../scripts/void_defense/vd_battle.gd:1932), 망루 레이저 충전 [vd_enemy_skills.gd:121](../scripts/void_defense/vd_enemy_skills.gd:121)
- 대안: 플라즈마 탄(흰 코어 + 단색 글로우, 무늬 없음)으로 시트만 교체.

### 10. 체인 라이트닝 지그재그 선 (`VDUlts.bolt`, Line2D 두 겹) — 시트 1 · 5
- 전기는 사이파이에도 있다. 다만 "마법사의 체인 라이트닝"이라는 이름·색(연보라)이 마법. 테슬라 코일/EMP 아크로 색(시안·흰색)과 이름만 바꿔도 된다.

### 11. 유물 뇌운 조각 번개 띠 (`VDRelicFx.bolt`, 리본 셰이더) — 시트 2 · 12'
- 자홍/노랑/시안 지그재그 띠. 모양은 쓸 만하고 착탄의 하늘 낙뢰(3번)만 바꾸면 된다. 이름 뇌운 조각(雷)은 세계관 어휘 문제.

### 12. 몬스터 피격 파티클 (`VDTouchHit`: 노란 별 섬광 + 내리치는 번개) — 시트 3 · 17
- 터치 게임 데모에서 그대로 가져온 카툰 별. 전투 전역(`vfx.spawn("burst")` 25곳)에서 쓴다. 카툰 톤이라 꼭 바꿀 필요는 없지만, 별 모양이 마법/카툰 쪽이다. 강타의 "내리치는 번개"는 3번과 같은 문법.
- 대안: 스파크 파편(직선 조각) + 육각 섬광.

### 13. 기사 검기 셀 초승달 (`vd_sword_slash.gd` + `sword_slash_cel.gdshader`) — 시트 3 · 18
- 검 자체가 판타지 장비. 기사가 계속 검을 쓴다면 플라즈마 블레이드처럼 시안/흰 코어 + 잔상 글리치로 색만 바꿔도 된다.

### 14. 레벨업 금빛 연출 (별 섬광 + 금빛 낙뢰 + 바닥 충격파 + 차임) — 시트 1 · 6
- 세명이 오리라(TrioChess)의 "기둥 + 금빛 플래시" 이식. 금빛 + 하늘 번개 조합이 신성 연출. 대안: 데이터 업로드 기둥(수직 스캔 라인) + 육각 링.

### 15. 상태 표시 — 시트 3 · 19
- 기절: 머리 위 **도는 별 세 개** [vd_unit.gd:1128](../scripts/void_defense/vd_unit.gd:1128) (카툰). 마나 READY **별** [vd_unit.gd:1115](../scripts/void_defense/vd_unit.gd:1115). 화상 불꽃 점(5번), 둔화 얼음 고리(6번), 가드 푸른 고리 [vd_unit.gd:1120](../scripts/void_defense/vd_unit.gd:1120).
- 캡처에서는 기절 별과 READY 별만 보였고, 화상 점·둔화 고리·가드 고리는 4px 크기라 눈에 띄지 않았다 (코드로 그리는 작은 도형이라 교체 비용은 작다).
- 대안: 기절 → 머리 위 글리치 "ERR"/빙빙 도는 사각 픽셀, 화상 → 과열 경고 삼각형, 둔화 → 발밑 느린 스캔 링.

### 16. 유물 보드 어휘·글리프 (UI, 연출은 아님)
- 성좌판(별자리), 유물 이름·한자 인장(雷 炎 氷 羽 壺 共 齒 囊 鏡, [vd_relic_hud.gd:1082](../scripts/void_defense/relics/vd_relic_hud.gd:1082)에서 글자로 그림), 태그 번개/화염/서리/수호/정수, "침식·정화".
- 스킬 이름: 생명의 축복, 부활의 기도, 절대 영도, 용맹한 강습 / 직업명 기사·마법사·힐러 ([vd_data.gd](../scripts/void_defense/vd_data.gd)).
- 연출을 바꿔도 이름이 마법이면 판타지로 읽힌다. 모듈/칩/프로토콜 같은 어휘로 같이 바꿀지 결정이 필요하다. 참고 캡처: `docs/relic_shots/02_battle_room0.png`.

---

## C. 유지 — 사이파이와 충돌 없음

| 연출 | 근거 |
|---|---|
| 충격파 링 `shockwave` (`vr_shockwave.png`) | 흰 링만. 색만 쓰는 쪽에 맞추면 됨 |
| 히트 스파크·슬램·먼지·대시 (타워대시 `td_*`) | 물리 타격 연출 |
| 망루 공허 섬광포 레이저 빔 ([vd_enemy_skills.gd](../scripts/void_defense/vd_enemy_skills.gd)) | 이미 사이파이 |
| 화면 글리치·피격 글리치·UI 글리치 등장·CRT | 이미 사이파이 |
| 화면 쇼크웨이브 왜곡, 하프톤 안개, 공허 성운 배경, 그래픽 와이프 | 추상/스타일 연출 |
| 몬스터 체액, 몸 찌그러짐·녹아내림, 소환 낙하·꽂힘 | 공허 생물 연출 (포털만 4번) |
| 초궁극기 컷인 | 사용자 원화 기반 (`docs/fx_lab/07_cutin_impact.png`) |
| 궁극기 조준 네온 외곽선 | 이미 사이파이 (형광 튜브) |
| 공허 정수 결정 (3D 육각 쌍뿔 크리스탈) | 보더라인. "크리스탈 루트"는 RPG 문법이지만 에너지 셀로 읽힐 수 있어 유지 가능 |

쓰이지 않는 시트: `td_slash_steel_swing`(slash)·`td_parry_spark`(parry)는 LIB 에 있으나 호출 0건, `vr_impact_burst` 는 LIB 에 없음, `td_multikill_burst` 는 사용 금지(2026-11-09).

---

## 교체 우선순위 (제안)

1. **마법진 + 회복 반짝임 + 하늘 낙뢰** — 셋이 힐러·마법사 전체와 레벨업·부활·소환에 걸쳐 있어 화면에 가장 자주 보인다. 시트 3장을 사이파이 버전(홀로 링 / 나노 스캔 / 궤도 빔)으로 바꾸면 호출부는 그대로 둬도 된다.
2. **포털** — 소환은 매 웨이브마다 보인다.
3. **유물 투사체 3종(잉걸불·서리 결정·별 깃털)** — 연구실 "유물 투사체" 조절값·색 구조가 있어 색·셰이더만 갈아 끼우기 좋다.
4. **카드 황금 불꽃**, 에너지 구슬, 상태 표시 별.
5. 어휘(스킬·유물·직업 이름)는 기획 결정.

---

## 교체 결과 (2026-11-09, 같은 날)

교체 전·후 비교: `docs/fantasy_vfx_audit/compare_1.png` · `compare_2.png` · `compare_3.png` (왼쪽 전, 오른쪽 후). 교체 뒤 원본 캡처는 `docs/fantasy_vfx_audit/after/`.

| 항목 | 바뀐 것 | 어디서 |
|---|---|---|
| 1 룬 마법진 | 홀로그램 표지 링 (동심원 · 눈금 · 호 조각 · 육각 격자 · 중심 브래킷) | `vr_magic_circle.png` 재작성 |
| 2 회복 반짝임 | 나노 스캔 (아래→위 스캔 띠 + 육각 셀 + 사각 입자) | `vr_heal_sparkles.png` 재작성 |
| 3 하늘 낙뢰 | 궤도 빔 (위에서 꽂히는 빔 + 납작한 착탄 링 + 직선 파편) | `vr_lightning_bolt.png` 재작성 |
| 4 소용돌이 포털 | 텔레포트 패드 (도는 점선 링 + 육각 + 펄스 링, 루프) | `vr_portal_swirl.png` 재작성 |
| 5 잉걸불 | ~~불꽃 셰이더를 끄고 자홍·주황 플라즈마 트레이서 + OVERHEAT!~~ → **2026-11-10 사용자 요청으로 되돌림**: 예전 불덩이(flame_on 기본 1, 주황 띠, BURN!), 저장값 무시 대상에서도 뺌 | `vd_relic_proj_fx.gd`, `vd_relic_fx.gd` |
| 6 서리 결정 | 청록 정지장 탄, 착탄 반짝이 6 → 8, FREEZE! → STASIS!, 둔화 얼음 고리 → 점선 링 | 같은 파일 + `vd_unit.gd` |
| 7 별 깃털 | 흔들림 없는 민트 실드 패킷, GUARD! → SHIELD! | 같은 파일 |
| 8 카드 황금 불꽃 | 에너지 줄기(이퀄라이저처럼 계단식 길이 + 바깥으로 흐르는 대시) + 홀로 스윕 + 사각 픽셀, 기본 색 청록·보라 | `shaders/card_ult_flame.gdshader`, `vd_card_flame_fx.gd` |
| 9 에너지 구슬 | 플라즈마 탄 (흰 코어 + 아크) | `vr_energy_orb.png` 재작성 |
| 15 상태 표시 | 기절 별 → 깜빡이는 사각 픽셀, 화상 점 → 경고 삼각형 | `vd_unit.gd` |

- 시트 다섯 장은 `tools/vfx/build_scifi_sheets.py` 가 같은 격자·프레임 수로 그린다. 호출부(`vfx.spawn("lightning")` 등)와 키 이름은 그대로라, 마법진·낙뢰·포털을 쓰던 모든 자리(힐러·마법사 스킬/궁극기, 레벨업, 부활, 전투불능, 소환, 보스 강하, 유물 착탄)가 함께 바뀌었다. 판타지 원본은 `assets/_backup/vfx_fantasy/`.
- **저장값 이전**: 연출 연구실 저장 파일(`user://relic_proj_fx.json`, `user://card_flame_fx.json`)은 모든 값을 통째로 저장해 새 기본값을 덮는다. 그래서 두 조절값에 `STYLE = 2` 를 두고, 그보다 오래된 저장에서는 바뀐 종류의 색·띠 모양·전용 값만 버리고 비행 시간·글자 크기·줄기 길이 같은 튜닝은 그대로 살린다. 다음에 연구실에서 저장하면 `_style: 2` 가 함께 기록된다.
- 연구실 이름: "궁극기 카드 불꽃" → "궁극기 카드 오버차지", 유물 투사체 종류 이름에 (열 플라즈마탄 / 정지장 탄 / 실드 패킷).

**아직 그대로 둔 것** (리스타일 후보, 판단 필요): 체인 라이트닝 선(색은 이미 청백), 뇌운 조각 번개 띠, 몬스터 피격 별 섬광(카툰), 기사 셀 초승달 검기, READY 별, 유물·스킬·직업 이름과 한자 인장(16번 어휘).
