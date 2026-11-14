# 사막 정거장 타일 — 원화 픽셀 추출본

기준 원화는 `docs/background_concepts_v1/battle_desert_station_v3.png`입니다. 새 그림을 생성하거나 색을 바꾸지 않고, 원화의 가리지 않은 표면 8곳과 양쪽 옆면 2곳을 추출했습니다.

## 결과물

게임용 파일은 `assets/void_defense_desert/terrain/`에 있습니다.

| 파일 | 용도 |
| --- | --- |
| `top_01.png` ~ `top_08.png` | 원래 크기로 자른 투명 배경 윗면 8종 |
| `side_left.png`, `side_right.png` | 원본의 철제 리벳 테두리와 벽면; 반전 없이 각각 사용 |
| `desert-station-atlas.png` | 실제 게임에서 사용하는 무손실 원본 픽셀 아틀라스, 768×432 |
| `desert-station.json` | 원화 좌표, 아틀라스 좌표, UV와 크기 정보 |
| `desert-station-block.png` | 윗면과 두 옆면을 합친 투명 PNG 블록, 168×152. Sprite2D 등에 사용 가능 |

PNG와 JSON만 모은 전달용 압축 파일: `docs/desert_station_tiles/desert_station_textures.zip`.

아틀라스의 각 사각형에는 원본의 여백 2픽셀도 보존합니다. 게임에서는 원화의 실제 테두리 선 중심을 UV 경계로 삼아 다각형 안쪽만 그립니다. 여백의 다른 배경 그림은 게임에 그려지지 않습니다.

`scripts/void_defense/vd_desert_terrain.gd`가 아틀라스를 읽고, `vd_board.gd`가 방과 복도의 바닥에 적용합니다. 기존의 UV 안쪽 잘라내기, 옆면 반전·보라색 착색, 중복 격자선과 유적 테두리 덧그리기는 제거했습니다. 방 모양, 유닛 좌표, 전투·배치 표시, 타일이 솟아오르는 동작은 기존 보드 로직을 사용합니다. 옆면 두께는 원화의 비율에 맞췄습니다. 텍스처는 무손실 압축이며 밉맵을 만들지 않습니다.

## 일치 범위와 검증

- `pixel_check.json`: 투명 마스크 안의 원본 RGB/RGBA 61,701픽셀 비교, 차이 **0**.
- `gpu_pixel_check.json`: Godot Vulkan에서 추출 면을 원화 좌표에 재조립. 경계 3픽셀을 제외한 내부 51,696픽셀 비교, 최대 채널 차이 **0/255**.
- `source_patches.png`: 원화에서 실제로 잘라낸 위치.
- `native_gpu_reassembly.png`: Godot에서 원래 좌표로 그린 투명 재조립 결과.
- `final/shot_01_t5.01.png`: 수정된 타일이 실제 전투 보드에 적용된 최종 캡처.
- 전투 → 방 이동 → 재배치 자동 진행 2회 완료, 진형 유지 2회 확인. 실제 Vulkan 전투 화면도 확인했습니다.
- `export_stdout.log`: 기존 단일 `build/windows/KSC_Touch_Game.exe` 재내보내기 성공, 내보내기 오류 0건. 새 아틀라스·JSON·보드 스크립트가 팩에 포함됐습니다.
- `exported_game_stdout.log`: 내보낸 실행 파일의 기본 로비 진입 확인, 종료 코드 0, 오류 0건. 실제 전투 화면 검증은 위의 프로젝트 Vulkan 캡처로 확인했습니다.

위 픽셀 일치는 **원본 크기 추출본과 원화 좌표 재조립**에 해당합니다. 게임에서는 고정 2:1 격자, 카메라 줌과 화면 해상도에 맞춰 같은 픽셀을 샘플링하므로 보간이 발생합니다. 원화의 각 칸은 미세하게 비정형이고 일부는 캐릭터·UI에 가려져 있으므로, 전체 원화의 모든 타일을 모든 배율에서 픽셀 단위로 동일하게 재현한다는 뜻은 아닙니다. 가려진 부분을 상상해 다시 그리지 않고, 실제로 보이는 원본 타일만 재사용합니다.

## 재생성

프로젝트 루트의 PowerShell에서 원본 크기 추출:

```powershell
& ./tools/terrain/extract_desert_station.ps1
```

Godot 에디터에서 리소스를 가져온 뒤 `tools/test/DesertTerrainCapture.tscn`을 실행하면 GPU 픽셀 검증 결과와 합성 블록 PNG가 갱신됩니다. 이 검증 도구는 배포 빌드에 포함되지 않습니다.
