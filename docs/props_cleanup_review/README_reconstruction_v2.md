# 아치 가림 영역 복원 v2 — 승인용

PSD 분리 과정에서 다른 그림에 가려져 단색으로 임의 보충된 영역을, 기존 아치의 구조와 원근에 맞는 석재 그림으로 복원한다.

- arch_left_reconstructed_v2.png: ImageGen 내장 도구로 복원한 투명 PNG 원본.
- arch_left_reconstructed_v2_game_size.png: 기존 리소스와 같은 230 × 287 크기의 검토용 PNG.
- comparison_reconstruction_v2.png: 왼쪽 이전 시안, 오른쪽 구조 복원 시안.
- 복원: 양 기둥의 받침돌, 가운데 연결 석재, 전면 기단과 이음새, 원근에 맞는 윗면/전면/측면, 이끼가 얹힌 왼쪽 받침돌.
- 유지 기준: 기존 보라색/올리브색, 낮은 채도, 넓고 단순한 면 묘사, 기존 아치와 기둥 형태. 상단에는 생성 과정의 약간의 차이가 있다.
- 배경과 아치 내부 알파 투명도를 확인했다.
- 게임 파일/배치/빌드에는 미적용. 다른 프랍으로 확대하기 전에 사용자 검토를 받는다.

## 사용 프롬프트 (ImageGen 내장 도구)

Use case: precise-object-edit, reconstruction of previously occluded artwork.
EDIT TARGET: the provided purple stone arch sprite. This is a local restoration of MISSING ARCHITECTURAL DRAWING, not silhouette cleanup, not a new design, not a detail/quality upgrade.

The entire lower 40 percent is unfinished: a vague, solid purple blob replaces masonry that was hidden behind foreground art in the source PSD. PAINT ACTUAL COHERENT STONE STRUCTURE in those blank areas. Merely smoothing or recoloring them is a failure.

KEEP the upper arch and both column shafts, their positions and lean, the arched opening, original muted purple/lavender palette, brightness and low saturation, sparse olive moss, broad simple cel shading, dark purple outlines and original low drawing density. Keep upper 60 percent as unchanged as possible.

RECONSTRUCT the bottom in the same existing 3/4 isometric perspective:
1. Continue BOTH existing upright column shafts down into believable squared stone FOOTINGS with a short simple stepped/beveled top lip. Draw clear top/front/side planes. The left moss-covered fragment must become the chipped corner of the LEFT squared footing, with moss resting on its top, not an arbitrary triangular color blob.
2. Restore a LOW STONE SILL / foundation across the empty purple panel between the pillars, directly below the arch opening. Draw its upper surface and front face with perspective-aligned edges that visibly connect the pillars. The arch opening itself stays transparent. The formerly blank interior panel should read as structural stone, not featureless fill.
3. Replace the broad shapeless purple FRONT AND RIGHT BASE with a coherent plinth made of TWO OR THREE LARGE PURPLE STONE BLOCKS. Draw only a few large masonry seams, one modest chipped corner and one sparse structural crack that continue the visual language of the upper arch. Define where the front face meets the right return face with a clean perspective corner. Complete the right pillar's footing and its connection to this plinth.
4. Make each edge, seam and shadow explain the construction and support the column above it. Existing blobs are missing art to be replaced, not shapes to preserve blindly. The lower silhouette may be locally squared/chipped just enough for believable stone.

VERY IMPORTANT: maintain exactly the same simple mobile-game art density. Broad quiet surfaces, no ornament, no symbols, no fine texture, no repeated brick grid, no rubble pile, no extra plants, no extra decoration, no new saturated accents. Do not make it a fancy new arch. This remains the same worn muted-purple arch, now with the obscured stonework actually completed. Same framing and camera. Single whole isolated sprite on actual transparent alpha, including arch opening. No ground/background, no drop shadow, no glow, no red marks or labels.

