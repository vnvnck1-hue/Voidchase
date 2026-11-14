# 은회색 양갈래 · 분홍 후드 캐릭터 v1

- 제작일: 2026-11-10
- 방식: 내장 image_gen으로 생성 후 비례 보정.
- 사용자 요청: 첨부 원화의 외형 디자인을 활용해 프로젝트 캐릭터 그리기.
- 최종 원화: [`silver_twintail_pink_hoodie_v1.png`](silver_twintail_pink_hoodie_v1.png), **1047×1501 PNG**, 흰 배경. 런타임 미연결.
- 사용자 원본: [`design_reference.png`](design_reference.png). 수정 없이 보관.

## 외형 디자인 적용

은회색의 긴 양갈래 머리와 짧은 앞머리, 황금빛 연두 눈, 반쯤 감긴 눈과 작게 벌어진 입, 턱에 손을 댄 자세를 사용했다. 어깨가 드러나는 분홍 크롭 후드, 흰색의 높은 허리 플리츠 스커트형 반바지와 두 개의 금색 단추, 흰 스캘럽 장식이 있는 분홍 긴 양말을 단순화했다. 보이지 않던 발은 흰색·분홍색 캐주얼 신발로 완성했다. 원본의 옷 위 필기체는 그림체와 큰 디자인 요소에 집중하기 위해 생략했다.

원본의 사실적인 신체·광택·모발 묘사 대신 최초 원화 네 장의 굵은 외곽선, 큰 머리와 짧은 몸통, 넓은 셀 명암과 간결한 표정을 적용했다. 독립 양갈래의 길이와 폭은 실제 머리 높이에 포함하지 않는다.

## 비례 검수

`../character_style_reference/proportions/README.md`에 정의한 동일 H를 사용한다. 주 머리 정수리 y204, 턱 y630 → **H=426px**. 발바닥 y1355 → `(1355-204)/426 = 2.702H`. 최초 원화의 관찰 범위 약 **2.67~2.80H** 안이다.

| 지점 | y(px) | 정수리 기준 H |
|---|---:|---:|
| 정수리 | 204 | 0.00 |
| 턱 | 630 | 1.00 |
| 어깨(추정) | 668 | 1.09 |
| 허리(추정) | 834 | 1.48 |
| 가랑이(추정) | 1000 | 1.87 |
| 무릎(추정) | 1130 | 2.17 |
| 발바닥 | 1355 | **2.70** |

원화의 윤곽과 관절 위치는 수동 판독했으며, 머리 기울기·옷과 포즈에 따른 가림 때문에 정밀한 해부학 측정은 아니다. 첫 생성의 약 2.83H는 확정하지 않고 종아리를 줄여 보정했다. 이후 전체 그림을 균일 축소해 머리 위와 발 아래 여백을 확보했다.

- [최초 네 장과 같은 H로 정렬한 비교표](proportions/reference_comparison.png)
- [최종 경계 판독용 좌표선](landmark_audit.png)
- [좌표 입력](candidate_landmarks.json) · [측정 결과](proportions/landmarks.json)
- [사용자 외형과 제작 가이드를 분리한 생성 입력](construction_and_design.png)
- [생성·보정 프롬프트](PROMPT.md)

재검수(프로젝트 루트):

```powershell
./tools/analyze_character_proportions.ps1 -OutputDir 'docs/silver_twintail_pink_hoodie_v1/proportions' -CandidateJson 'docs/silver_twintail_pink_hoodie_v1/candidate_landmarks.json'
```
