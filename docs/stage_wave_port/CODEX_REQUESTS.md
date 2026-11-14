# 코덱스 리소스 요청 — 기믹 몬스터 7종 · 스킬 아이콘 16종 (· 선택: 기믹 배너 아이콘 6종)

작성일: 2026-11-08. 대상 기능은 `README.md` (TrioChess 이식분). 아래 두 묶음은 게임 코드가 **파일 이름으로 바로 집어 쓰도록** 준비되어 있다 — 파일만 그 자리에 넣으면 된다.

Mode: built-in image_gen; transparent_background=true (모두 알파 배경, 캐릭터·아이콘 바깥은 완전 투명).
참고 이미지: 기존 공허 몬스터 `assets/void_defense_enemies/void_shard.png` `void_spore.png` `void_bulwark.png`, 원화 `assets/컨셉 원화/공허 유적의 전술 방어전.png` 의 공허 잔재. 아이콘은 시안 `화면 컨셉_2.psd` 의 아이템 아이콘(`ui_icon_projectileheart` 등)과 유물 아이콘(`assets/textures/relic_ui/icon_*.png`) 톤.

---

## A. 기믹 무리 몬스터 7종 (필수)

넣을 곳: `assets/void_defense_enemies/<파일>.png`. 받으면 `scripts/void_defense/vd_rig.gd` 의 `SPECIALIST_ART` 에 `{"texture", "width", "lift"}` 로 등록하고 `ENEMY_ALIAS` 에서 그 id 를 뺀다 (지금은 기존 원화를 배율·틴트만 바꿔 임시로 쓴다).

공통: 몬스터는 **왼쪽(아군 쪽)을 바라본다** (기존 몬스터 원화와 같은 방향). 한 장에 한 마리 전신, 발이 아래 가운데, 그림자·바닥·텍스트 없음, 가장자리 여백 조금. 1024² 정도로 뽑아도 된다 (게임이 폭 기준으로 줄인다).

| 파일 | id | 이름 | 크기감(잔재 기준) | 디자인 |
|---|---|---|---|---|
| `void_swarm.png` | swarm | 잔재 떼 | 0.6배 | 아주 작은 잔재. 눈 하나, 몸이 거의 머리만, 짧은 가시 두세 개. 떼로 보일 때 읽히는 단순한 실루엣 |
| `void_assassin.png` | assassin | 균열 암살자 | 1.0배, 가늘고 길게 | 가늘고 긴 검은 형체, 얼굴을 가린 두건 같은 머리, 보라색 단검 한 자루(또는 손끝이 칼), 발 대신 끝이 흩어지는 연기. 몸 둘레에 보라 균열 선 한두 개 |
| `void_splitter.png` | splitter | 분열 잔재 | 1.3배 | 통통한 큰 잔재. 몸 가운데에 세로로 갈라질 듯한 보라 틈(발광 선)이 있고 눈이 둘 — 둘로 갈라질 것 같은 느낌 |
| `void_splitling.png` | splitling | 소잔재 | 0.5배 | 분열 잔재의 반쪽: 한쪽이 잘린 듯 납작한 작은 잔재, 눈 하나 |
| `void_sprinter.png` | sprinter | 공허 추적자 | 1.1배, 낮고 길게 | 네 발 달린 잔재(원화 '심연의 왕관체' 옆 거미형 참고). 몸을 낮추고 앞으로 쏠린 돌진 자세, 뒤로 흐르는 잔상 가시 |
| `void_hydra.png` | hydra | 공허 촉수 | 1.15배, 세로로 길게 | 바닥의 보라 웅덩이에서 솟은 촉수 머리 하나. 끝이 입처럼 벌어지고 작은 눈이 박혀 있다. 밑동 웅덩이는 캐릭터 일부(투명 배경 위 그려도 됨) |
| `void_illusionist.png` | illusionist | 공허 환술사 | 1.1배 | 잔재가 너덜한 보라 망토와 뾰족한 모자를 썼다. 눈 셋(가운데 하나는 크게), 손끝에 작은 보라 구슬. 환영(`illusion`)은 이 그림을 반투명으로 쓰므로 별도 그림 불필요 |

### Final prompt (한 마리씩, 이름만 바꿔 7번)

