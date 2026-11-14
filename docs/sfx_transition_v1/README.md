# 화면 전환(번개 닫힘) 소리 v1 (2026-11-12)

요청: "대각선으로 닫히는 화면 트랜지션에 쓸 사운드. 크레딧이 별로 없으니 너무 많이 만들지 마".

- 연출: `scripts/screen_transition.gd` 프리셋 2 번개 닫힘(기본값, `screen_transition_lightning.gd`). 덮기 `lt_in_dur` 0.36초 → covered(씬 교체) → 되감아 열기 `lt_out_dur` 0.3초.
- 생성: ElevenLabs 웹 효과음(SFX v3, 1.0초, 영향 30%, 변형 4개) 설명 2가지 = 8개, 24크레딧. 수신 [receiver.mjs](receiver.mjs).
  - 받기 주의: 행의 React fiber 에서 `item` 을 가진 노드를 찾은 뒤 **그 노드의 자식**에서 파형 `url` 을 찾아야 한다(한 단계 위에서 찾으면 묶음의 첫 소리만 4번 나옴).
- 다듬기·페이지 [build.mjs](build.mjs) → `edited/*.wav`, [transition.html](transition.html). 게임 적용(같은 날 승인): b-2·b-3·b-4 → `assets/audio/transition/transition_1~3.wav`. 전환 start() 에서 재생, 연구실 "화면 전환" [5 소리] 에서 끔·1·2·3·무작위·크기 선택(기본 1, -4dB).
