# 바이오 연구실 런타임 에셋 v2

2026-11-13. 이전 단독 블록 스프라이트 v1을 **현재 게임의 실제 면별 보드 구조**에 맞춰 재가공한 버전이다.

## 게임에서 사용

기존 실행 파일 `build/windows/KSC_Touch_Game.exe`에서 전투에 들어간 뒤 **설정 → 배경 테마 → 바이오 연구실**을 선택한다. 기존 공허·사막 선택은 유지되며, 마지막으로 고른 테마가 저장된다. 게임을 재시작하거나 맵을 다시 만들지 않고 전환된다.

실제 게임 파일: `assets/void_defense_bio/terrain/`, `assets/void_defense_bio/props/`.
연결 코드: `scripts/void_defense/vd_bio_terrain.gd`. 현재 프로젝트의 보드·테마 선택기에 연결 완료.

[실제 전투 캡처](actual_battle.png) · [블록 연결 검수](joined_board.png) · [상승 중 검수](rising_board.png) · [전달 ZIP](bio_lab_runtime_v2.zip)

## 블록 구조

| 항목 | 현재 게임 규격 |
| --- | --- |
| 윗면 폭·높이 | 166.4 × 83.2 |
| 좌우 옆면의 수직 높이 | 66.56 |
| 윗면 기준점 | 블록 도형 좌상단 기준 (83.2, 41.6) |
| 전체 도형 높이 | 149.76 |
| 텍스처 베이크 배율 | 4배, 좌표와 UV는 JSON에 보관 |
| 아틀라스 | 1536 × 1536, 무손실, 밉맵 없음 |

각 디자인을 **윗면·왼쪽 면·오른쪽 면**으로 분리했다.

- `top_01.png` + `side_left_01.png` + `side_right_01.png`: 기본 민트.
- `top_02.png` + `side_left_02.png` + `side_right_02.png`: 새싹 마크.
- `top_03.png` + `side_left_03.png` + `side_right_03.png`: 배수구·뿌리 관찰창.
- `bio-lab-atlas.png`, `bio-lab.json`: 실제 런타임에서 쓰는 아틀라스와 면별 UV/도형 좌표.
- `block_01_game.png` ~ `block_03_game.png`: 동일 런타임 폴리곤을 GPU에서 합친 보조 PNG, 168×152. 게임 윗면 중심 기준점은 (84, 42.6). 현재 보드 렌더러는 합친 PNG 대신 면별 아틀라스를 사용한다.

면별 단독 PNG는 4배 텍스처와 4px 여백을 포함한다. Sprite2D로 따로 그릴 경우 JSON의 `standalone_texture_scale=0.25`, `standalone_sprite_offset`을 사용한다. 아틀라스는 폴리곤 바깥에 색상 여백을 두어 선형 보간 시 투명 틈이 생기지 않게 했다. 단독 PNG의 알파 마스크와 아틀라스의 색상 여백은 용도가 다르다.

## 보존·재가공 방식

v1 생성 마스터의 색과 선을 기준으로 면을 기하학적으로 재투영했다. **이번 재가공에는 이미지 재생성이나 색 보정을 사용하지 않았다.** 윗면의 민트 패널·아이보리 테두리·새싹 표식·배수구와 측면의 배관·조임쇠·뿌리 관찰창을 보존했다.

v1의 짧은 측면을 게임 높이까지 세로로 늘리지 않았다. 장식 띠와 하단 테두리는 본래 크기로 유지하고, 그 사이 하부에 기존 원본의 청록 철제 기둥 표면을 샘플링한 벽을 삽입해 높이를 맞췄다. 따라서 측면 하부의 넓은 철제 벽 영역은 규격에 맞추기 위해 보완한 부분이다. 전체 화면 컨셉 원화의 원본 픽셀을 그대로 잘라낸 무손실 추출이라고 주장하지 않는다.

바닥 패턴은 맵 좌표로 고정되며 이동·재그리기 중 바뀌지 않는다. 기본 바닥을 주로 사용하고, 새싹/배수구는 좌표 해시로 드물게 배치한다. 실제 빈도는 방 모양과 좌표에 따라 달라진다.

후속 [런타임 v3](../bio_lab_props_runtime/README.md)에서 프랍 3종도 실제 게임에 연결했다. 외곽 받침·새 방 생성/도착·테마별 표시·HUD 안쪽 프레이밍까지 적용했으며, 최신 블록+프랍 전달 파일은 v3 ZIP이다.

## 검증

- 실제 Godot 4.7.2 Forward+ / Vulkan 렌더러로 검증.
- 윗면 3종 × 좌우 측면 = 총 9개 면, 게임 상수와 JSON 규격 일치.
- 구멍·모서리·복도 포함 보드에서 윗면 17개, 노출 왼쪽 면 8개, 오른쪽 면 5개가 정확히 그려짐.
- 공유 경계 189개 샘플에서 투명 틈 0.
- 상승 완료 후 정적 화면과 다른 픽셀 0. 테마 전환 중 맵·상승 상태 유지.
- 실제 전투 클리어 → 갈림길 선택 → 방 이동 → 재배치 2회 완료. 아군 4명 생존, 진형 확인 2회.
- 공허·사막·바이오 선택 메뉴 및 개별 설정 저장/복원 확인. 공허 보드의 기존 렌더와 다른 픽셀 0.
- 테마 전환 직전의 지연 저장이 이전 프로필 값을 잃게 하는 문제도 수정.
- 검증 도중 사용자 저장 테마는 바꾸지 않았다. 자동 검증의 테마 선택은 비영구 메모리 설정 또는 docs 아래의 별도 테스트 설정 파일을 사용한다.
- 빌드 검증은 [export_validation.json](export_validation.json), 렌더 검증은 [runtime_validation.json](runtime_validation.json), 테마 검증은 [theme_test.json](theme_test.json)에 기록.
- 전투 러너/캡처 종료 시 기존 캡처에도 있던 ObjectDB 5~7개·리소스 2개 잔류 메시지가 남는다. 기능 검증 실패나 내보내기 오류와는 구분해 로그를 보관했다.

[캡처 실행 로그](battle_stdout.log) · [전투 2회 로그](loop_stdout.log) · [면별 검증 로그](probe_stdout.log) · [테마 회귀 로그](theme_regression_stdout.log)

재가공: 프로젝트 루트에서 `& ./tools/terrain/build_bio_runtime.ps1`.
렌더 검증: `Godot --path . res://tools/test/BioTileProbe.tscn`.
전투 검증: `Godot --path . res://tools/test/BioLabRunner.tscn -- --cycles=2 --speed=4 --out=res://docs/bio_lab_runtime_v2/loop`.

