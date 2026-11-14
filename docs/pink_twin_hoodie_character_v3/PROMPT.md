# 분홍 양갈래 후드 캐릭터 v3 — 최초 원화 비례 적용

- 제작일: 2026-11-10
- 방식: 내장 image_gen 도구. 이미지 편집으로 머리/몸 관계와 다리 길이를 단계적으로 보정.
- 결과: `pink_twin_hoodie_character_v3.png` (검토용 원화, 런타임 미연결)
- 기준: `../character_style_reference/proportions/README.md`
- 같은 수동 측정에서 정수리 y120, 턱 y655, 발바닥 y1552, H535 → 전신 2.677H. 최초 원화의 관찰 범위 2.675~2.797H 안에 들어옴. 소수점은 계산값이며 경계 판독의 오차가 있음.
- 첫 생성은 전신이 길어 재조정했고, 두 번째는 다리가 짧아 최종 편집에서 다리 길이를 보강. 생성 과정 중 결과는 확정본으로 사용하지 않음.
- 가려지거나 단순화된 관절의 수치는 추정이며 픽셀 단위의 동일 비례를 보증하지 않음. 자세한 검수와 비교 도표는 기준 문서에 기록.

## 최초 생성 프롬프트

Use case: stylized-concept. Create ONE finished full-body 2D game character. STRICT ROSTER PROPORTION MATCH REQUIRED.

Images 1,2,3,4 are our four original roster characters. They are authoritative for form, facial construction, linework, proportions and flat cel shading.
Image 5 is a construction sheet: LEFT is a precisely spaced proportion guide derived from images 1-4; RIGHT is the new character's APPEARANCE ONLY. Output only a finished character, do NOT reproduce the sheet, text, guide lines or source realistic anatomy.
No prior generated pink character is a reference. Rebuild from the originals.

MEASURED PROPORTIONS -- follow these instead of generic "chibi" assumptions:
H = vertical distance from top of the MAIN HEAD MASS to the chin, excluding separate ponytails, headbands, ahoge and hats. The original four crown-to-sole heights measure 2.80H, 2.67H, 2.69H, 2.73H. Target 2.72H, stay within 2.67-2.80H.
Use image 5 LEFT as the skeleton BEFORE drawing costume. Main head crown = 0H, chin = 1H, shoulders = 1.09H, waist = 1.43H, crotch = 1.85H, knees = 2.26H, soles = 2.72H. These are vertical positions from main head crown. Maintain their spacing. Main head width about 1.30H before side ponytails, shoulder joint width about 0.86H, hips about 0.72H; add sleeve volume naturally. Body below chin is only about 1.72 head units. Do NOT elongate torso or legs. In a conceptual 1100x1600 canvas: crown y100, chin y600, shoulders y645, waist y815, crotch y1025, knees y1230, soles y1460. Main head ellipse x225..875. You may scale the whole figure uniformly to fit output, but keep landmark proportions.

DESIGN from right side of image 5:
Dusty pink bob-length hair, two short high twin ponytails with paired white ball ties, chunky bangs and small ahoge. Violet eyes, pink cheeks and tiny playful puckered mouth. Closed pale lavender pullover hoodie with loose sleeves, dark lavender cel shadows, pale drawstrings, rib cuffs, centered small pink heart-face patch with white scallop outline. Lavender shorts, elastic gathered waist, tied white waist cord, simple curved pocket openings and broad turned-up cuffs. White ankle socks, chunky lavender/white sneakers with small pink outsole accents. Take only outfit/hair design from the realistic appearance picture.
Simple cartoon hands with angular thumbs/fingers in the same language as originals, not tiny mitten dots. Straightforward standing three-quarter pose with a slight hip shift, arms relaxed at sides. Avoid a strongly tilted head or deep knee bend so vertical proportions remain readable.

EXACT ART FAMILY: match the first four ink drawings, with the same compact upper body and large expressive head, bold BLACK varied-width contour, broad graphic hair locks, thick top eyelid, simple oval iris with two flat purple bands and a tiny white shine, no realistic nose/lips. Large simple costume shapes with selective details at overlaps. Slightly enriched but controlled density: a few hair contours, hoodie sleeve folds/cuffs/seams, shorts pocket seams and sneaker panels/laces. Broad flat colors and 1-2 hard edged cel shadows. Avoid smooth gradients, 3D lighting, realistic breasts or knees, glossy skin, elaborate anime eyes and fine strand rendering.
No giant realistic chest; hoodie torso follows the reference skeleton as one simple short shape. Do not make a long 3.5-4H character. Do not enlarge ponytails so much they obscure the main skull silhouette.

