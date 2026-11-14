# 생성 및 비례 보정 프롬프트

방식: 내장 image_gen. 최초 기준 원화 네 장을 모든 단계에서 실제 이미지 입력으로 제공했다. 처음에는 비례 가이드와 사용자 외형 참고를 결합한 입력을 함께 사용하고, 보정 단계에서는 직전 그림을 편집 대상으로 사용했다. 최종 결과는 `indigo_bob_fullbody_v1.png`.

프롬프트의 2048×3072는 요청 해상도이며 실제 도구 출력 해상도는 **968×1625**다. 출력 크기와 요청 크기를 혼동하지 않는다.

## 최초 생성

Use case: style-transfer / full-body completion. Redraw the cropped pixelated character in image 5 RIGHT into ONE polished HIGH RESOLUTION full-body character illustration for the same game as images 1-4. Target a crisp 2048 x 3072 portrait PNG, with genuinely redrawn smooth confident curves, NOT pixel enlargement or filtering.

INPUT ROLES:
Images 1-4 are the four authoritative roster drawings: match their EXACT proportions, graphic shape design, ink weight and flat cel rendering.
Image 5 LEFT is the measured construction guide. Image 5 RIGHT is the cropped character design to preserve and complete. The output is only the finished character. Never reproduce the diagram or its labels.

HARD PROPORTION CONSTRAINT:
H is the MAIN HEAD crown-to-chin vertical distance, excluding decorative projecting hair tufts. Crown-to-shoe-sole must measure 2.67-2.80H, TARGET 2.72H. This is NOT 3.5 or 4 heads tall. Body below chin is approximately 1.72H.
Follow construction sheet: crown=0H, chin=1H, shoulder=1.09H, waist=1.43H, crotch=1.85H, knees=2.26H, soles=2.72H. Main head width about1.30H, shoulder joints width0.86H, hips0.72H. On equivalent1100x1600 canvas: main crown y100, chin y600, shoulders y645, waist y815, crotch y1025, knees y1230, soles y1460. Scale entire figure uniformly for high resolution, never elongate body independently. The large main head and compact torso are mandatory. Do not shrink the head to accommodate the completed legs.

PRESERVE THIS SPECIFIC CHARACTER from image 5 RIGHT:
Angular dark indigo/violet bob, short sharply cut blunt bangs with a central small part, dramatic outward-flipped tuft on viewer-left, longer straight cheek-framing side locks near collar and pointed layered back hair. Broad flat muted-violet highlight shapes replacing the pixelated highlight blocks. Amber/golden oval eyes with strong upward-slanting black upper lids and a small lower lash accent; angled eyebrows, pink eye shadow, peach skin with pink/coral flat shadows and rosy cheek marks. A CONFIDENT MISCHIEVOUS CLOSED-MOUTH SMIRK, slightly asymmetric smiling cheek, looking toward viewer, not innocent open-mouth surprise. Small graphic nose or absent nose. Keep the angular expressive personality and cheek shape.
Lavender-purple zip-front roomy hoodie, large folded hood/raised collar, darker purple shadow planes, pale cream drawstrings, ribbed hem/cuffs and a visible small zipper pull at bottom. Cream crewneck rib-knit top inside, only a few fine rib lines. Source chest/torso simplified to the compact roster's broad shapes, not realistic volumes. One elbow angled outward and hand on hip at viewer-right, opposite arm relaxed beside body. Slight three-quarter standing angle and small hip shift, without excessive head tilt.

COMPLETE THE CROPPED LOWER BODY coherently:
Charcoal short pleated skirt emerging below hoodie, a few broad pleats. Warm peach simplified legs with clearly placed knees; dark plum knee-high socks, chunky dark low-top casual shoes with a simple pale lavender sole accent. Both legs and BOTH SHOES ENTIRELY VISIBLE, no frame cutoff. Keep outfit casual and consistent, no extra props, badges, jewelry, ribbons or ornaments. The leg lengths must fit the measured reference skeleton, not adult realistic anatomy.

DRAWING QUALITY / DENSITY:
The four original roster characters' bold BLACK silhouette outlines, sparse finer colored inner contours, strong rounded/angular shapes, broad flat color areas, one or two hard-edged cel shadow planes, restrained clean solid highlight shapes. Slightly enriched but controlled detail: deliberate hair clumps, a few sleeve folds/seams, visible zipper teeth/pull and hood thickness, cuff rib marks, skirt pleats, simple sock top and shoe panel/sole divisions. Preserve the source graphic ink attitude while refining all jagged edges into smooth intentional high-resolution curves. No pixel grid, jagged aliased edges, blur, low-res blocks, texture grain, painterly gradients, 3D light, glossy realistic skin/fabric or elaborate generic anime eyes.

ONE isolated full-body character centered on clean WHITE background, comfortable margin around flipped hair tuft and both soles. Character fills portrait composition while keeping all limbs visible. No scenery, cast shadow, labels, lettering, guide lines, measurements, frames, collage, watermark or additional characters.

## 머리/몸 비례 보정

