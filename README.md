# KSC Touch Game — Godot 4.7 포팅

Unity 프로젝트 `E:\KSC_250420_2` 의 두 씬을 Godot 4.7로 옮긴 프로젝트입니다.

| Unity 씬 | Godot 씬 |
|---|---|
| `Assets/KSC_251206/Scenes/Touch_Game_demo.unity` | `scenes/Touch_Game_demo.tscn` (메인 씬) |
| `Assets/KSC_251206/Scenes/Touch_Game_demo_anim.unity` | `scenes/Touch_Game_demo_anim.tscn` |

## 실행

Godot 4.7.2 로 `project.godot` 을 열고 실행하면 **로비**(`scenes/Lobby.tscn`, `scripts/lobby.gd`)가 뜹니다. 로비 카드·입장 버튼·숫자키 1~3 으로 터치 게임 데모 / 캐릭터 선택 / VOID DEFENSE 에 들어가고, 모드 안에서 Esc 로 로비에 돌아옵니다. 모드 목록은 `scripts/scene_switcher.gd` 의 `SCENES` 하나로 관리합니다(로비가 이 목록을 읽어 카드를 만든다). 몬스터를 클릭하면
Unity 와 똑같이 파티클·흰색 플래시·스케일 펀치·히트스톱·카메라 셰이크·HP 바 감소가 일어납니다.
모드 씬 안에서는 숫자키 `1`~`4`, `Tab`, 왼쪽 위 버튼으로도 전환할 수 있습니다 (`scripts/scene_switcher.gd` 오토로드; 로비에서는 이 바가 숨겨집니다).

## 좌표/단위 매핑

- 1 Unity unit = 100 px, Y 축 반전, 회전 부호 반전 (Unity CCW → Godot CW).
- 해상도 1920x1080 (Unity PlayerSettings 기본값), 카메라 orthographic size 5 → `Camera2D.zoom = 1.08`.
- SpriteRenderer sorting order → `z_index` (절대값).
- Canvas(Screen Space Overlay, 1920x1080) → `CanvasLayer` + `Control`.

## 스크립트 대응

