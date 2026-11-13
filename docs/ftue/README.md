# FTUE 화면 캡처

`tools/test/FtueCapture.tscn` 이 실제 게임을 처음부터 따라가며 찍은 화면 (1280x720). 설계는 `docs/FTUE_분석_및_구조설계.md`.

| 파일 | 장면 |
|---|---|
| `01_title_boot` · `02_title` | 부팅 로그 → 타이틀 |
| `03_prologue_note` · `04_prologue_chief` · `05_prologue_*` | 첫 실행 프롤로그: 접수된 쪽지 → 반장 → 분대 한 마디씩 |
| `06_loading` | 로딩: 접속 문구 + 팁 |
| `07_room_place_card` | 첫 방 도착: 장소 카드 + 반장 말풍선 |
| `08_coach_place` · `09_coach_start` · `10_coach_ult` | 튜토리얼 코치 (배치 → 유물/시작 → 궁극기 카드 강조) |
| `11_boss_shout` | 보스 외침 (체력 구간) |
| `12_pause` | 일시정지 메뉴 (Esc) |
| `13_door_client` · `14_door_healer` | 의뢰 완료: 마지막 문 대화 (의뢰인은 신호 파형) |
| `15_memory_log_1~3` · `16_ending_line` | 엔딩 기억 로그 3장 → 반장 한마디 |
| `17_result_clear_counting` · `18_result_clear` | 결과 (완료): 기록 → 시간의 결정 → 엽서 → 허브 해금 알림 |
| `19_hub_after_clear` · `20_hub_*` · `21_hub_upgrade_bought` | 허브: 의뢰 · 분대 · 강화 · 엽서 벽 · 연구실 |
| `22_defeat_banner` · `23_result_retreat` | 전멸: "오늘 상담은 여기까지" → 결과 |
| `24_hub_first_visit` | 첫 방문 허브 (분대·강화·엽서 벽 잠김) |