Edit image 1 to correct its proportions ONLY. It is the new character, not a correct anatomy reference. Images 2-5 are our authoritative game roster. Keep the same recognizable angular indigo hair, amber eyes, sly closed smirk, lavender hoodie, cream rib-knit top, charcoal skirt, dark knee socks and chunky dark shoes. Keep smooth crisp ink and flat cel shadows.

CRITICAL: Image 1 is TOO TALL RELATIVE TO ITS HEAD. Its main crown is near y22, chin y470, soles y1520 on 1024x1536: H448 and total1498 =3.34H. This violates the roster. The corrected figure MUST have crown-to-sole height between 2.67 and2.80 head units, TARGET2.72.

Required geometric change: increase the MAIN SKULL AND FACE height by about23%, from448 to550, keeping crown near y22 and moving chin to y572. Scale main head uniformly, not only hair width. Compress/rebuild the small torso so shoulders near y620, waist near y810, crotch near y1040, knees near y1260, feet soles near y1520. At this scale the complete figure is1498/550=2.72H. The head must become significantly larger while torso gets shorter. Image 1 must NOT remain 3.3 heads tall. No hidden long neck. Under-chin body is only about1.72H, NOT over2H.

If the enlarged hair silhouette needs more room, make the canvas wider or scale the WHOLE finished figure uniformly to fit with generous white margin. Do not shrink the head independently to fit. No cropping hair or feet.
Preserve the defining graphic face: tilted angular upper lids and brows, amber eyes, peach/pink skin planes, blushed cheeks, confident asymmetric closed-mouth smile. Keep one hand on hip, the other relaxed by skirt. Compact cream sweater within hoodie; no elongated curvy torso, no detailed breasts. Keep knee positions clear, the simple leg shapes of images 2-5 and the exact same clothing details. This is not a realistic adult-proportion anime figure.

Clean high-resolution redraw with BLACK smooth contours, flat cel colors, selective controlled folds, no pixels or blur. Request a high-resolution 2048x3072 portrait if available, but correct proportions take precedence over canvas size.
One complete full-body character isolated on white, no text, guide lines, numbers, labels, collage, scenery, extra accessories or watermark.

## 다리 길이 보정

Make one very specific edit to image 1: LENGTHEN THE LEGS so its full-body proportions match the original roster images 2-5. Preserve the upper character.

DO NOT CHANGE THE HEAD OR FACE SIZE AT ALL. Preserve every defining angular hair shape, the amber eyes, the smirk, lavender hoodie, cream top, skirt, hands on hip, black contours and cel shading.

Image1 has main crown y30, chin y650, H620, soles y1500. That is only (1500-30)/620=2.37H, too short. Our roster requires 2.67-2.80H, target2.72H.
With head/torso unchanged, the soles need to move DOWN approximately220px to y1720 in the current image scale. Make the canvas TALLER to accommodate this. Add about100px of length between skirt and knee and120px between knee and ankle. In current-coordinate-equivalent terms, aim knees y1400 and soles y1720. This gives (1720-30)/(650-30)=2.73H. Do not change the skirt hem, head or torso size. Legs remain the same substantial width and simple cartoon anatomy. Move the shoes down and keep their size the same.
You can uniformly scale the entire completed drawing to fit a portrait output, but never shrink the head separately or compress the legs back to their old length. NO enlarged head. NO tiny short legs again. The entire composition should be taller than image1 because of the specified leg extension.
The original roster images2-5 demonstrate the required relationship, not an adult realistic figure.

Retain dark knee-high socks and chunky shoes with pale lavender sole, confident casual stance, one leg supporting weight, small bend at other knee. Give a clean visible knee accent at the correctly lowered joint. Keep all other clothing and the character's attitude unchanged.
Clean smooth high-resolution 2D cartoon ink, flat cel shadows, no pixelation or blurred enlargement. All hair and both soles visible with white margins. White background only, no labels, arrows, guide lines or typography.

## 최종 종아리 길이 보정

Make ONE SMALL GEOMETRIC EDIT to image1, preserving its entire design and drawing:
SHORTEN ONLY THE LOWER LEGS (below the kneecap) by approximately90 pixels at the current image scale. Keep head, face, hair, torso, hands, skirt, thighs and knee positions UNCHANGED. Keep shoes exactly the same size and move them UP90 pixels. Dark knee socks become correspondingly shorter. Do not change leg width.

Why: on image1 approximately968x1625, main crown y35, chin y575, H540, sole y1600 gives2.90H. The original roster images2-5 requires2.67-2.80H, target2.72. With the upper character and knees unchanged, moving shoe soles to y1510 gives(1510-35)/(575-35)=2.73H. THIS is the required correction. Adjust only the shins so soles move UP90px. Do not stretch the thighs, shrink the head, enlarge the shoes, move the knee or undo the change to fit the canvas.
Preserve all head contours and the exact mischievous smirk. Retain purple angular bob, amber eyes, lavender hoodie, cream rib-knit top, charcoal pleated skirt, dark knee socks and dark chunky shoes with lavender soles. One hand on hip, other relaxed.
Keep original full figure on white with all hair and shoes entirely visible, allowing a little extra white below the raised shoes or use a slightly shorter canvas. Preserve high-resolution smooth black outlines and flat cel shading. No pixel effects, blur, text, new accessories or guides.
