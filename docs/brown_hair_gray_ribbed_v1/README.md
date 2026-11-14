# 갈색 긴 머리 · 회색 골지 캐릭터

- 제작일: 2026-11-10
- 사용자 요청: 첨부 원화의 외형 디자인으로 우리 게임 캐릭터 그리기. 이전에 승인한 비례/그림체와 한 장의 최종본 전달 방식을 유지.
- 최종 원화 한 장: [`brown_hair_gray_ribbed_final.png`](brown_hair_gray_ribbed_final.png), **1038×1515 PNG**, 흰 배경. 런타임 미연결.
- 방식: 내장 image_gen으로 처음부터 생성. 완성 이미지의 축방향 변형이나 비균일 리사이즈를 하지 않음.
- 사용자 외형 원본: [`design_reference.png`](design_reference.png), 수정 없이 보관.

## 외형 해석

원본의 정면은 긴 머리, 뒤쪽 시안은 단발로 길이가 다르다. 이번에는 **정면 시안의 긴 갈색 생머리와 일자 앞머리**를 선택했다. 반쯤 감긴 갈색 눈, 작은 무심한 입, 따뜻한 피부와 볼의 붉은 색면, 큰 은색 링 귀걸이를 적용했다.

회색 골지 하이넥 크롭 볼레로와 긴 소매, 가로 트임, 같은 색 이너탑과 하이웨이스트 레오타드형 하의를 간결한 색면으로 재구성했다. 골지선은 큰 의상 면에만 선택적으로 배치했다. 원본에서 보이지 않던 발은 짙은 회색의 단순한 앵클부츠로 완성했다. 포즈는 한 손을 허리 옆에 두고 반대 손은 자연스럽게 내려오는 전신 스탠딩이다.

사실적인 인체/재질/광택 대신 최초 원화 네 장의 큰 머리와 작은 몸통, 단순한 팔다리, 굵은 검정 윤곽선과 셀 명암을 사용했다. 원본의 두 인물을 같이 그리지 않고 한 캐릭터만 제작했다.

## 수동 비례 검수

기준: `../character_style_reference/proportions/README.md`. 주 머리 정수리~턱 외곽의 수직 높이를 H로 한다. 긴 뒤머리 길이는 머리 높이에 포함하지 않는다.

| 지점 | y(px) | 정수리 기준 H |
|---|---:|---:|
| 정수리 | 25 | 0.00 |
| 턱 외곽 | 560 | 1.00 |
| 어깨(추정) | 610 | 1.09 |
| 허리(추정) | 800 | 1.45 |
| 가랑이 | 1004 | 1.83 |
| 무릎(추정) | 1190 | 2.18 |
| 발바닥 | 1508 | **2.77** |

H535px, `(1508-25)/535 = 2.772H`로 최초 원화의 관찰 범위 약2.67~2.80H 안이다. 턱 외곽은 확대 판독으로 확인했다. 좌표는 수동 판독이며 가려진 관절과 포즈에 따른 오차가 있다. 수치만으로 같은 형태임을 보장하지 않고, 눈/턱의 형태와 목~어깨~골반~사지의 연결, 손과 신발 방향도 함께 시각 확인했다.

- [최초 네 장과 동일 H 비교](proportions/reference_comparison.png)
- [최종 좌표선](landmark_audit.png) · [턱 외곽 판독](chin_audit.png)
- [측정 좌표](candidate_landmarks.json) · [계산 결과](proportions/landmarks.json)
- [초기 인체 가이드와 외형 참고](construction_and_design.png)
- [실제 생성 프롬프트](PROMPT.md)

재검수:

```powershell
./tools/analyze_character_proportions.ps1 -OutputDir 'docs/brown_hair_gray_ribbed_v1/proportions' -CandidateJson 'docs/brown_hair_gray_ribbed_v1/candidate_landmarks.json'
```
