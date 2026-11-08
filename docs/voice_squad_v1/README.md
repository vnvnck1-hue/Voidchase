# 분대 3명 추임새 v1 (2026-11-06)

요청: "필드에서 나머지 세 명(기사·마법사·힐러)에게도 만들어 줘, 이전처럼 보고하면 승인하겠다". 건너 작업은 [../voice_gunner_v1](../voice_gunner_v1/README.md).

- 목소리(캐릭터마다 2종, 건너 Irohauta 와 겹치지 않게): 기사 Lola(Female Action Character)·Aisyah(Energetic Anime Character) / 마법사 Suzu(Cute, Clear & Calm)·Ayame(Anime) / 힐러 Koume(Sweet & Playful)·Kano(Cute & Anime).
- 문구 [cast.json](cast.json): 캐릭터마다 스킬 5 · 피격 5, 성격(기획서 §분대: 기사 직설·따뜻 / 마법사 조용·건조 / 힐러 다정)에 맞춘 영어 감정 태그 + 한 음절 위주 한국어 추임새. × 테이크 2 = 캐릭터당 40, 총 120개.
- 생성: 로그인한 웹 화면(Eleven v4). 문구 입력·생성·받기를 페이지 스크립트로 돌림(`execCommand insertText` → 생성 버튼 → 테이크 재생으로 data URI → [receiver.mjs](receiver.mjs) 로 POST). 크레딧 7,391 → 4,567 (2,824 사용).
- 다듬기 [edit.mjs](edit.mjs): 건너 2차 선택 때 음절 편집 요청("두 번 한다 → 한 번만")을 처음부터 적용 — 소리 덩어리 중 가장 센 하나만(기사 skill-04 "흡… 핫!"만 앞 덩어리까지), 최대 0.6초. 결과 0.18~0.6초, 원본 120개 중 84개가 덩어리 여럿(숨소리·반복)이었음.
- 음높이 중앙값: Lola 507 · Aisyah 621 · Suzu 300 · Ayame 271 · Koume 496 · Kano 531Hz.
- STT 검증 못 함(API 키 무효). 고르기 페이지 [squad-voice.html](squad-voice.html) (`node build_page.mjs`). **아직 게임 미적용 — 사용자 승인 대기.**
- 게임 연결은 이미 일반화돼 있음: `vd_audio.gd` `SFX` 에 `voice_<knight|mage|healer>_<skill|hurt>` 를 추가하면 `VDAudio.voice()` 가 재생.
