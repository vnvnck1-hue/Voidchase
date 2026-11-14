# 세 포즈의 잘린 부분 복원 · 개별 투명 PNG

- 제작일: 2026-11-10
- 사용자 요청: 원본의 포즈·디자인·쉐입을 최대한 보존하면서 위아래 잘린 부분을 모두 복원하고 각 캐릭터를 별도 PNG로 분리.
- 이 작업에서는 최신 사용자 요청을 우선해 **원본 세 포즈의 비례와 그림체를 유지**했다. 기존의 새 캐릭터 제작용 2.72H 정규화나 새 스탠딩 포즈를 적용하지 않았다.
- 복원 방식: 내장 image_gen 편집/아웃페인팅으로 각 인물을 개별 복원. 원본 전체와 해당 포즈 확대 크롭을 각각 입력해 이웃 인물의 부분을 구분했다.

## 최종 산출물

모두 **1280×1792, RGBA 투명 배경 PNG**. 인물은 생성된 원화에서 확대·축소하거나 축방향으로 변형하지 않았다. 동일한 캔버스에 투명 여백을 추가하고 위치만 옮겼다. 인물 밑면의 강한 알파 영역을 같은 높이에 맞췄다.

| 파일 | 원본 위치/자세 |
|---|---|
| [01_left_pose.png](png/01_left_pose.png) | 왼쪽: 기울인 머리와 몸, 목 근처에 올린 손과 앞으로 내려온 손 |
| [02_middle_pose.png](png/02_middle_pose.png) | 가운데: 앞으로 내민 손, 두 무릎을 한쪽으로 굽힌 자세 |
| [03_right_pose.png](png/03_right_pose.png) | 오른쪽: 감은 눈과 미소, 팔짱과 굽힌 무릎 |

- [PNG 세 장 ZIP](silver_trio_restored_pngs.zip) — 이미지 세 장만 포함.
- [미리보기](preview.png) — 미리보기만 균일 축소해 나란히 배치했으며, 개별 PNG의 크기/비례는 그대로다.
- [실제 생성 프롬프트](PROMPTS.md)

## 보존 및 복원 범위

원본의 눈/입 표정과 머리 기울기, 앞머리·포니테일·리본/주름 머리끈의 실루엣, 큰 소매, 흰 두 구멍 지퍼 장식, 스커트의 사선 주름, 양말의 의도된 구멍, 장갑/손의 방향, 흰색/보라색 비대칭 레이스업 신발을 보존하는 방향으로 복원했다. 원본의 보이는 부분을 새 포즈나 다른 의상으로 리디자인하지 않았다.

잘린 정수리/머리끝과 신발 앞코·밑창, 옆 인물 뒤에 가려진 일부 윤곽은 주변 선과 색을 바탕으로 추정해 그렸다. 생성형 복원이므로 보이는 원본 픽셀과 완전히 동일한 트레이싱/픽셀 복사는 아니며, 알 수 없는 잘린 부분은 원작의 정확한 원형을 보증하지 않는다. 사용자 원본은 `references/original_trio.png`로 별도 보관했다.

## 투명도와 패키징 검증

- 세 PNG 모두 실제 알파 투명도가 있으며 파일 테두리에 비투명 픽셀 **0개**다. 최종 알파 검사: [final_alpha_report.json](final_alpha_report.json).
- 원화의 보이는 RGB와 알파를 유지한 채 투명 여백만 추가했다. 완전히 투명한 픽셀의 숨은 RGB만 0으로 정리했다. 이것은 RGB만 표시하는 뷰어에서 배경 잔상처럼 보이는 문제를 막기 위한 인코딩 정리이며 실제 보이는 인물은 바꾸지 않는다.
- 패키징 후 다시 읽어 비교한 결과, 원화와의 **알파 차이 0픽셀, 보이는 RGB 차이 0픽셀**, 확대·축소 없음: [packaging_manifest.json](packaging_manifest.json).
- 중간 포즈의 알파를 실제 유색 바탕에 합성해 확인했다. 별도 배경 추출 시도는 최종본으로 선택하지 않고, 더 원본에 가까운 최초 복원 결과의 실제 알파를 사용했다. RGB-only 뷰에서 보이던 잔상 영역은 실제로 알파 0이었다.

검수/패키징 스크립트:

```powershell
./tools/package_restored_trio.ps1
./tools/inspect_png_alpha.ps1 -Paths @('docs/silver_trio_pose_restoration_v1/png/01_left_pose.png','docs/silver_trio_pose_restoration_v1/png/02_middle_pose.png','docs/silver_trio_pose_restoration_v1/png/03_right_pose.png') -ReportPath 'docs/silver_trio_pose_restoration_v1/final_alpha_report.json'
```

패키징 스크립트는 생성 원화의 선이나 형태를 그리는 도구가 아니다. 최종 PNG에 비례 변형 없이 투명 캔버스를 추가하고 검증/ZIP 생성을 수행한다.
