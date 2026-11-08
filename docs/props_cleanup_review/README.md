# 왼쪽 아치 가공 정리 — 승인용 샘플

- 원본: `assets/void_defense_original/background/props/arch_left.png` (230 × 287).
- 승인용 결과: `arch_left_cleaned.png`. 원본과 같은 크기, 원본 알파 유지.
- 전후 비교: `comparison.png` (왼쪽 원본, 오른쪽 정리).
- ImageGen 내장 도구로 원본 하단의 복원 줄무늬를 정리한 뒤, 손상된 하단 영역에만 결과를 합성했다. 원본 상단 198행과 원본 투명도는 픽셀 단위로 동일하다. 변경된 하단 픽셀은 7,797개.
- 게임 리소스 및 코드에는 적용하지 않았다. 이전에 시도한 전체 교체·추가 프랍용 코드 변경은 되돌렸다.
- `arch_left_imagegen.png`는 합성에 사용한 도구 출력이며 최종 검토 대상은 `arch_left_cleaned.png`이다.
- `prepare_review.ps1`은 원본을 읽어서 이 폴더 안에만 결과를 생성한다.

## ImageGen 프롬프트

Use case: precise-object-edit. EDIT TARGET: the attached original 230 x 287 pixel transparent purple ruined arch game sprite. This is an asset cleanup, NOT a redesign or quality upgrade. Preserve its exact outer silhouette, single narrow arch opening, lean, camera angle, layout, stone shapes, sparse cracks, original dark outline thickness, muted purple palette, brightness, saturation, simple low-detail painted/cel shaded style, and small olive moss patches. Preserve existing upper 70% as closely as possible. Change ONLY the rough processing damage in the bottom quarter: replace the conspicuous vertically striped/pixel-repeated purple fill on the lower base/right face with a clean coherent FLAT muted violet stone face, matching the adjacent existing stone plane. Clean abrupt rectangular patch seams in the lower block so the stone planes join naturally. Keep the original polygonal lower perimeter and internal structure. Do NOT add detail, texture, new cracks, decoration, new masonry blocks, new pedestal, plants or highlights. Do NOT increase contrast or saturation. Keep sparse simple broad color areas at the original level of detail. Keep same framing and transparent alpha including the arch opening; no background, no shadow, no glow, no text. Return just this same single sprite with its lower processing artifacts repaired.
