# void_defense VFX 출처 (2026-11-04)

플립북 시트는 `scripts/void_defense/vd_vfx.gd` 의 `LIB` 표(열·행·프레임·fps·블렌드)로 재생한다.

| 파일 | 원본 | 용도 |
|---|---|---|
| td_hit_spark_light.png (8x2, 12f, 64px) | 타워대시 textures/vfx/pxf/hit_spark_light | 건너 총구 섬광, 적→아군 피격 |
| td_hit_spark_heavy.png (8x2, 16f, 96px) | 타워대시 hit_spark_heavy | 기사 명중 |
| td_slash_steel_swing.png (8x2, 16f, 64px, add) | 타워대시 slash_steel_swing | 기사 베기 궤적 |
| td_parry_spark.png (8x2, 14f, 64px) | 타워대시 parry_spark | (예비) 방어 섬광 |
| td_multikill_burst.png (8x3, 20f, 128px) | 타워대시 multikill_burst | 적 처치 폭발, 보스 처치 |
| td_slam_impact.png (8x3, 18f, 128px) | 타워대시 slam_impact | 보스 등장 지면 충격 |
| td_land_dust.png (8x2, 14f, 64px) | 타워대시 land_dust | 이동 한 걸음 먼지, 배치 |
| td_dash_burst.png (8x2, 12f, 64px) | 타워대시 dash_burst | 복도 이동 출발 |
| hx_hit_spark_sheet.png (3x1, 3f, 256px) | 헥스 블레이드 assets/fx/hit_spark_sheet | 건너 명중 |
| vr_impact_burst.png (4x4, 16f, 512px, add) | VFX연구 vfx_textures/impact_burst | 마법사 명중 폭발 |
| vr_heal_sparkles.png (4x4, 16f, 512px, add) | VFX연구 heal_sparkles | 힐러 회복, 웨이브 회복 |
| vr_energy_orb.png (4x4, 16f, 512px, add, loop) | VFX연구 energy_orb | 마법사 투사체 |
| vr_shockwave.png (4x4, 16f, 512px, add) | VFX연구 shockwave | 보스 등장·처치, 구역 클리어 |
| vr_portal_swirl.png (4x4, 16f, 512px, add, loop) | VFX연구 portal_swirl | 적 등장 균열 |
| vr_lightning_bolt.png (4x4, 16f, 512px, add) | VFX연구 lightning_bolt | 영웅 전투불능 |
| vr_magic_circle.png (1장, 1024px, add) | VFX연구 magic_circle | 힐러 시전 마법진 |

기사 검기는 플립북이 아니라 셰이더다: `scripts/void_defense/vd_sword_slash.gd` + `shaders/sword_slash_cel.gdshader` (VFX연구 vfx/sword_slash 의 CEL 셀 초승달, 2026-11-06).