Use case: stylized-concept, single game sprite. Create ONE original "void monster" for VOID DEFENSE on a genuinely transparent alpha background. Match the attached existing void monsters exactly in rendering: thick near-black outlines, chunky simple masses, restrained interior lines, broad 2–3-tone cel shading, charcoal-violet body with lavender rim light, one or more small crimson/magenta glowing eyes, faint violet glow only inside the silhouette. Slightly elevated three-quarter view, the creature FACES LOWER-LEFT, upper-left light. Full body visible including every extremity, feet at bottom center, transparent padding on all sides. No floor, no cast shadow, no background, no text, no UI, no watermark, no comparison sheet, exactly one creature.

Subject: <위 표의 '디자인' 칸을 영어로 옮겨 넣는다. 예: "Splitter remnant — a plump oversized void blob with two eyes and a glowing violet vertical seam down the middle of its body as if about to split in two.">

---

## B. 스킬 아이콘 16종 (필수)

넣을 곳: `assets/textures/skill_icons/<id>.png` (폴더는 새로 만든다). 파일 이름이 맞으면 스킬창(`vd_skill_window.gd`)이 바로 보여 준다. 128×128, 투명 배경, 정사각 안에 꽉 차게. 시안의 아이콘처럼 **굵은 검은 외곽선 + 두세 톤 셀 음영 + 작은 하이라이트**, 보라 상자(#8B62BC) 위에 올라가므로 노랑·분홍·하늘색 등 밝은 색이 주색.

| id | 영웅 | 스킬 | 그림 제안 |
|---|---|---|---|
| assault_mastery | 기사 | 강습 숙련 | 아래로 내리꽂는 검과 땅에 퍼지는 충격 금 |
| quake_mastery | 기사 | 충격파 숙련 | 방패에서 번지는 동심원 파동 |
| iron_wall | 기사 | 철벽 | 금이 간 자리 없는 두꺼운 방패, 작은 빗금 |
| vitality | 기사 | 생명력 | 하트 안에 작은 + 표시 |
| volley_mastery | 건너 | 다중 사격 숙련 | 세 갈래로 퍼지는 탄환 궤적 |
| barrage_mastery | 건너 | 집중 포화 숙련 | 부채꼴로 쏟아지는 탄막 |
| rapid_fire | 건너 | 속사 | 탄환 셋이 겹친 속도선 |
| critical | 건너 | 치명타 | 과녁 가운데 꽂힌 번쩍이는 별 |
| frost_mastery | 마법사 | 절대 영도 숙련 | 육각 눈 결정 + 얼음 조각 |
| storm_lord | 마법사 | 번개 군주 | 왕관 쓴 번개 |
| arcane | 마법사 | 마력 증폭 | 빛나는 보라 구슬과 위로 솟는 화살표 |
| freeze | 마법사 | 빙결 | 얼음에 갇힌 작은 잔재 실루엣 |
| blessing_mastery | 힐러 | 축복 숙련 | 빛줄기 아래 작은 십자 |
| prayer_mastery | 힐러 | 기도 숙련 | 날개 달린 하트(부활) |
| grace | 힐러 | 은총 | 초록 잎 두 장과 반짝임 |
| mana_flow | 힐러 | 마나 순환 | 서로 꼬리를 무는 파란 물방울 두 개 |

### Final prompt (한 장에 4×4 시트로 뽑은 뒤 잘라도 되고, 한 장씩이어도 된다)

Use case: game UI icon set. Create 16 skill icons for a cute chibi tactics game, each a clean square icon on a genuinely transparent background, drawn in the same style as the attached item icons: bold near-black outlines, flat 2–3-tone cel shading, one small white highlight, saturated readable colors (yellow, pink, sky blue, mint, violet) that stay legible on a medium purple box. Centered symbol filling ~80% of the square, no text, no frame, no drop shadow, no background. If produced as a sheet: a 4-column × 4-row grid with generous transparent gutters, left-to-right top-to-bottom in this order: <표의 16개 그림 제안을 영어로 나열>.

시트로 받으면 `tools/icons/` 에 자르는 스크립트를 추가해 16장으로 나눈다 (이름은 위 id).

---

## C. 기믹 무리 배너 아이콘 6종 (선택)

웨이브 배너 "N차 웨이브!" 옆과 상단 안내문에 붙일 작은 아이콘. 96×96 투명 PNG, 넣을 곳 `assets/textures/battle_ui/gimmick_<id>.png` (id: swarm_raid, assassin_raid, splitter_raid, sprinter_raid, hydra, illusionist). 지금은 글자만으로 안내하므로 없어도 동작한다. 스타일은 B 와 같고 단색(연보라) 실루엣이면 충분하다: 작은 잔재 셋 / 단검 / 둘로 갈라지는 방울 / 속도선 달린 발자국 / 촉수 / 눈 셋 달린 모자.
