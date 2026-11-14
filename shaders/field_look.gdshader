// 필드 연구실 색 보정을 CanvasItem(보드 타일 · 프랍)에 입힌다. 그리는 내용(텍스처 × 정점 색)은 그대로 두고 결과 색만 보정한다.
shader_type canvas_item;
#include "res://shaders/field_look.gdshaderinc"

varying vec4 fl_vcol;

void vertex() {
	fl_vcol = COLOR;
}

void fragment() {
	COLOR = fl_apply(texture(TEXTURE, UV) * fl_vcol);
}
