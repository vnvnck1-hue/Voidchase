# 갈림길 석판 솟아오름 소리 v1 (2026-11-06)

요청: "다음 스테이지 방향 정할 때 석판들이 올라오는 소리를 만들어 줘".

- 연출: `VDBattle` 방 클리어 → `map.generate_exits` → `VDBoard.raise_tiles(new_cells, …)` (블록마다 RISE_SEC 0.5초, 거리×0.035초 + 무작위 0~0.3초 늦게) → 약 1.5~2초 뒤 갈림길 표시. 소리는 솟아오르기 시작할 때 한 번 내는 것으로 설계(블록마다는 수십 개 겹침).
- 생성: 로그인한 ElevenLabs 웹 효과음(SFX v3, 2.0초, 영향 30%, 한 번에 변형 4개) — 설명 5가지(`build.mjs` PROMPTS) × 4 = 20개, 140 크레딧(4,567 → 4,432 화면 값). 수신은 [receiver.mjs](receiver.mjs). 받은 파일은 확장자가 .mp3 지만 실제 opus.
  - 주의: 결과 창에 이전 묶음이 위로 쌓여 처음 받기에서 이름이 덮였음 → 묶음 제목으로 구분해 다시 받음(md5 20개 모두 다름).
- 다듬기·페이지 [build.mjs](build.mjs) → `edited/*.wav`, [slab-rise.html](slab-rise.html). 게임 적용(같은 날 승인): `slab_rise_01~04`(a-2·b-1·d-1·d-2, 무작위) · `slab_rise_boss`(e-2, 다음 웨이브가 보스·대형 적일 때 — `VDData.is_hard_wave`). 평균 음량 -23dB(boss -21)로 맞춤.
