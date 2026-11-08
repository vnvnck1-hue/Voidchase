# 건너 추임새 v1 (2026-11-06)

요청: 캐릭터별 스킬 사용·피격 추임새를 ElevenLabs로 만들되 우선 한 캐릭터만. 보고는 마녀산장 소리 보고 페이지 형식(`마녀산장/output/audio-guest-voices-v02/build_erin_pick.mjs`)으로.

- 캐릭터: **건너**(핑크 SMG 메이드, 눈치 빠른 관찰자, `vd_data.gd` `gunner`, 스킬 "다중 사격").
- 문구 [cast.json](cast.json): 스킬 "하앗!"·"흡… 하앗!"·"에잇!"·"후훗~ 하앗!" / 피격 "꺄앗!"·"윽…!"·"아얏!"·"큭… 으읏!". `[영어 감정 태그] 한국어 추임새`.
- 목소리: Irohauta(Bratty Anime female)·Kano(Cute & Anime)·Pipi(Cute & Anime) — 라이브러리 "anime" 검색 결과의 일본어 애니풍 여성.
- 생성: `%USERPROFILE%\.elevenlabs\api_key` 의 키가 **401 무효**라 로그인된 웹 화면(앱 안 브라우저, Eleven v4, 안정성 50%·유사성 75%)에서 생성. 한 번에 테이크 2개 → 3 × 8 × 2 = 48개, 690 크레딧(8,556 → 7,866).
  - 받기: 페이지 플레이어의 data URI를 [receiver.mjs](receiver.mjs)(127.0.0.1:8799)로 POST → `raw_web/*.mp3`. ffmpeg가 없어 같은 페이지의 WebAudio로 디코딩해 `decoded/*.wav`(44.1kHz 모노).
- 다듬기 [edit.mjs](edit.mjs) → `edited/*.wav`, [meta.json](meta.json)(길이·음높이). 음량 기준(-35dB), 최대 1.6초(skill-04만 2.2초), 피크 -3dB. 음높이 315~850Hz.
- 받아쓰기(STT) 검증은 키가 없어 못 함 — 귀로 확인 필요.
- 보고 페이지 [gunner-voice.html](gunner-voice.html) (`node build_page.mjs`): 목소리별 스킬·피격, 여러 개 체크·코멘트·결과 복사, 한 번만 재생. **아직 게임 미적용.**
- 폴더에 `.gdignore` — 열려 있는 Godot 에디터가 mp3/wav 를 임포트하지 않게.

## 1차 선택 → 게임 적용, 2차 생성 (같은 날)

- 1차 결과(gunner-voice.html): 스킬 Irohauta "하앗!" t1·t2, "에잇!" t2 — 피격 0개. 코멘트 "대부분 너무 길다, 더 임팩트 있게 짧게, 미소녀 서브컬처 게임에 어울리게".
- 다듬기 규칙 2차로 변경([edit.mjs](edit.mjs)): -30dB, 앞뒤 10ms, 쉼 0.06초, **최대 0.8초**, 끝 40ms 페이드. 1차 페이지는 옛 규칙 결과 그대로 둠(다시 만들면 짧은 소리로 바뀜).
- **게임 적용**: 고른 3개를 새 규칙으로 다시 다듬어(0.42·0.64·0.52초) `assets/audio/void_defense/voice/gunner_skill_01~03.wav`. `vd_audio.gd` `SFX["voice_gunner_skill"]`(-6dB, 무작위), `VDSkills.cast` 가 시전 성공 때 `voice_<영웅 id>_skill` 재생 — 다른 영웅은 항목을 추가하기만 하면 됨.
  - 검증: VDRunner 4사이클 — 건너 스킬 2회 = `voice_gunner_skill` 재생 2회. 실행판 내보내기는 게임 exe 가 켜져 있어 이름 바꾸기 실패(다시 내보내야 함).
- **2차 후보** [cast_v2.json](cast_v2.json): Irohauta 한 목소리, 한 음절 위주 — 스킬 "핫!"·"얍!"·"타앗!"·"세잇!"·"하잇!"·"흣!", 피격 "꺅!"·"읏!"·"아읏!"·"히앗!"·"큿!"·"꺄웃!" × 테이크 2 = 24개(`v2iro_*`), 0.22~0.8초.
- 보고 페이지 [gunner-voice-v2.html](gunner-voice-v2.html) (`node build_page.mjs v2`): 맨 위 "지금 게임에 들어감"(체크 기본, 빼면 게임에서 뺌) + 2차 후보.

## 2차 선택 → 게임 적용 (같은 날)

- 2차 결과(gunner-voice-v2.html): 스킬 7개(1차 3 + "얍!" v2iro_skill-02-t2 · "세잇!" 04-t1 · "하잇!" 05-t1 · "흣!" 06-t1), 피격 6개("꺅!" 01-t1·t2 · "읏!" 02-t1 · "히앗!" 04-t2 · "큿!" 05-t1·t2).
- 음절 편집 [cut.mjs](cut.mjs): "하잇 두 번"→첫 음절, "흣·휴 두 개"→음절별 2개, "히얏 두 번"→첫 음절, "큿" t1→하나, t2→음절별 2개. 결과 `edited/<key>-sN.wav`(0.16~0.36초). "흣!" t1 의 셋째 짧은 소리(s3)는 넣지 않고 확인 페이지에 참고로.
- 게임: `voice/gunner_skill_01~08.wav`, `voice/gunner_hurt_01~07.wav`. `VDAudio.voice(영웅 id, "skill"|"hurt")` — 피격은 영웅별 1.2초 쿨다운(`HURT_VOICE_COOLDOWN_MS`), -7dB. 호출: `VDSkills.cast`(스킬), `VDBattle._apply_hit`(아군 피해 > 0).
- 검증: 임포트 후 스킬 8·피격 7 로딩, 연속 피격 → 1회, 전투 씬에서 건너 피격 → `voice_gunner_hurt` 1회(임시 씬, 실행 후 삭제), VDRunner 4사이클 오류 없음.
- 적용본 확인 페이지 [gunner-voice-final.html](gunner-voice-final.html) (`node build_final.mjs`): 게임 파일 그대로 재생, 체크 풀면 "빼기"로 결과 복사.
