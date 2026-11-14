# TrioChess 부분 이식 — 스테이지·웨이브 / 기믹 무리 / 적 HP 바 / 레벨업·스킬 레벨업

작성일: 2026-11-08
원본: `세명이 오리라/godot/scripts/` (TrioChess, Godot 4) — `defs.gd` `waves.gd` `main.gd` `march_main.gd` `specials.gd` `hud.gd` `stats.gd`
대상: VOID DEFENSE (`scripts/void_defense/`)

TrioChess 에서 네 가지만 떼어 왔다. 수치는 TrioChess 것을 출발점으로 쓰되 VD 의 기존 체감(적 잔재 90/6, 영웅 4인, 방 단위 진행)에 맞췄다.

## 1. 스테이지 = 방, 그 안의 웨이브 (TrioChess 무리 → 서브웨이브)

| | TrioChess | VOID DEFENSE (이식) |
|---|---|---|
| 단위 | 무리(group) 하나 = 서브웨이브 1~3개 (`sub_wave_count`: 20무리↑ 2, 25무리↑ 3) | 방 하나 = **스테이지** 하나 = 웨이브 2개(첫 스테이지) / 3개(그 뒤) |
| 웨이브 사이 | 0.8초 뒤 다음 서브웨이브, "N차 웨이브!" 배너, 회복·재배치 없음 | 같다 (`VDData.SUBWAVE_DELAY` 0.8초 실제 시간, 얇은 배너, 기절·가드만 해제) |
| 등장 위치 | 영웅에게서 2.8칸 이상 떨어진 앞쪽 | 방의 E 구역(균열) → 모자라면 아군 구역 밖 아무 데나 |
| 보스 | 10무리마다 중간보스 | `BOSS_EVERY` 5 스테이지마다 마지막 웨이브에 공허 군주 |
| 스케일링 | `1.2 × 1.07^(wave-1)` | `1.07^(wave-1)` (기본 배율 1). wave 는 누적 웨이브 — 스테이지마다 ×1.23, 보스 스테이지 다섯마다 ×2.8 |
| 적 수 | `3 + 0.5w` (최대 10) | `3 + 0.5·stage + (웨이브 순서 - 1)` (3~9) |
| 클리어 후 | 결정 +2, 영웅 50 회복, 10무리마다 퍼크 | 기존 그대로: 치료 성공 배너 → 정수 회수 → 50 회복 → (3스테이지마다) 유물 → 길 선택 |

변수 (`vd_battle.gd`): `stage`(방 순서), `wave_in_stage`, `wave`(누적, 난이도·증원·오염 기준). HUD 왼쪽 위 `스테이지 N · WAVE w/W (· 보스)(· 기믹: …)`, 오른쪽 명판 `W<웨이브> - S<스테이지>`.
유물 보상 주기(`RELIC_EVERY` 3)와 침식 확정은 **스테이지** 기준으로 바꿨다 (전엔 방 = 웨이브라 같은 뜻이었다).

## 2. 기믹 무리 (TrioChess GIMMICKS)

스테이지 2부터 45% 확률로 스테이지의 웨이브 하나가 기믹 무리로 바뀐다 (보스 스테이지의 마지막 웨이브는 제외). 안내문은 그 웨이브가 등장할 때 띄운다. 구성·수치 `VDData.GIMMICKS` / `VDData.ENEMIES`, 행동 `vd_gimmicks.gd`.

| TrioChess | 공허 이름 | 구성 | 기믹 |
|---|---|---|---|
| goblinRaid | **잔재 떼 습격** | 포자 2 + 잔재 떼 6 | 작고 빠른 물량 (56/5) |
| ninjaRaid | **균열 암살자 습격** | 포자 1 + 암살자 3 | 가장 먼 영웅을 노리고, 사거리 밖이면 1.7초마다 그 곁으로 도약(0.32초) → 착지 즉시 공격 |
| splitterRaid | **분열 잔재 습격** | 포자 1 + 분열 잔재 4 | 쓰러지면 옆 빈 칸에 소잔재 2 (현재 웨이브 배율) |
| sprinterRaid | **공허 추적자 습격** | 포자 1 + 추적자 3 | 걷지 않고 0.76초마다 2칸 질주(0.18초), 재사용 대기 중엔 제자리 |
| hydra | **공허 촉수** | 촉수 4 | 쓰러지고 2초 뒤 체력 가득 부활. 네 머리가 동시에 쓰러져 있어야 처치 (임시 사망은 정수·경험치 없음) |
| illusionist | **공허 환술사** | 환술사 1 + 환영 4 | 환술사가 살아 있는 동안 환영은 무적(IMMUNE, 반투명). 환술사가 쓰러지면 "실체화!" |

스탯은 TrioChess 값에 VD 잔재 비율(체력 ×2.57, 공격 ×0.75)을 곱했다. 전용 원화가 올 때까지 기존 적 비주얼에 배율·틴트만 바꿔 쓴다 (`VDRig.ENEMY_ALIAS`; 원화 요청은 `CODEX_REQUESTS.md`).
테스트·캡처: `--vdgimmick=<id>` 또는 `VDBattle.force_gimmick` 으로 모든 스테이지 첫 웨이브를 그 기믹으로 강제.

