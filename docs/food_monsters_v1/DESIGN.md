# 음식 몬스터 디자인 v1

게임 적용 전 검토용 콘셉트. 내장 `image_gen`으로 생성한 6종 라인업이며 개별 투명 스프라이트는 아니다.

이미지: `food_monsters_lineup_v1.png`

## 공통 방향

참고 이미지의 케이크·우유 소재를 기존 VOID DEFENSE 몬스터의 굵은 먹색 외곽선, 큰 덩어리, 단순한 셀 음영, 붉은 외눈에 연결했다. 음식 고유의 황금색·크림색·초콜릿색은 유지하고, 몸 안의 공허를 보라색 잼·시럽·액체로 표현한다. 작은 전투 화면에서도 실루엣으로 역할을 알아볼 수 있도록 한다.

| 번호 | 이름 | 디자인 핵심 | 제안하는 전투 행동 |
|---|---|---|---|
| 01 | 시럽 방패병 | 버터 투구, 팬케이크 몸, 와플 방패 | 느리게 전진하며 정면 피해 감소. 공격 직전 방패를 젖힌다. |
| 02 | 딸기케이크 미믹 | 딸기 외눈, 벌어지는 케이크 턱, 보라 잼 혀 | 잠깐 웅크린 뒤 전방 물기. 열린 턱이 공격 예고가 된다. |
| 03 | 초코 펀처 | 크림 뿔, 낮고 넓은 케이크 몸, 커다란 트러플 주먹 | 짧은 사거리의 강한 펀치. 팔을 뒤로 당기는 예고 동작. |
| 04 | 우유병 폭탄병 | 열린 코르크, 둥근 병, 작은 우유 폭탄 | 병을 흔든 뒤 곡사 투척. 착탄한 우유가 잠시 둔화 지대를 만든다. |
| 05 | 밀크 마도사 | 마녀모자 형태의 우유 거품, 머그 손잡이, 초승달 스푼 | 후열에서 투사체 발사. 스푼을 들어 주문을 예고한다. |
| 06 | 우유팩 돌격병 | 접힌 팩의 쐐기형 이마, 뒤로 뻗은 빨대, 우유 다리 | 잠시 멈춰 몸을 숙인 후 직선 돌진. 경로를 미리 표시한다. |

전투 행동은 디자인 제안이며 게임 코드에 구현하지 않았다. 실제 적용 시 각 캐릭터를 독립 투명 PNG로 제작하고 대기·공격·피격 포즈를 분리한다.

## 생성 정보 및 프롬프트 요약

- 방식: 내장 `image_gen`, 불투명 연보라 배경의 단일 콘셉트 시트.
- 참고 1: 사용자 첨부 케이크 이미지. 음식 소재와 생물화 아이디어 참고.
- 참고 2: 사용자 첨부 우유 이미지. 병·머그·팩 형태 참고.
- 참고 3: `docs/toy_monsters_v1/windup_boxer_v1.png`. 외곽선·셀 음영·붉은 눈의 렌더링 스타일 참고. 기계 구조는 차용하지 않음.

Use case: stylized-concept. Create one original food-monster concept lineup for VOID DEFENSE, six distinct chibi enemies in a landscape 3-column by 2-row sheet. Reference cakes and dairy only for subjects; match the existing wind-up boxer reference for bold near-black outlines, chunky shapes, restrained internal lines, broad 2–3-tone cel shading and a crimson magical eye. Food bodies remain butter gold, baked brown, ivory cream, strawberry red and muted milk blue, with charcoal-violet living filling and lavender shadows. Slightly elevated three-quarter view facing lower-left, upper-left light, readable at 100–140px tall. Cute but hostile magical food creatures, no robot anatomy or horror.

01: Pancake bulwark with butter helmet, syrup arms and feet, one eye in violet filling, and round waffle shield. 02: Strawberry shortcake mimic with a hinged sponge-and-cream jaw, biscuit teeth, one eye in the strawberry, and curling violet jam tongue. 03: Chocolate cyclops cake with two cream horn peaks, enormous truffle fists, and one red eye. 04: Round milk-bottle bomber with tilted cork, connected violet cream wisp, blue label opening around its eye, and a small corked milk bomb. 05: Ivory mug hexer with a visible handle, curled milk-foam witch-hat peak, one eye, crescent teaspoon wand, and small milk feet. 06: Red-and-ivory milk-carton rammer leaning into a charge, blunt folded gable crest, backward bent straw, one eye, simple blue oval patch, violet liquid arms and oversized cream splash legs.

Very pale warm lavender background, ample whitespace, each full body visible, tiny contact shadows, numeric labels 01–06 only. No title, other text, UI, watermark, scenery, floating effects, tiny details, realistic material rendering, duplicate characters or cropped bodies.
