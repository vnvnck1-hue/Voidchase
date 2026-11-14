# 프로젝트 지침 (미소녀 카드게임 · Godot 4.7)

## 캐릭터 그림체 최상위 기준
- 2026-11-10 사용자가 지정한 **그룹 22.png, 그룹 30.png, 그룹 32.png, 레이어 193.png** 네 장을 캐릭터 그림체의 최상위 기준으로 삼는다.
- 원본 보관 및 세부 적용 지침: [`docs/character_style_reference/README.md`](docs/character_style_reference/README.md). 캐릭터 제작·수정·생성·검수 시 문서와 기준 이미지 네 장을 먼저 확인한다. 이전 캐릭터 스타일 프롬프트나 컨셉과 충돌하면 이 기준을 우선한다.
- 선화는 필압에 따른 굵기·강약 변화와 자연스럽게 가늘어지는 획 끝, 미세한 붓결이 느껴지는 손그림 선을 기준으로 한다. 일률적인 굵기와 지나치게 매끈한 벡터형 선은 지양하며, 제작 지시와 검수에 함께 반영한다.

## 빌드는 하나로 통일한다
- Windows 실행 파일은 **`build/windows/KSC_Touch_Game.exe` 하나**만 만든다. `export_presets.cfg` 의 프리셋도 "Windows Desktop" 하나만 둔다.
- 씬·프로토타입(VOID DEFENSE 등)마다 별도 exe 나 별도 프리셋을 만들지 않는다. 새 프로토타입은 `scripts/scene_switcher.gd` 의 `SCENES` 에 등록해 같은 exe 안에서 숫자키·버튼으로 전환한다.
- 기능 태그(`custom_features`)로 메인 씬·아이콘을 바꿔 내보내는 방식도 쓰지 않는다. 메인 씬을 바꾸려면 `project.godot` 의 `run/main_scene` 을 바꾼다.
- 내보내기 명령 (프리셋의 exclude 필터가 `tools/*`, `docs/*`, `build/*`, `assets/_backup/*`, 문서·스크립트 소스를 제외한다):

```
Godot --headless --path . --export-release "Windows Desktop" build/windows/KSC_Touch_Game.exe
```

- 빌드에 영향을 주는 변경(씬·스크립트·에셋)을 마쳤으면 이 명령으로 다시 내보내고, 내보내기 로그에서 ERROR 0건과 바뀐 파일이 팩에 들어갔는지 확인한다.
- exe·창 아이콘은 `icon_game.ico` / `icon_game.png` 하나다. `tools/build_icon.py` 로 캐릭터 얼굴에서 생성하며, 손으로 다른 아이콘 파일을 프리셋에 넣지 않는다.

## 씬은 생성물이다
- `scenes/*.tscn` 은 `tools/port/gen_godot.py` → `tools/expand/apply_expansion.py` → `tools/expand/apply_standing.py` 로, `scenes/characters/maid_rig.tscn` 은 `tools/rig/build_maid_rig.py` 로 생성한다. 손으로 고치지 말고 스크립트를 고쳐 다시 실행한다.
