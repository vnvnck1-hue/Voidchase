# 앞 안개 스타일: 하프톤 (2026-11-09)

전투 화면 오른쪽 위 **설정 → 앞 안개 스타일 → 기체 / 하프톤**, 또는 배경 조정 패널(F10)의 **스타일** 버튼으로 고릅니다. 테마(공허/사막)와는 별개로 고르며 `user://vd_world_theme.cfg`에 `fog_style`로 함께 저장됩니다. 기본은 **기체**(기존 앞 안개).

| 스타일 | 셰이더 | 모양 |
| --- | --- | --- |
| 기체 | 공허 `void_vignette.gdshader` / 사막 `desert_dust.gdshader` | 가장자리를 덮는 흐르는 기체·모래바람 (기존) |
| 하프톤 | 테마 공통 `shaders/halftone_fog.gdshader` | 서브컬처·일본 애니 그래픽의 망점(스크린톤) 그라데이션 |

## 하프톤의 구조

맑은 중앙에서 가장자리로 갈수록

1. 안개 색 도트가 작게 시작해 점점 커지고 (0.82셀에서 이웃과 맞닿음)
2. 솔리드 안개로 합쳐진 뒤
3. 그 안쪽에 **밝은 도트**(반 칸 어긋난 격자)가 경계 근처에서 크고 깊어질수록 작아지며 사라집니다.

도트 격자는 **화면 픽셀 기준**(1080p 기준 px, 해상도에 따라 늘림)이라 카메라 줌·흔들림과 무관하게 고정되고, 기본 45° 회전으로 전형적인 스크린톤 각도입니다. 경계는 느린 fbm 노이즈로 일렁입니다(0이면 매끈한 기하 경계). 색은 배경 컬러를 따라갑니다: 공허는 안개 본색 = 하늘 위쪽(col_deep), 밝은 도트 = 기체 빛(col_glow); 사막은 본색 = 모래 어두운 톤(col_lilac), 밝은 도트 = 모래 빛. 아군 사망·보스 연출의 색 변화도 그대로 얹힙니다.

## 패널 슬라이더 (하프톤일 때만 보임)

| uniform | 이름 | 기본(공허 / 사막) |
| --- | --- | --- |
| `ht_strength` | 세기 | 0.92 / 0.80 |
| `ht_reach` | 범위 (안쪽으로 파고듦) | 0.33 / 0.22 |
| `ht_size` | 도트 간격 (1080p 기준 px) | 14 |
| `ht_angle` | 격자 각도 | 45 |
| `ht_light` | 밝은 도트 띠 | 0.70 / 0.60 |
| `ht_wobble` | 경계 일렁임 | 0.35 |
| `ht_speed` | 흐름 속도 | 0.06 |

기체 스타일의 슬라이더(`strength`, `wisp_*`)와 uniform 이름이 달라 값이 섞이지 않고, 둘 다 테마별 cfg(`vd_nebula.cfg` / `vd_desert.cfg`)에 함께 저장됩니다.

## 구현

- `shaders/halftone_fog.gdshader`: 새 셰이더.
- `scripts/void_defense/vd_world_theme.gd`: `FogStyle`, `FOG_LABELS`, `fog_style` 저장·복원, `foreground()`가 스타일에 따라 셰이더를 고른다.
- `scripts/void_defense/vd_battle.gd`: `set_fog_style()` + 설정 메뉴 [앞 안개 스타일].
- `scripts/void_defense/vd_nebula_tuner.gd`: `HALFTONE_PARAMS`, 스타일 버튼, 스타일별 슬라이더 표시·색·흐름 속도.
- `scripts/scene_switcher.gd`: 드롭다운 이름 `FogStyle` (검증용).

## 실제 화면과 검증

`tools/test/HalftoneFogCapture.tscn`을 서브 모니터에서 실행해 찍었습니다 (설정 파일은 `test_settings/`에 따로 기록).

- `void_gas.png` / `void_halftone.png`, `desert_gas.png` / `desert_halftone.png`: 같은 방에서 스타일만 바꾼 화면.
- `crop_*_halftone.png`: 왼쪽 아래 안개 가장자리 3배 확대.
- `tuner_halftone.png`: 배경 조정 패널(스타일 버튼·하프톤 슬라이더) + 설정 메뉴.

검사 12건 통과(기본 스타일 기체, 테마별 셰이더 선택, 패널 슬라이더 표시 전환, 슬라이더 값 왕복 유지, cfg 복원, 설정 메뉴 항목·전환). 기존 `WorldThemeProbe.tscn` 17건도 통과(공허 보드 픽셀 차이 0).
