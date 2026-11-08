# v2: 눈 제거 · 투명 배경

결과: food_monsters_lineup_v2_noeyes_transparent.png

방식: 내장 image_gen, transparent_background=true. 기존 v1을 편집 대상으로 사용. 실제 PNG 알파 채널과 배경·캐릭터 사이 여백의 알파 0을 확인했다.

기존 6종의 배치·색상·포즈를 유지하고 모든 눈을 음식 표면으로 복원했다. 번호와 접지 그림자를 제거했다. 기존 DESIGN.md의 외눈 관련 설명은 v1에만 해당하며, v2가 최신 수정 시안이다.

## Final prompt

Use case: precise-object-edit + background-extraction.
Edit the provided six-monster food character concept sheet. The user requests exactly two changes: REMOVE EVERY EYE and make the background completely transparent.
1. Remove all six red eyes, pupils, eye highlights, eyelid outlines and any eye sockets/eye-shaped recesses, including the strawberry's eye. Seamlessly reconstruct natural food surface or filling underneath: smooth dark-purple jam between pancakes, ordinary red strawberry flesh, uninterrupted chocolate cake surface, smooth plain blue bottle label, plain ivory mug ceramic, and uninterrupted red/ivory carton print. No eye-like shapes or replacement eyes anywhere. Do not replace eyes with holes, black sockets, symbols, gems or spots. All six characters must be completely eyeless. Preserve the cake mimic's large mouth, biscuit teeth and purple tongue, and preserve the mug's small smile.
2. Remove the pale lavender background, all ground/contact shadows and all six numeric labels, leaving ONLY the six character cutouts on a genuinely fully transparent alpha background. Gaps between arms, mug handle and objects must also be transparent. All character bodies remain fully opaque. No checkerboard pattern painted into image, no white background, no colored backdrop, no floor, no residual shadow haze.
Invariants: Keep the same six original characters, their exact 3-column by 2-row arrangement and relative scale, original poses, silhouettes, food materials and colors, thick dark outer contour and cel shading. Preserve pancake and waffle shield, strawberry cake jaws, chocolate fists, bottle and small bomb, foam hat and spoon wand, milk carton and straw. Do not redesign, add characters or change framing. Clean game-ready character silhouettes and anti-aliased edges. No text, labels, watermark or floating decoration.

