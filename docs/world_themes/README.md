# 전투 배경 테마

전투 화면 오른쪽 위 **설정 → 배경 테마 → 공허 / 사막**을 선택합니다. 타일과 배경/앞 안개가 함께 바뀌며, 전투 상태와 유닛 위치, 방 이동·타일 상승 애니메이션은 유지됩니다.

| 구성 | 공허 | 사막 |
| --- | --- | --- |
| 타일 | 기존 보라색 석판과 아치 옆면 | 원화 픽셀을 추출한 모래색 석판과 리벳 테두리 |
| 배경 | 기존 `void_nebula.gdshader` | `desert_sand.gdshader`: 내려다보는 모래 물결, 바람 결, 잔모래 |
| 전경 | 기존 `void_vignette.gdshader` | `desert_dust.gdshader`: 가장자리의 옅고 길게 흐르는 먼지 |
| 유적 프랍 | 기존처럼 표시 | 숨김 |
| 조정값 | 기존 `user://vd_nebula.cfg` 유지 | 별도 `user://vd_desert.cfg` |

마지막 선택은 `user://vd_world_theme.cfg`에 저장합니다. 기록이 없으면 현재 작업 중이던 **사막**을 기본값으로 씁니다. 배경 조정 패널(F10)도 선택한 테마에 맞는 제목과 설명을 표시하며 기본값 복원·저장·색 조정이 테마별로 적용됩니다. 아군 사망과 보스 전투의 배경 연출도 선택한 팔레트 위에 계속 적용됩니다.

## 구현

- `scripts/void_defense/vd_world_theme.gd`: 테마 ID, 표시 이름, 셰이더와 선택 저장.
- `scripts/void_defense/vd_void_terrain.gd`: 이전 공허 보드의 UV·옆면 음영·아치·테두리 그리기를 보존.
- `scripts/void_defense/vd_desert_terrain.gd`: 직전 작업에서 추출한 원화 아틀라스 그대로 사용.
- `scripts/void_defense/vd_board.gd`: 기존 맵/타일 상승 로직에서 선택한 타일 렌더러 호출.
- `scripts/void_defense/vd_battle.gd`: 같은 배경 재질을 유지하면서 테마를 함께 전환. 카메라 패럴랙스·화면 비율·궁극기 어둡게 하기 연동 유지.
- `scripts/scene_switcher.gd`: 기존 설정 메뉴에 목록 선택형 항목 추가.

## 실제 화면과 검증

- `desert_settings.png`, `void_settings.png`: 같은 방에서 설정 목록으로 전환한 실제 화면.
- `desert_battle.png`, `void_battle.png`: 전투 중 전환 화면.
- `desert_wind_a.png`, `desert_wind_b.png`: 카메라를 고정하고 모래/먼지의 흐름 위상을 바꾼 화면.
- `void_legacy_board.png`, `void_theme_board.png`: 사막 도입 이전 보드와 새 공허 테마를 동일한 맵/해상도에서 렌더. **393,216 RGBA 픽셀 중 차이 0**.
- `theme_test.json`, `probe_stdout.log`: 설정 목록의 실제 선택 신호, 전투 상태 유지, 테마별 조정값 분리 저장, 선택 복원, 새 전투 입장, 상승 애니메이션 유지, 잘못된 ID 거부, 모래 흐름을 검사. 모든 검사 통과.

검증은 `tools/test/WorldThemeProbe.tscn`을 일반 Vulkan 실행으로 수행합니다. 설정 파일은 이 폴더의 `test_settings/`에 따로 기록하여 사용자의 실제 선호값에 영향을 주지 않습니다. `reference_void_board.gd`는 저장소 HEAD의 사막 도입 이전 보드 스냅샷이며, 검증에만 사용하고 빌드에는 포함하지 않습니다.

기존 단일 실행 파일 `build/windows/KSC_Touch_Game.exe`를 다시 내보냈습니다. `export_stdout.log`에서 오류 0건, 두 사막 셰이더와 테마/공허 타일 스크립트의 팩 포함을 확인했습니다.
