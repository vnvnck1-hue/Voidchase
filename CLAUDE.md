# 프로젝트 지침 (미소녀 카드게임 · Godot 4.7)

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
