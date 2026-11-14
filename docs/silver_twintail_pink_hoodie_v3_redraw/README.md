# 은회색 양갈래 v3 — 새 드로잉

- 제작일: 2026-11-10
- 사용자 피드백: v2가 위아래로 눌린 것처럼 보임.
- 최종 선택: [`silver_twintail_pink_hoodie_v3.png`](silver_twintail_pink_hoodie_v3.png), 1052×1495 PNG, 흰 배경. 내장 image_gen으로 처음부터 새로 생성한 그림. 런타임 미연결.
- 입력: 최초 원화 네 장과, 비례 가이드/외형 원화를 분리해 배치한 `../silver_twintail_pink_hoodie_v1/construction_and_design.png`. v1/v2 또는 다른 생성본을 편집 입력으로 사용하지 않음.

## 형태 재구성

기존 결과의 가로/세로 크기를 백분율로 바꾸는 지시를 중단했다. 원본 스타일에 따라 인체를 새로 구성하고, 손을 허리에 둔 포즈, 새 소매 접힘과 치마의 겹침, 좌우가 다른 머리카락 흐름, 서로 다른 방향의 신발 원근을 다시 그렸다. 후보 중 인체 연결과 전체 비례를 비교해 이 그림을 선택했다.

은회색 양갈래, 반쯤 감긴 연두색 눈, 분홍 어깨 트임 후드, 흰 플리츠 치마바지, 분홍 양말과 흰/분홍 신발이라는 외형 디자인은 유지했다. 머리끈·주름·양말 장식 등 세부 묘사는 새 그림에 맞게 해석되었다.

## 검수

주 머리 정수리 y12, 턱 외곽선 y540 → H528px. 발바닥 y1484 → `(1484-12)/528 = 2.788H`. 최초 원화의 관찰 범위 약2.67~2.80H 안이다. 어깨·허리·가랑이·무릎은 각각 약1.09H·1.41H·1.89H·2.23H로 수동 표시했다. 경계선 두께와 가려진 관절 때문에 근삿값이다.

이 수치만으로 전체 형태가 최초 원화와 완전히 같다고 판정하지 않는다. 얼굴의 턱 면과 눈의 타원, 목~어깨 연결, 팔꿈치~손, 체중을 받치는 골반과 다리, 의상 주름의 방향과 신발 원근을 최초 네 장과 함께 시각 확인했다.

이전 가로 폭 보정의 문제: 머리카락 외곽 단면의 폭을 얼굴·두개부 폭으로 취급하면, 헤어스타일 차이를 인체 변형으로 고치게 된다. 이 시안의 머리카락 외곽은 별도 헤어 디자인이며 v2의 단면 폭 수치에 맞추기 위해 납작하게 만들지 않았다. 가로 폭 표본을 해부학적 규격이나 자연스러움의 보증으로 사용하지 않는다.

- [최초 네 장과 같은 H로 비교](proportions/reference_comparison.png)
- [수동 측정 좌표](candidate_landmarks.json) · [결과 JSON](proportions/landmarks.json)
- [턱 경계 판독](chin_audit.png)
- [선택된 그림의 실제 생성 프롬프트](PROMPT.md)

재검수:

```powershell
./tools/analyze_character_proportions.ps1 -OutputDir 'docs/silver_twintail_pink_hoodie_v3_redraw/proportions' -CandidateJson 'docs/silver_twintail_pink_hoodie_v3_redraw/candidate_landmarks.json'
```
