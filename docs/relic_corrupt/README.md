# 성좌판 침식 칸 셰이더 (2026-11-09)

예전 침식 칸(보라 링 + 도는 선 3줄, 침식 순간 폴리라인 균열)을 사이파이 VisualShader 두 종으로 바꿨다.
설정 메뉴(톱니) **[침식 스타일]** 에서 고르고 `user://relic_corrupt.cfg` 에 저장된다.

| 프리셋 | 셰이더 | 모습 |
|---|---|---|
| 0 데이터 붕괴 | `shaders/relic_corrupt_glitch.tres` | 가로 찢김 · 블록 단위로 갉아먹는 침식 전선 · 깜빡이는 자홍/청록 오염 블록 · 위아래로 훑는 스캔 막대 · 흘러내리는 데드 픽셀 · RGB 분리 테두리 · 깜빡이는 깨진 경고 육각과 느낌표 |
| 1 나노 감염 | `shaders/relic_corrupt_infect.tres` | 가운데 특이점(검은 핵 + 도는 강착 고리) · 체비쇼프 보로노이 회로 혈관과 바깥으로 흐르는 청록 맥동 · 감염되는 나노 격자 · 빨려 드는 사각 입자 · 테두리에서 뻗는 촉수 |

- 생성: `Godot --headless --path . -s res://tools/shaders/build_relic_corrupt.gd` (손으로 고치지 않는다). 함수는 Global Expression, 좌표 → 왜곡 → 본체를 Expression 노드로 잇고 값은 파라미터 노드.
- HUD(`scripts/void_defense/relics/vd_relic_hud.gd` `_sync_corrupt`)가 침식 칸마다 200×180 ColorRect 를 HUD 그림 뒤에 깔고 `spawn`(0.75초에 퍼짐 / 정화 때 0.5초에 걷힘) · `hover` · `jolt`(침식 순간·정화 거절 때 튐) · `seed` 를 넣는다. "침식 −25%" 라벨·툴팁은 그대로 위에 그려진다.
- 정화 연출도 금빛 고리 + 별가루 → 청록 육각 스캔 링 + 사각 파편으로 바꿨다.
- 캡처: `tools/test/RelicCorruptCapture.tscn -- --out=res://docs/relic_corrupt/<이름>/ --style=0|1` (창 필요, 서브 모니터). 비교 시트 `presets_board.png` · `presets_cells.png`.