| Unity (C#) | Godot (GDScript) |
|---|---|
| `MonsterBehavior.cs` | `scripts/monster_behavior.gd` (클릭 판정은 `Area2D` 포인트 쿼리) |
| `HealthBar.cs` | `scripts/health_bar.gd` (`Image.fillAmount` → `TextureProgressBar.value`) |
| `SpriteColorLerp.cs` + `SpriteColorLerp.shader` | `scripts/sprite_color_lerp.gd` + `shaders/sprite_color_lerp.gdshader` |
| `AdvancedSpring2D.cs` | `scripts/advanced_spring_2d.gd` (물리 연산은 Unity 단위계 그대로) |
| `CubeRotator.cs` + 3D Cube | `scripts/cube_rotator.gd`, `SubViewport` 안의 3D 큐브를 `Sprite2D` 로 표시 |
| `ParticleSystem` (25+5개) | `scripts/unity_particles_2d.gd` — Unity 모듈 설정을 그대로 해석하는 CPU 파티클 |
| 2D IK `LimbSolver2D` / `IKManager2D` | `scripts/limb_solver_2d.gd` / `scripts/ik_manager_2d.gd` (Unity 알고리즘 포팅) |
| PSB 리그 (SpriteSkin + 본) | `Skeleton2D` + `Bone2D` + `Polygon2D`(본 가중치) |
| Animator / Timeline (.anim 클립) | `AnimationPlayer` (60fps 로 샘플링한 트랙, 루프) |

## 재생성 (tools/port)

씬은 `tools/port/gen_godot.py` 가 Unity 에서 내보낸 JSON(`tools/port/unity_export`) 으로부터 생성했습니다.

1. `tools/port/GodotExport.cs` 를 Unity 프로젝트의 `Assets/Editor/` 아래에 복사
2. `Unity.exe -batchmode -projectPath E:\KSC_250420_2 -executeMethod GodotExport.Run -exportPath <출력폴더> -quit`
3. `python tools/port/gen_godot.py <출력폴더>` → `scenes/*.tscn`, `assets/textures/*.png` 갱신
4. `Godot --headless --path . --import`

## 빌드 (Windows 실행 파일)

빌드는 **하나**입니다 (`CLAUDE.md` 지침). `export_presets.cfg` 의 유일한 프리셋 "Windows Desktop" 이 Touch 게임 두 씬과 VOID DEFENSE 를 모두 담은
`build/windows/KSC_Touch_Game.exe` (pck 내장, 단일 파일) 를 만듭니다. 실행 중 숫자키 `1`/`2`/`3`, `Tab`, 왼쪽 위 버튼으로 씬을 전환합니다.
씬·프로토타입별 별도 exe 나 프리셋은 만들지 않고, 새 프로토타입은 `scripts/scene_switcher.gd` 의 `SCENES` 에 등록합니다.
프리셋의 exclude 필터는 `tools/*`, `docs/*`, `build/*`, `assets/_backup/*` 와 문서·파이썬·C# 소스를 뺍니다.

```
Godot --headless --path . --export-release "Windows Desktop" build/windows/KSC_Touch_Game.exe
```

아이콘: `tools/build_icon.py` 가 메이드 v2 셋업 포즈(`spine_parts_maid_v2/setup-pose.png`)의 얼굴을 둥근 사각 보라 배경에 올려
`icon_game.png`(256, `config/icon` = 에디터·창 아이콘)와 `icon_game.ico`(256~16 7단계, 프리셋 `application/icon` + `config/windows_native_icon` = exe 아이콘)를 만듭니다.
다른 캐릭터로 바꾸려면 `python tools/build_icon.py <png> --crop x0 y0 x1 y1`(정사각 크롭) 뒤 다시 내보냅니다. 프리셋의 `application/modify_resources=true` 가 있어야 exe 에 박힙니다.

## 테스트

`tools/test/ShotRunner.tscn` 은 씬을 띄우고 지정 시각에 스크린샷을 찍고, `--click` 으로 몬스터 클릭을 시뮬레이션합니다.

```
Godot --path . res://tools/test/ShotRunner.tscn -- --scene=res://scenes/Touch_Game_demo.tscn --out=D:/shots --click --shots=0.5,1.3,2.5 --quit=3
```

## 화면 확장 + 캐릭터 선택 (tools/expand)

`Touch_Game_demo_anim` 씬은 포팅 후 `tools/expand/apply_expansion.py` 로 한 번 더 가공한 상태입니다
(파일 머리의 `; expanded by tools/expand/apply_expansion.py` 주석이 표시). 재생성할 때는
`gen_godot.py` → `apply_expansion.py` 순서로 실행하면 같은 결과가 나옵니다.

| 단계 | 스크립트 | 결과 |
|---|---|---|
| 배경 좌우 확장 | `tools/expand/extend_bg.py` | `assets/textures/main_BG_2_wide.png` (2400x1280, 원본 720px 은 가운데에 그대로, 양옆 840px 은 세 영역의 경계선·그라데이션을 이어서 생성, 오른쪽 가장자리의 실루엣 선은 끊기지 않도록 서서히 사라지게 처리) |
| 캐릭터 패널 분할 | `tools/expand/slice_panels.py` | `assets/textures/char_panels/panel_01..08.png` + `panels.json` (characters_list.png 을 알파 연결 영역으로 잘라 패널마다 한 장, 외곽선용 10px 여백) |
| 씬 패치 | `tools/expand/apply_expansion.py` | 아래 항목 |

씬 패치 내용:

- `BG_all/BG` 텍스처를 확장본으로 교체 (위치·스케일 동일, offset 만 -840px).
- "Olivia" 워터마크 텍스트: 원래 두 대각선(step 778,-163)을 따라 복사본 3개 추가(`Olivia_1 (2)`, `Olivia_2 (2)`, `Olivia_2 (3)`), 같은 이동 트랙을 평행이동해서 붙임.
- `main_character_BG` 애니메이션을 셋으로 분리: 워터마크 흐름(루프 유지) / `EntrancePlayer`의 `entrance`(아바타 슬라이드 인·이름·별·스킬 패널, 1회) / `ListPlayer`의 `list_enter`(선택창 슬라이드 인, 1회).
- `BG_all/characters_list` → `Node2D` + `scripts/character_select.gd`, 자식 `Panel_01..08`(Sprite2D) 을 원본 이미지와 같은 자리에 배치. 빈 패널은 `metadata/empty = true`.

캐릭터 선택 동작 (`scripts/character_select.gd`):

- 패널 클릭(알파 픽셀 기준 판정) / 배경에 그려진 `<` `>` 화살표 클릭 / 키보드 ←→ 로 선택.
- 선택된 패널은 살짝 떠오르며 확대 + 연한 외곽선(`shaders/panel_outline.gdshader`), 마우스 오버 시 약간 밝아짐, 빈 패널은 흔들림.
- 선택이 바뀌면 `entrance` 연출을 다시 재생. 리그된 캐릭터가 Olivia 하나뿐이라 어떤 패널을 골라도 같은 아바타가 나옵니다(임시). `character_selected(index)` 시그널을 내보냅니다.

테스트: `ShotRunner` 에 `--click_world=x,y`(반복 가능, `--click_time`/`--click_interval` 간격) 옵션이 추가되었고,
`tools/test/probe_select.gd` 는 헤드리스로 판정 함수를 점검하고, `tools/test/probe_shader.gd` 는 패널 셰이더가 원본 색을 그대로 내는지 픽셀로 확인합니다(창 필요).

### 스탠딩 원화 + 캐릭터별 등장 (2단계 패치)

`tools/expand/apply_standing.py` 를 `apply_expansion.py` 다음에 실행합니다 (파일 머리 두 번째 주석으로 표시).

- `assets/textures/standing/char_01..07.png`: 캐릭터 스탠딩 원화. 선택창 읽기 순서(왼쪽 위부터)로 01→패널1, 02→패널2, 03→패널3, 07→패널4(오른쪽 위, 원래 빈 칸), 06→패널5(왼쪽 아래, 원래 빈 칸), 04→패널6, 05→패널7. 패널8(원래 반 잘린 캐릭터 자리)은 Olivia: 선택하면 리그된 아바타(`BG_all/avatar`)와 이름 이미지가 켜짐. Olivia 패널 원화는 `tools/expand/capture_olivia.gd`(창 필요)가 리그를 렌더한 `standing/olivia_render.png`.
- `tools/expand/make_portraits.py`: 빈 칸 두 개와 Olivia 패널(`char_panels/new_panel_04.png`, `new_panel_05.png`, `new_panel_08.png`)을 기존 패널과 같은 틀(빈 패널 프레임 + 얼굴 구도 + panel_03 의 LV.2 배지)로 생성. 얼굴 구도는 스크립트 상단 `JOBS` 의 눈/턱 좌표로 조절.
- `BG_all/stand_character` (`scripts/standing_character.gd`): 선택된 패널의 스탠딩 원화를 발 기준으로 표시(`pixel_scale`). 정지 원화에는 리그 아이들과 같은 주기(2.53s)의 절차적 아이들(호흡 스쿼시/스트레치 + 발을 축으로 한 느린 기울임, `breath_scale`/`sway_degrees`/`sway_shift`)을 적용. 입장 트랙은 아바타 트랙을 복사한 것. 이름 이미지(`olivia_2`)는 Olivia 선택 시에만 표시(다른 캐릭터 이름 에셋은 아직 없음).

## 메이드 캐릭터 본 리그 + 아이들 (tools/rig)

`spine_parts_maid_v2/`(파츠 PNG 32장 + `layout.json`, 인수인계 문서 `CLAUDE_HANDOFF.md`)로부터 Olivia 와 같은 방식의
`Skeleton2D` + `Bone2D` 리그를 생성합니다. 씬은 생성물이므로 직접 고치지 말고 스크립트를 수정해 다시 실행합니다.

```
python tools/rig/build_maid_rig.py
Godot --headless --path . --import
```

- 결과: `scenes/characters/maid_rig.tscn` (원점 = 캔버스 바닥 중앙, 단위 = 캔버스 px, 셋업 회전 0°) 과 `assets/textures/maid_rig/*.png`
  (v2 폴더는 `.gdignore` 라 복사본을 씁니다).
- 본 29개: 인수인계 문서의 계층(pelvis → torso → neck → head → ponytail/side_hair/fringe/headpiece/eye/brow/mouth, 팔·다리 3절, skirt, apron, heart_fx).
  파츠는 각 본의 `Sprite2D` 자식이고 `z_index` = `layout.json` 의 `drawOrder` (상대값). 홍채는 흰자 윤곽 폴리곤(`clip_iris_l/r`, `clip_children`) 안에 있어
  시선을 옮겨도 눈꺼풀 밖으로 새지 않습니다. `eye_l/r` 본은 눈꺼풀 선에 피벗이 있어 `scale.y` 를 0 으로 내리면 눈을 감습니다(눈꺼풀은 head 에 남아 감은 선이 됨).
- 애니메이션(`AnimationPlayer`, 60fps 선형 키, 값 트랙): `RESET`, `idle`(5.067 s 루프 = 호흡 2.533 s × 2, autoplay), `rig_check`(인수인계 3절의 검수 포즈: 고개 3°, 포니테일 8°, 홍채 -9,+4 px, 오른 팔꿈치 17°, 무릎 9°).
  `idle` 은 `build_maid_rig.py` 의 `CURVES` 사전(본 → 속성 → f(t))으로 정의: 상체 호흡 상승 4 px + 좌우 기울기, 목·머리 지연 회전, 포니테일·옆머리 팔로스루,
  양팔 미세 흔들림, 하트 부유. 다리·골반은 고정이라 발이 미끄러지지 않습니다.
- **눈 (Olivia `main_character_idle_2` 의 eyes_1/eyes_2/eyes_3 트랙을 수치 분석해 옮김)**: Olivia 는 흰자 본을 축 방향 1→0.60 으로 0.15 s(S커브) 눌렀다가 0.10 s 에 열고,
  눈꺼풀 조각은 0.1 s 먼저 3 % 기어 내려오다 흰자보다 늦게 ×1.45 로 커지며(최대는 흰자 최소와 같은 프레임), 올라올 때 살짝 오버슈트한 뒤 0.3 s 동안 +3 % 로 안정, 깜빡임 사이에는 -6..+3 % 로 느리게 처집니다.
  깜빡임은 1.2~1.35 s 간격의 쌍이고 두 번째 깜빡임이 눈동자 복귀를 숨깁니다. 눈동자는 0.52 s(S커브)에 37 px 옆으로 가서 3 px 되돌아오며 수직으로 느리게 흔들리고 폭이 20 % 넓어졌다가,
  눈이 감긴 3프레임 동안 중앙으로 스냅 → 반대쪽 오버슈트 → 언더슈트 → 안정(감쇠 1회), 폭은 바운스하며 복귀합니다.
  메이드는 눈꺼풀이 래시 선뿐이라 래시 본(`lid_l/r`, 피벗 = 래시 위쪽 가장자리)을 22 px 내리고 ×1.15 두껍게 하면서 흰자+홍채 본(`eye_l/r`, 피벗 = 래시 선)을 0.22 로 눌러 Olivia 처럼 아래에 흰자 한 줄이 남는 반쯤 감은 상태를 만듭니다.
  타임라인: 깜빡임 0.55 / 3.35 / 4.35 s(오른눈은 1프레임 늦음, 눈썹 2.5 px 동반 하강), **왼쪽 쳐다보기** 1.95 s 부터 0.52 s 동안 홍채 -42 px(화면 왼쪽) → 유지(3 px 되돌림·상하 미세 흔들림·폭 +10 %) → 3.50 s 깜빡임 안에서 스냅 복귀·감쇠. 상수는 `BLINKS`, `GLANCE`, `EYE_CLOSED`, `LID_DROP`, `LID_PEAK`.
  얼굴 클로즈업 검수: `capture_maid.gd` 가 `docs/maid_rig/face/` 에 60 fps 프레임을 찍고 `check_maid_render.py` 가 `face_preview.gif` 와 `face_blink_strip.png`/`face_glance_strip.png`/`face_return_strip.png` 를 만듭니다.
- 검수: `Godot --headless --path . -s res://tools/test/probe_maid.gd` (파츠 32개의 셋업 위치가 `layout.json` 과 0 px 오차인지, 본 회전·깜빡임·발 드리프트 샘플).
  렌더 검수는 창이 필요: `Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 -s res://tools/rig/capture_maid.gd` 뒤 `python tools/rig/check_maid_render.py`
  → `docs/maid_rig/` 에 `setup_render.png`(기준 `setup-pose.png` 와 채널 차 8 초과 픽셀 243개, 전부 홍채 클립 가장자리), `setup_diff.png`, `rig_check.png`, `idle_sheet.png`, `idle_preview.gif`.
- **캐릭터 선택 연결**: `apply_standing.py` 의 `RIGS = {패널 index: (노드명, 리그 씬, 스케일)}` 이 리그 씬을 `BG_all/stand_character` 아래에
  인스턴스(`rig_maid`, 숨김·처리 중지, scale 0.32)로 넣고 `StandingCharacter.rigs` 배열에 적습니다. 현재 패널 6(index 5, 검은 머리 메이드 char_04 자리)이 메이드 리그입니다.
  `StandingCharacter` 는 패널에 리그가 있으면 정지 원화·시트 대신 리그를 켜고(다른 리그는 끄고) Olivia 와 같은 방식의 리그 드롭 섀도(`<리그명>DropShadow` CanvasGroup)를 만듭니다.
  입장 연출은 `stand_character` 위치 트랙을 그대로 타고, 리그 원점이 발이라 추가 보정이 없습니다. 이름 이미지는 여전히 Olivia 전용입니다.
  검수: `probe_standing.gd`(헤드리스, 패널 5 ↔ 7 전환까지 확인) 와 `tools/test/capture_maid_panel.gd`(창 필요, `docs/maid_rig/panel_shots/`).

## 화면 글리치 (아군 피격 · 성좌판 침식)

`scripts/void_defense/vd_screen_glitch.gd` + `shaders/screen_glitch.gdshader`. 아군이 피해를 받거나 공허가 성좌판을 침식하면 HUD 위 전체 화면 레이어(CanvasLayer 13)에서 화면이 가로 띠로 찢어지며 왼쪽은 청록, 오른쪽은 자홍으로 갈라지고, 밝은 부분(캐릭터·HUD)에 납작한 청록/자홍 잔상이 남습니다 (틱톡식 글리치). '나쁜 피해'를 강조하는 연출이라 전체가 살짝 어두워집니다.

- **피격**: 기존 카드 피격 글리치(`VDHurtGlitch.on_hit`)와 같은 순간·같은 세기로 발동. 약 0.3초, 빠르게 사그라듦. 세기는 피해 비율·보스 여부를 따르고 `hit_scale`(피격 세기 배율, 기본 0.5)을 곱합니다.
- **침식**: `VDBattle._relic_rewards` 에서 성좌판이 침식될 때. 약 1초, 세 번 맥동하며 더 어둡게.
- 실제 시간으로 돌아 히트스탑 중에도 움직입니다. 설정 → **화면 글리치** 로 끄고, **F9 글리치 조정** 패널 아래 '화면 글리치' 칸에서 값을 바꿉니다 (`user://vd_screen_glitch.cfg`). [화면 침식] 버튼으로 침식 연출을 바로 볼 수 있습니다.
- **패배**: `VDBattle._do_game_over` 에서 `kick(1.0, "defeat")`. 약 2.6초 — 처음 1/4 동안 큰 폭발이 가라앉고, 그 뒤로 낮게 들끓으며 박자마다 가끔 튀고 굵은 띠가 통째로 검정/청록/자홍 평면으로 끊깁니다(`dropout`). 흑백 바램과 겹치고, "거점 함락" 배너와 패널이 뜨는 자리는 `burst_rect` 로 그 영역만 글리치되며 가라앉습니다. 캡처: `tools/test/DefeatCapture.tscn` → `docs/defeat_glitch/`.
- 캡처: `tools/test/ScreenGlitchCapture.tscn` → `docs/screen_glitch/` (슬로모션 연속 프레임 strip_hit/strip_corrupt, 최고점 peak_*, 실제 전투 real_*).

## 유물 보상 카드 글리치 등장

`shaders/ui_glitch_in.gdshader` 를 건 CanvasGroup 으로 보상 카드와 제목을 한 장씩 감싸, 흰 섬광 실루엣 → 청록/자홍 띠 → 가로 띠가 좌우로 튀며 난수 순서로 켜짐 → 또렷해짐 순으로 물질화합니다 (사이파이 UI). 카드마다 0.14초씩 늦게 시작하고 한 장이 0.55초에 끝나며, 끝나면 머티리얼을 떼어 평소대로 그립니다 (`VDRelicHud._glitch_in`). 캡처: `tools/test/RelicOfferCapture.tscn` → `docs/relic_offer/`.

## 화면 CRT 효과 (전 씬 공통)

`scripts/crt_overlay.gd` + `shaders/crt.gdshader`. SceneSwitcher 가 모든 씬 위(CanvasLayer 99)에 전체 화면 ColorRect 하나를 두고 스크린 텍스처를 브라운관처럼 다시 그립니다. 오른쪽 위 **설정 → CRT 효과**에서 프리셋을 고르고, **F6** 으로 다음 프리셋, **F7** 로 조정 패널(`scripts/crt_tuner.gd`)을 엽니다. 설정 메뉴·조정 패널은 CRT 위 레이어라 선명합니다.

| 프리셋 | 느낌 |
| --- | --- |
| 끄기 | 효과 없음 |
| 은은한 모니터 | 평면 · 가는 주사선 · 살짝 번짐. 원화 선을 거의 건드리지 않음 |
| 클래식 브라운관 | 살짝 휜 유리 · 주사선 · RGB 줄무늬 · 색수차 |
| 아케이드 | 굵은 주사선 · 진한 형광체 · 강한 블룸 · 높은 채도 |
| 공허 보라 형광체 | 보라 기운 도는 형광체 · 부드러운 블룸 · 느리게 흘러내리는 띠 (게임 색감에 맞춘 것) |
| 낡은 TV | 많이 휜 화면 · 색 번짐 · 노이즈 · 떨림 · 흘러내리는 띠 |

슬라이더로 손본 값과 고른 프리셋은 `user://crt.cfg` 에 저장되고, **[값 복사]** 로 `PRESETS` 에 붙여 넣을 사전 문자열을 복사합니다. 주사선·줄무늬 간격은 실제 픽셀 정수로 맞춰 해상도가 달라도 모아레가 생기지 않습니다. 캡처: `tools/test/CrtCapture.tscn` → `docs/crt/` (전투·로비 × 프리셋, 확대, 모음 시트).

## 알려진 차이

- 3D 큐브의 조명은 Unity 기본 스카이박스 앰비언트를 근사한 것입니다.
- 파티클 Noise 모듈은 FastNoiseLite 로 근사합니다(Unity 노이즈 필드와 수치가 다를 수 있음).
- Timeline(PlayableDirector)은 한 번 재생 후 Animator 가 이어받는 구조였는데, 결과적으로 같은 클립을 루프하므로 `AnimationPlayer` 루프로 대체했습니다.
- `EventSystem`, `GraphicRaycaster`, `CanvasScaler` 는 Godot 에서 필요 없어 생략했습니다.

## VOID DEFENSE 그레이박스 프로토타입 (scenes/void_defense)

`docs/VoidDefense_기획안.md` 의 전투 루프를 색 박스로 만든 프로토타입입니다. 맵은 10x6 전투 방이 복도로 이어지는
절차 생성 그래프이고(`vd_map.gd`), 방을 클리어하면 출구가 1~2개 생겨 갈림길이면 플레이어가 길을 고릅니다(빛나는 복도 클릭 또는 버튼).
분대는 복도를 따라 다음 방으로 걸어가 **배치 완료 때 저장한 진형(방 로컬 a,c)** 그대로 자리 잡고, 전투는 다시 `배치 완료 ▶` 를 눌러야 시작됩니다. 로비에서 3번 카드로 들어갑니다(모드 안에서는 `4` 키·왼쪽 위 버튼).

- 방 모양은 `vd_map.gd` 의 `TEMPLATES` 3종(전장 10x6 직사각형 · 협곡 10x8 가운데가 좁음 · 광장 10x8 모서리 깎인 마당, 적은 위아래 모서리 주머니에서 등장) 중 무작위. 문자 마스크 A(아군 배치)·E(적 등장)·.(바닥)로 구역을 정하고, 어느 모양이든 입구 (0,2~3)·앞 출구 (9,2~3)·옆 출구 (6~7, 가장자리)에 바닥이 있어야 합니다.
- 새 방에 도착해 분대가 저장한 진형(그 모양의 아군 구역에 없으면 가장 가까운 아군 칸)으로 자리 잡으면 **적이 먼저 등장**해 배치 단계에서 위치가 보입니다. 하늘색 구역 안에서 영웅을 드래그해 옮긴 뒤 `배치 완료 ▶` 를 누르면 "전투 개시" 연출 뒤 전투가 시작됩니다(등장 중에 누르면 끝난 뒤 시작). 전투는 방 안에 갇힙니다.
- `--vdseed=N` 인자로 맵 생성을 재현할 수 있습니다(시드 2 = 첫 방 협곡). 모양별 캡처: `docs/room_shots/`.
- 전투: 전원 자동. 기사(근접) / 건너·마법사(사거리 3) / 힐러(체력 75% 미만 아군 회복). 5웨이브마다 보스 + 상단 보스 바.
- 클리어: 영웅이 배치 위치로 돌아가며 +50 회복, 적 처치로 모은 공허 정수가 우상단에 누적. 전멸 시 `다시 도전`.
- 코드: `scripts/void_defense/vd_data.gd`(수치·좌표) · `vd_unit.gd`(유닛) · `vd_map.gd`(방·복도 절차 생성) · `vd_board.gd`(맵 렌더) · `vd_fx.gd`(이펙트) · `vd_audio.gd`(효과음 풀) · `vd_battle.gd`(상태 머신·HUD).
- 사운드: `assets/audio/void_defense/` (마녀산장·타워대시·헥스 블레이드에서 가져옴, 출처는 같은 폴더의 `SOURCES.md`). 볼륨은 `vd_audio.gd` 의 `VOLUME_DB` 표에서 조절.
- VFX: `assets/vfx/void_defense/` 플립북 시트(타워대시·헥스 블레이드·VFX연구에서 가져옴, 출처는 같은 폴더의 `SOURCES.md`)를 `vd_vfx.gd` 가 재생. 기사 베기 궤적+강타 스파크, 건너 총구 섬광+예광+핑크 스파크, 마법사 에너지 오브 투사체+폭발(명중은 0.22초 뒤), 힐러 마법진+회복 반짝임, 적 등장 포털, 처치 폭발, 보스 등장·처치 충격파, 이동·배치 먼지, 복도 출발 바람, 영웅 전투불능 번개. 크기·색은 `vd_battle.gd` 의 `_attack_vfx` / `_hit_vfx` 에서 조절.
- 피해 숫자: 헥스 블레이드 `scripts/presentation/damage_log.gd` 를 `vd_damage_log.gd` 로 가져옴(ARCO 글꼴 `assets/fonts/ARCO.otf`, SIL OFL). 팝·세로 눌림·위로 튀는 포물선(BOUNCE 기본, `--dmglog=stack`)·강타 기울기·연타 열기 색은 원본 그대로, 글자 크기만 40/60(강타: 피해 50 이상 또는 보스)으로 맞춤. 회복·정수는 같은 글꼴의 상태 글자(`spawn_status`).

자동 테스트 (배치 완료를 누르고 N웨이브가 클리어되어 배치 단계로 돌아오는지 확인, 창이 있으면 단계별 스크린샷 저장):

```
Godot --headless --path . res://tools/test/VDRunner.tscn -- --cycles=2 --speed=4
Godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDRunner.tscn -- --cycles=1 --out=D:/shots
```

마지막 실행 스크린샷: `docs/greybox_shots/`.

### 배경 테마

VOID DEFENSE 전투 화면에서 오른쪽 위 **설정 → 배경 테마**로 전환합니다.

- **공허**: 기존 보라색 유적 타일·푸른 공허 기체·앞 안개·떠 있는 유적 프랍.
- **사막**: 원화에서 직접 추출한 사막 타일·황토색 모래 물결·한 방향으로 흐르는 잔모래와 먼지. 공허 프랍은 숨깁니다.

전투나 방 이동을 다시 시작하지 않고 즉시 전환됩니다. 마지막 선택은 `user://vd_world_theme.cfg`에 저장하며, 선택 기록이 없으면 사막으로 시작합니다. **배경 조정(F10)** 값은 공허의 기존 `user://vd_nebula.cfg`와 사막의 `user://vd_desert.cfg`에 각각 보존합니다.

구현·화면·검증 결과는 `docs/world_themes/README.md`를 참고하세요.

### 실행 파일

별도 exe 는 없습니다. 위 "빌드" 절의 `KSC_Touch_Game.exe` 하나에 들어 있고, 실행 후 `3` 키(또는 왼쪽 위 `3: VoidDefense_greybox` 버튼)로 들어갑니다.
(2026-11-04 까지 있던 "VoidDefense Windows" 프리셋과 `build/windows/VoidDefense.exe`, `project.godot` 의 `*.void_defense` 기능 태그 오버라이드는 빌드 단일화로 제거했습니다.
`icon_void.ico`/`icon_void.png` 는 남겨 두었습니다.)

로비 전환 점검 (로비 → 각 모드 → Esc 복귀, 창이 있으면 `--out=` 으로 캡처):

```
Godot --headless --path . res://tools/test/LobbyProbe.tscn
```
