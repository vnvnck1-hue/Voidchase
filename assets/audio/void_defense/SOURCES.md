# void_defense 사운드 출처 (2026-11-04)

| 파일 | 원본 | 용도 |
|---|---|---|
| knight_attack.wav / knight_hit.wav | 타워대시 assets/audio/sfx-slash.wav, sfx-slash_hit.wav | 기사 공격·명중 |
| gun_01~03.wav | 헥스 블레이드 output/mg-sound-candidates-20261002/v2/A_close/A_close_01~03.wav | 건너 사격 (랜덤) |
| gun_hit.wav | 타워대시 sfx-shuriken_hit.wav | 건너 명중 |
| mage_cast.wav / mage_hit.wav | 마녀산장 godot/assets/audio/sfx-bolt_cast.wav, sfx-bolt_hit.wav | 마법사 시전·명중 |
| heal.wav | 마녀산장 sfx-witch_heal.wav | 힐러 회복 |
| enemy_attack.wav / ally_hurt.wav | 마녀산장 sfx-mon_attack.wav, sfx-ally_hurt.wav | 적 공격·아군 피격 |
| enemy_hit.wav / enemy_die.wav | 마녀산장 sfx-mon_hit.wav, sfx-mon_die.wav | 적 피격·처치 |
| enemy_spawn.wav / boss_spawn.wav | 마녀산장 sfx-mon_spawn.wav, sfx-mon_big.wav | 적·보스 등장 |
| hero_down.wav | 마녀산장 sfx-witch_down.wav | 영웅 전투불능 |
| wave_start.wav / wave_clear.wav / defeat.wav | 마녀산장 sfx-wave_start.wav, sfx-wave_clear.wav, sfx-defeat.wav | 웨이브 시작·클리어·게임오버 |
| essence.wav | 타워대시 sfx-coin.wav | 정수 획득 |
| click.wav / place.wav | 마녀산장 sfx-btn_click.wav, sfx-move_click.wav | 버튼·배치 |

## 2026-11-06 — 세명이 오리라(TrioChess) 사운드로 교체

전투·UI 소리는 `trio/` 폴더(원본: `세명이 오리라/godot/audio/sfx/`, 마녀산장 사운드 세트·ElevenLabs)로 바꿨다.
whoosh·boom·rise·clash 는 TrioChess `scripts/sfx.gd` 합성식을 `vd_audio.gd` 에 옮겨 런타임에 만든다.
적 소환(`enemy_spawn.wav`·`boss_spawn.wav`)과 BGM 은 요청대로 제외(기존 유지). 이름 → 파일 매핑은 `vd_audio.gd` 의 `SFX`.
위 표의 나머지 기존 파일은 지금 쓰이지 않는다.

## 2026-11-06 — 캐릭터 추임새 (ElevenLabs)

`voice/` — 영웅별 짧은 추임새. `VDAudio.voice(영웅 id, kind)` 가 `SFX` 의 `voice_<영웅 id>_skill`(VDSkills.cast, 스킬 시전) · `voice_<영웅 id>_hurt`(VDBattle._apply_hit, 아군 피격, 영웅별 1.2초 쿨다운) 중 무작위로 재생.
생성·고르기 기록은 `docs/voice_gunner_v1/` (README·고르기 페이지).

| 파일 | 원본 | 용도 |
|---|---|---|
| voice/gunner_skill_01~03.wav | ElevenLabs Eleven v4, Irohauta — iro_skill-01-t1·01-t2("하앗!")·03-t2("에잇!"), 0.8초 이하로 다듬음 | 건너 스킬(다중 사격) 시전 |
| voice/gunner_skill_04~08.wav | 2차 v2iro_skill-02-t2("얍!")·04-t1("세잇!")·05-t1 첫 음절("하잇!")·06-t1 첫째·둘째 음절("흣!"·"휴") — cut.mjs 로 음절 편집 | 건너 스킬 시전 |
| voice/gunner_hurt_01~07.wav | 2차 v2iro_hurt-01-t1·01-t2("꺅!")·02-t1("읏!")·04-t2 첫 음절("히앗!")·05-t1 첫 음절·05-t2 두 음절 각각("큿!") | 건너 피격 |

## 2026-11-06 — 발소리