Plain white background, one isolated FULL FIGURE with both feet and all hair visible and clean margins. No floating hearts, props, floor scene, numbers, lettering, diagram, measurement lines, collage, watermark or additional character. Draw the actual polished character over the construction concept and remove all construction marks.

## 머리/몸 비례 보정 프롬프트

Edit image 1 with ONE PRIORITY: correct its measurable head/body ratio. Preserve character design, costume, pose, colors, linework and detail level.

Image 1 is the edit target, NOT a correct proportion reference. Its main skull crown is near y90 and chin near y540, feet near y1500 on a roughly 1040x1514 image: (1500-90)/(540-90)=3.13H. THIS FAILS.
Images 2-5 are the original roster and measure 2.67-2.80H from main head crown to shoe sole. Match them.

REQUIRED CORRECTION:
Increase the MAIN HEAD (skull and face, not ponytails) by approximately 16 percent uniformly while keeping crown near its current height. Compress the entire under-chin body vertically so feet stay near current baseline. At equivalent 1040x1514 canvas, main skull crown near y90, chin near y610, shoulders near y655, waist near y835, crotch near y1050, knee near y1260 and soles near y1500. This makes H=520 and crown-to-sole=1410: 2.71H. The head itself must become visibly larger/taller; merely spreading hair or ponytails does not count. Main head width around 675, while ponytail extent must remain inside the canvas.
Rebuild the torso/legs in those spaces, matching the compact roster shapes. The required H=520 is measured from main central scalp top to jaw bottom, excluding ahoge/ponytails. BODY BELOW CHIN only 890 px in this coordinate equivalent. Do not output the original 3.13H proportions again. Keep the same total standing composition.

Keep the pink bob-length twin tails, white ball ties, purple eyes, tiny cartoon mouth, lavender CLOSED hoodie with scalloped heart-face patch, lavender cuffed shorts and bow drawstring, white socks and lavender sneakers. Hoodie hem meets waistband, no exposed midriff. Keep clean flat cel shading, bold black contours, simple angular graphic limbs from images 2-5. Character fully visible on white. No diagram, text, guides, collage, shadows on ground or extra objects.

## 최종 다리 길이 보정 프롬프트

Make a PRECISE MINOR PROPORTION CORRECTION to image 1. Do not redesign or restyle it.

Images 2-5 are the original game roster. Their measured crown-to-sole height is 2.67-2.80 times main-head-crown-to-chin height. Target 2.72.

Image 1 now has a correctly large head and compact torso, but its LEGS ARE A LITTLE TOO SHORT. In the current approximately 1040x1514 image, main central skull crown is around y115, chin around y655, H about540; shoe sole around y1500. This yields only 2.57H crown-to-sole.

Keep the entire head, face, hair, torso, sleeves, hands, shorts and their scale UNCHANGED. Extend only the legs a modest amount so the sole moves approximately 75-80 pixels lower relative to the current fixed head. At the current equivalent scale soles should be around y1580, then (1580-115)/(655-115)=2.71H. Use a taller canvas or uniformly fit the entire finished figure into a portrait canvas WITH ALL PROPORTIONS PRESERVED. Do not shrink or enlarge just the head to fit. Add approximately 40px length to each thigh and 40px to each lower leg, keep leg width and simple stylized knee construction. Both shoes should retain size and detailing. This is a small leg extension, NOT a tall anime transformation.

Maintain the same thick black contour, flat cel colors, pink twin tails with white ball ties, purple eyes, small mouth, lavender heart-patch pullover and cuffed shorts with white waist bow, white socks and lavender/pink chunky sneakers. Hoodie hem should touch the shorts waistband with no exposed skin. Do not add any accessories. White isolated background and clean margins, full figure and both shoe soles visible. No text, guide lines, diagrams or measurements in final.
Do not output the same short legs again. Preserve the entire upper character while adding the specified modest leg length so measured full height is 2.72 head units.
