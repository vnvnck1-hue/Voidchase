## 연출 조절값의 색. 값 저장은 그대로 float 이라 색 하나를 PARAMS 에 "키_r / 키_g / 키_b" 세 줄로 넣는다
## (vd_card_flame_fx.gd 가 먼저 쓰던 방식). 연출 연구실은 이 세 줄을 컬러 피커 한 줄로 보여 준다 (vd_fx_lab.gd _add_color_row).
## class_name 없음: preload 해서 쓴다.
extends RefCounted

const CH := ["_r", "_g", "_b"]
const CH_NAMES := [" R", " G", " B"]


## [[키, 이름, Color(, 최대)], ...] → PARAMS 줄 (키_r/_g/_b, 0~최대(기본 1, HDR 색은 더 크게), 기본값 = 색 채널)
static func rows(group: String, list: Array) -> Array:
	var out := []
	for c in list:
		var col: Color = c[2]
		for i in 3:
			out.append([c[0] + CH[i], group, c[1] + CH_NAMES[i], 0.0, float(c[3]) if c.size() > 3 else 1.0, 0.01, col[i]])
	return out


## PARAMS 의 i 번째 줄이 색 세 줄의 첫 줄(_r)이면 그 색 키, 아니면 ""
static func base_at(params: Array, i: int) -> String:
	var key: String = params[i][0]
	if not key.ends_with("_r") or i + 2 >= params.size():
		return ""
	var base := key.left(key.length() - 2)
	if params[i + 1][0] == base + "_g" and params[i + 2][0] == base + "_b":
		return base
	return ""
