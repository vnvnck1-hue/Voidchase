# 초궁극기 시전 소리 v1 (2026-11-06)

요청: "초궁극기 시전 사운드 — 파칭~! 하면서 날카로우면서도 청명하고 깔끔한 소리" (참고로 든 게임의 궁극기 시전 느낌).

- 연출: `vd_super_cutin.gd` (마법사만 `vd_ult_cinematic.gd` SUPER_CUTIN). 0.00 whoosh → **0.15 IMPACT "핏칭!"**(두 띠 맞물림, 지금 `clash`+`boom` 합성음 + 마법사 추임새) → 0.32 눈 반짝 → 1.12 띠 접힘. 고른 소리는 IMPACT 에 낼 예정.
- 생성: 로그인한 ElevenLabs 웹 효과음(SFX v3, 1.5초, 영향 30%, 변형 4개) — 설명 5가지(`build.mjs` PROMPTS, 게임 이름은 넣지 않음) × 4 = 20개. 크레딧 4,432 → 4,312(첫 묶음 오염으로 a 한 번 더 생성).
  - 받기 주의: 웹 결과 창은 같은 오디오 요소를 재사용해서 재생 순간의 src 가 한 박자 늦음 → 행의 React 속성(`item.sound_generation_history_item_id`·`subgroup_position`, 파형 컴포넌트 `url` blob)으로 행마다 정확히 받음. 새 행은 한 번 재생해야 url 이 붙음.
- 다듬기·페이지 [build.mjs](build.mjs) → `edited/*.wav`, [super-ult.html](super-ult.html): 앞 무음만 자름, 최대 1.5초, "피크까지 ms" 표시. 게임 적용(같은 날 승인): a-2·a-3·a-4·b-1·b-3·c-1·c-2·c-3 → `super_ult_01~08.wav`, 맞물림 순간 무작위(합성 clash+boom 대신). b-1 은 앞 0.26초 잘라 "핑"을 0.06초로.
