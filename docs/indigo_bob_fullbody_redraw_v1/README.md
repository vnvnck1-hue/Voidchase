# 남보라 단발 캐릭터 — 전신 완성 및 그림체 정리 v1

- 제작일: 2026-11-10
- 요청: 사용자 첨부의 픽셀 느낌과 잘린 하반신을 정리하고, 프로젝트 캐릭터 규격에 맞게 화질을 높여 전신으로 다시 그리기.
- 방식: 내장 image_gen으로 신규 렌더 및 비례 보정. 단순 확대 필터를 적용한 파일이 아님.
- 결과: [`indigo_bob_fullbody_v1.png`](indigo_bob_fullbody_v1.png), **968×1625 PNG**, 흰 배경. 런타임 미연결 검토용 원화.
- 사용자 원본: [`design_reference.png`](design_reference.png). 원본은 수정하지 않고 보관.

## 디자인 적용

남보라색 각진 단발·길게 내려오는 옆머리·왼쪽으로 뒤집힌 머리끝, 호박색 눈, 비스듬한 눈꺼풀과 눈썹, 자신감 있는 비대칭 미소, 연보라 지퍼 후드와 크림색 골지 상의를 유지했다. 원본의 낮은 해상도와 계단형 윤곽은 부드러운 굵은 잉크선과 셀 명암으로 다시 그렸다.

보이지 않던 하반신은 짙은 플리츠 치마, 무릎 양말, 캐주얼 신발로 완성했다. 하반신 의상은 원본에서 확인할 수 없는 부분을 기존 옷차림과 이어지도록 보완한 디자인이다.

## 비례 검수

기준: `../character_style_reference/proportions/README.md`. 주 머리 정수리~턱의 수직 높이를 H로 측정한다. 외곽으로 삐친 머리끝과 양옆 긴 머리는 머리 높이에 포함하지 않는다. 관절은 옷과 포즈에 따라 불명확하여 수동 추정이다.

| 지점 | 최종 y(px) | 정수리 기준 H |
|---|---:|---:|
| 정수리 | 35 | 0.00 |
| 턱 | 575 | 1.00 |
| 어깨(추정) | 615 | 1.07 |
| 허리(추정) | 805 | 1.43 |
| 가랑이(추정) | 980 | 1.75 |
| 무릎 | 1170 | 2.10 |
| 발바닥 | 1495 | **2.70** |

H=540px, `(1495-35)/540 = 2.7037H`. 최초 원화 네 장의 관찰 범위 약 **2.67~2.80H** 안에 들어온다. 어깨·허리·골반·무릎의 추정 비율도 최초 원화에서 관찰한 범위 안이다. 소수점은 계산 결과이며 수동 윤곽 판독의 정밀도를 의미하지 않는다.

- [동일 H로 정렬한 원화 네 장과 최종본](proportions/reference_comparison.png)
- [경계 판독용 좌표선](landmark_audit.png)
- [좌표 입력](candidate_landmarks.json)
- [측정 결과 JSON](proportions/landmarks.json)
- [생성에 사용한 비례 가이드와 외형 참고](construction_and_design.png)
- [전체 생성·보정 프롬프트](PROMPT.md)

재검수 명령(프로젝트 루트):

```powershell
./tools/analyze_character_proportions.ps1 -OutputDir 'docs/indigo_bob_fullbody_redraw_v1/proportions' -CandidateJson 'docs/indigo_bob_fullbody_redraw_v1/candidate_landmarks.json'
```

검수 스크립트는 지정 좌표에서 계산한 전신 비율이 최초 원화의 범위 밖이면 실패한다. 좌표 자체를 자동 검출하는 도구는 아니므로 시각 판독과 비교표 확인도 함께 수행한다.