| 파일 | 원본 | 용도 |
|---|---|---|
| step.wav | 마녀산장 godot/assets/audio/sfx-witch_step.wav (눈 밟는 한 걸음, 0.08초, -14dB) | 아군이 스테이지(방) 사이를 이동할 때(VDBattle TRAVEL) 두 걸음에 한 번 — `VDUnit.stepped` |

## 2026-11-06 — 기사·마법사·힐러 추임새 (ElevenLabs)

생성·고르기 기록 `docs/voice_squad_v1/` (README·squad-voice.html, 승인 목록은 apply.mjs `PICKS` 순서 = 파일 번호).

| 파일 | 원본 | 용도 |
|---|---|---|
| voice/knight_skill_01~06.wav | Lola "하아앗!"·"타앗!"·"흡… 핫!", Aisyah "타앗!"·"얍!"·"세잇!" | 기사 스킬(용맹한 강습) |
| voice/knight_hurt_01~09.wav | Lola "윽!"×2·"흐읍!"·"아윽!", Aisyah "큭!"·"윽!"·"크읏!"·"흐읍!"·"아윽!" | 기사 피격 |
| voice/mage_skill_01~07.wav | Suzu "흥."×2·"핫."·"얍.", Ayame "흥."·"핫."·"후우…" | 마법사 스킬(절대 영도) |
| voice/mage_hurt_01~07.wav | Suzu "읏."×2·"흣.", Ayame "읏."×2·"큿…"·"흣." | 마법사 피격 |
| voice/healer_skill_01~07.wav | Koume "에잇~!"·"하앗~"·"야앗!"·"얍~!", Kano "야앗!"·"하잇~!"·"얍~!" | 힐러 스킬(생명의 축복) |
| voice/healer_hurt_01~09.wav | Koume "꺄앗!"·"아앗!"·"히잉!"·"꺅!", Kano "꺄앗!"·"아앗!"×2·"히잉!"·"꺅!" | 힐러 피격 |

## 2026-11-06 — 갈림길 석판 솟아오름 (ElevenLabs SFX v3)

기록 `docs/sfx_slab_rise_v1/` (README·slab-rise.html). 평균 음량 -23dB(boss -21dB)로 맞춤.

| 파일 | 원본 | 용도 |
|---|---|---|
| slab_rise_01~04.wav | slab-a-2(무거운 고대 석판)·slab-b-1(마법 석판 + 반짝임)·slab-d-1·d-2(깊은 울림 + 마지막 쿵) | 방 클리어 후 새 복도·방 석판이 솟아오를 때(VDBoard.raise_tiles 직후) 무작위 |
| slab_rise_boss.wav | slab-e-2(공허 에너지 + 떠오르는 발판) | 다음 웨이브가 보스·대형 적일 때(`VDData.is_hard_wave`) 대신 |

## 2026-11-06 — 초궁극기 시전 "파칭~!" (ElevenLabs SFX v3)

기록 `docs/sfx_super_ult_v1/` (README·super-ult.html). 평균 음량 -21dB 안팎으로 맞춤. 초궁극기 컷인 맞물림 순간(`vd_super_cutin.gd` `_on_impact`, 시작 0.15초)에 8개 중 무작위 — 전의 합성 clash+boom 을 대신함.

| 파일 | 원본 |
|---|---|
| super_ult_01~03.wav | ult-a-2·a-3·a-4 (금속성 파칭 + 크리스털 울림) |
| super_ult_04.wav | ult-b-1 (빠른 휙 → 유리 같은 핑) — "핑"이 0.32초 뒤라 앞 0.26초를 잘라 0.06초에 오게 함 |
| super_ult_05.wav | ult-b-3 |
| super_ult_06~08.wav | ult-c-1·c-2·c-3 (칼날 같은 칭 + 종소리 울림) |

## 2026-11-12 — 화면 전환 소리 (ElevenLabs SFX v3) → assets/audio/transition/

기록 `docs/sfx_transition_v1/`. 평균 음량 -20dB 로 맞춤. `scripts/screen_transition.gd` start() 에서 재생, 연출 연구실 "화면 전환" [5 소리] 에서 끔 / 1 / 2 / 3 / 무작위 와 크기(dB)를 고른다(`screen_transition_fx.gd` snd_pick·snd_db, user://transition_fx.json).

| 파일 | 원본 |
|---|---|
| transition/transition_1~3.wav | tr-b-2·b-3·b-4 (전기 지직 + 휙 → 단단한 탁) |
