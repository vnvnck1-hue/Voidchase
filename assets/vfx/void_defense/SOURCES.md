# void_defense VFX 출처 (2026-11-04)

플립북 시트는 `scripts/void_defense/vd_vfx.gd` 의 `LIB` 표(열·행·프레임·fps·블렌드)로 재생한다.

| 파일 | 원본 | 용도 |
|---|---|---|
| td_hit_spark_light.png (8x2, 12f, 64px) | 타워대시 textures/vfx/pxf/hit_spark_light | 건너 총구 섬광, 적→아군 피격 |
| td_slash_steel_swing.png (8x2, 16f, 64px, add) | 타워대시 slash_steel_swing | 기사 베기 궤적 |
| td_parry_spark.png (8x2, 14f, 64px) | 타워대시 parry_spark | (예비) 방어 섬광 |
| td_multikill_burst.png (8x3, 20f, 128px) | 타워대시 multikill_burst | 적 처치 폭발, 보스 처치 |
| td_slam_impact.png (8x3, 18f, 128px) | 타워대시 slam_impact | 보스 등장 지면 충격 |
| td_land_dust.png (8x2, 14f, 64px) | 타워대시 land_dust | 이동 한 걸음 먼지, 배치 |
| td_dash_burst.png (8x2, 12f, 64px) | 타워대시 dash_burst | 복도 이동 출발 |
| hx_hit_spark_sheet.png (3x1, 3f, 256px) | 헥스 블레이드 assets/fx/hit_spark_sheet | 건너 명중 |
| vr_impact_burst.png (4x4, 16f, 512px, add) | VFX연구 vfx_textures/impact_burst | 마법사 명중 폭발 |
| vr_heal_sparkles.png (4x4, 16f, 512px, add) | **사이파이 재작성** (나노 스캔: 스캔 띠 + 육각 셀 + 사각 입자) | 힐러 회복, 웨이브 회복, 별 깃털 착탄 |
| vr_energy_orb.png (4x4, 16f, 512px, add, loop) | **사이파이 재작성** (플라즈마 탄: 흰 코어 + 아크) | 마법사·포자·보스 투사체, 망루 충전 |
| vr_shockwave.png (4x4, 16f, 512px, add) | VFX연구 shockwave | 보스 등장·처치, 구역 클리어 |
| vr_portal_swirl.png (4x4, 16f, 512px, add, loop) | **사이파이 재작성** (텔레포트 패드: 점선 링 + 육각 + 펄스) | 적 등장 예고, 보스 공허 강하 |
| vr_lightning_bolt.png (4x4, 16f, 512px, add) | **사이파이 재작성** (궤도 빔: 위에서 꽂히는 빔 + 착탄 링) | 절대 영도·체인 마무리·부활·레벨업·전투불능·강적 착지·뇌운 조각 착탄 |
| vr_magic_circle.png (1장, 1024px, add) | **사이파이 재작성** (홀로그램 표지 링: 동심원 + 눈금 + 호 + 육각 격자) | 힐러 회복·스킬·궁극기, 절대 영도, 강적 예고 |

기사 검기는 플립북이 아니라 셰이더다: `scripts/void_defense/vd_sword_slash.gd` + `shaders/sword_slash_cel.gdshader` (VFX연구 vfx/sword_slash 의 CEL 셀 초승달, 2026-11-06).

2026-11-09 사이파이 리스타일: 위에서 **사이파이 재작성** 표시한 다섯 장은 `tools/vfx/build_scifi_sheets.py` 가 같은 격자·프레임 수로 다시 그린다 (흰색으로 그려 tint 로 물들임). 판타지 원본(VFX연구)은 `assets/_backup/vfx_fantasy/` 에 있다.