## 3. 적 HP 바 (TrioChess hud.gd register_unit)

`vd_unit.gd _draw_overlay`: 폭 64(대형·보스 110) × 높이 12, 둥근 먹색 받침(`16121f`), 주황 잔상(`f2900f`, 초당 70%p) → 채움(아군 `76cd2b`, 적 `ef3f55`) → 위쪽 흰 광택 띠. 체력이 가득 차 있어도 늘 그린다.
TrioChess 처럼 **적 바는 교전이 시작될 때 붙는다** (`show_bar`, 배치 단계엔 이름만, BATTLE 진입 때 바가 흔들리며 나타남). 아군 바 왼쪽엔 금색 `Lv.N` 배지. 상단 보스 바는 기존 그대로.

## 4. 레벨업 · 스킬 레벨업 (TrioChess grant_exp/_level_up + 스킬북 fx × 레벨)

`vd_growth.gd` (한 판 안에서만 유지):

- 경험치: 처치한 영웅 `EXP_PER_KILL` 25 × (1 + 적 tier). 나머지 살아 있는 영웅은 그 25% (VD 추가 — TrioChess 는 처치자만. 힐러·기사가 굶지 않게). 필요치 `50 × L`, 남는 건 이월.
- 레벨업: 최대 체력 +15, 공격력 +8, 30 회복, **SP +1**. 연출: 금빛 폭발·번개 기둥·"LEVEL UP!"·차임·카드 톡. 분대 카드 오른쪽 아래 `LV.N` 배지(시안), 남은 SP 는 카드 오른쪽 위 붉은 점.
- 스킬 4칸 (`VDData.HERO_SKILLS`, 최대 Lv5, fx × 레벨 합산 = TrioChess `skill_fx`):

| 영웅 | 1 고유 스킬 숙련 | 2 궁극기 숙련 | 3 | 4 |
|---|---|---|---|---|
| 기사 | 강습 피해 +25%·기절 +0.2초 | 충격파 피해 +20%·기절 +0.15초 | 철벽: 받는 피해 -5% | 생명력: 최대 체력 +30 |
| 건너 | 다중 사격 피해 +10%, 3·5레벨 대상 +1 | 집중 포화 피해 +20% | 속사: 공속 +6% | 치명타: +6% |
| 마법사 | 절대 영도 피해 +25%·빙결 +0.2초 | 체인 라이트닝 피해 +15%, 2·4레벨 튕김 +1 | 마력 증폭: 평타 피해 +7% | 빙결: 평타 빙결 확률 +7% (0.6초) |
| 힐러 | 축복 회복 +25% | 부활 체력 +10%·전체 회복 +15% | 은총: 회복량 +10% | 마나 순환: 마나 획득 +12% |

고유 스킬·궁극기는 `growth.skill_def()/ult_def()` 가 보정한 복사본을 `VDSkills`/`VDUlts` 가 쓴다. 평타 보정은 유닛 필드(`dmg_reduce` `dmg_bonus` `crit_bonus` `atk_speed` `mana_mult` `heal_bonus` `freeze_chance` `bonus_hp`).

### 스킬창 (시안 PSD `캐릭터 스킬창` 레이어)

`vd_skill_window.gd` + 생성물 `vd_skill_window_layout.gd` (`tools/battle_ui/extract_skill_window.py`). 시안의 상자는 세로변이 수직인 채 가로변만 -5.47° 기운 평행사변형이라, 기울기를 뺀 사각형을 뽑아 두고 그릴 때 Transform2D 로 다시 기울인다. 보라 본체 + 머리띠(이름) + 정보 4줄 + 스킬 4줄(아이콘 상자·이름·Lv·핍 5개·설명) + 아래 말꼬리. 가리킨 줄은 시안의 흰 강조 줄(더 크고 왼쪽으로 튀어나옴).
배치·회복·길 선택 단계에 **분대 카드를 누르면** 그 영웅 것이 열리고(전투 중 카드 탭은 궁극기), 줄을 누르면 SP 로 올린다(`UP` 알약). 전투가 시작되면 닫힌다. 스킬 아이콘은 `assets/textures/skill_icons/<skill id>.png` 가 있으면 쓰고 없으면 이름 첫 글자.

## 테스트

```
Godot --headless --path . res://tools/test/VDGimmickProbe.tscn -- --speed=6
Godot --headless --path . res://tools/test/VDRunner.tscn -- --cycles=2 --speed=6
Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDGimmickProbe.tscn -- --gimmicks=splitter_raid,hydra --speed=2 --out=<폴더>
```

`VDGimmickProbe` 는 성장 API(SP 지급 → 스킬 올림 → 수치 확인)를 보고, 기믹 6종을 차례로 강제해 스테이지(웨이브 2개)를 치우며 팩 구성·HP 바 표시 시점·서브웨이브·기믹 행동 횟수·레벨업을 확인한다. 2026-11-08 PASS (`shots/` 에 캡처).
