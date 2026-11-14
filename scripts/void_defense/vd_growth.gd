## 영웅 성장 (TrioChess main.gd grant_exp/_level_up + stats.gd skill_fx 이식, 2026-11-08).
##   처치 경험치 → 레벨업(체력 +15 · 공격력 +8 · 회복 30 · SP +1) → 스킬창(VDSkillWindow)에서 스킬 4칸에 SP 를 써 레벨업 (최대 5).
##   스킬 효과(VDData.HERO_SKILLS fx × 레벨)는 apply() 가 VDUnit 의 보정치로 써 넣고, 고유 스킬·궁극기 수치는
##   skill_def()/ult_def() 가 VDData.SKILLS/ULTS 를 복사해 보정한 사전을 돌려준다 (VDSkills·VDUlts 가 쓴다).
## 레벨·경험치·SP 는 한 판(run) 안에서만 유지되고 다시 도전하면 1 레벨부터다 (TrioChess 런 내 레벨과 같다).
## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 preload 해서 쓴다.
extends RefCounted

signal leveled(unit: VDUnit, level: int)          # 레벨이 올랐다 (VDBattle 이 연출)
signal skill_upgraded(hid: String, slot: int, level: int)

var b: VDBattle
var data := {}          # hid -> {"level", "exp", "sp", "skills": [레벨 x SKILL_SLOTS]}
var count := {"exp": 0, "levels": 0, "upgrades": 0}   # 테스트용


func _init(battle: VDBattle) -> void:
	b = battle
	reset()


func reset() -> void:
	data.clear()
	for hid in VDData.HEROES:
		var lv: Array[int] = []
		lv.resize(VDData.SKILL_SLOTS)
		lv.fill(0)
		data[hid] = {"level": 1, "exp": 0, "sp": 0, "skills": lv}


func level_of(hid: String) -> int:
	return int(data[hid]["level"]) if data.has(hid) else 1


func exp_of(hid: String) -> int:
	return int(data[hid]["exp"]) if data.has(hid) else 0


func sp_of(hid: String) -> int:
	return int(data[hid]["sp"]) if data.has(hid) else 0


func need(hid: String) -> int:
	return VDData.exp_need(level_of(hid))


func skill_level(hid: String, slot: int) -> int:
	return int(data[hid]["skills"][slot]) if data.has(hid) else 0


func unit_of(hid: String) -> VDUnit:
	for a in b.allies:
		if a.id == hid:
			return a
	return null


## 처치 경험치: 처치한 영웅이 amount, 나머지 살아 있는 영웅은 EXP_SHARE 배. killer 가 영웅이 아니면(유물 처치) 전원 EXP_SHARE 배.
func grant_kill_exp(killer: VDUnit, amount: int) -> void:
	for a in b.allies:
		if not a.alive:
			continue
		var give := amount if a == killer else int(round(amount * VDData.EXP_SHARE))
		if give > 0:
			grant_exp(a, give)


## 경험치를 주고 오른 레벨 수를 돌려준다. 남는 경험치는 이월, 여러 레벨이 한 번에 오를 수 있다.
func grant_exp(u: VDUnit, amount: int) -> int:
	if not data.has(u.id):
		return 0
	var d: Dictionary = data[u.id]
	d["exp"] = int(d["exp"]) + amount
	count["exp"] += amount
	var gained := 0
	while int(d["exp"]) >= VDData.exp_need(int(d["level"])):
		d["exp"] = int(d["exp"]) - VDData.exp_need(int(d["level"]))
		_level_up(u, d)
		gained += 1
	return gained


func _level_up(u: VDUnit, d: Dictionary) -> void:
	d["level"] = int(d["level"]) + 1
	d["sp"] = int(d["sp"]) + VDData.SP_PER_LEVEL
	count["levels"] += 1
	u.level = int(d["level"])
	u.max_hp += VDData.LEVEL_HP
	u.atk += VDData.LEVEL_ATK
	if u.alive:
		u.heal(VDData.LEVEL_HEAL)
	else:
		u.hp = 0.0
	print("[VD] level up: %s -> Lv%d (hp %d atk %d, sp %d)" % [u.display_name, u.level, int(u.max_hp), int(u.atk), int(d["sp"])])
	leveled.emit(u, int(d["level"]))


func can_upgrade(hid: String, slot: int) -> bool:
	return data.has(hid) and sp_of(hid) > 0 and skill_level(hid, slot) < VDData.SKILL_MAX


## SP 하나로 slot 의 스킬을 한 레벨 올린다. 성공하면 true.
func upgrade(hid: String, slot: int) -> bool:
	if not can_upgrade(hid, slot):
		return false
	var d: Dictionary = data[hid]
	d["sp"] = int(d["sp"]) - 1
	d["skills"][slot] = int(d["skills"][slot]) + 1
	count["upgrades"] += 1
	var u := unit_of(hid)
	if u:
		apply(u)
	var sk: Dictionary = VDData.HERO_SKILLS[hid][slot]
	print("[VD] skill up: %s %s -> Lv%d" % [hid, sk["name"], int(d["skills"][slot])])
	skill_upgraded.emit(hid, slot, int(d["skills"][slot]))
	return true


## 스킬 효과 합: fx 키 → Σ(레벨당 수치 × 레벨).
func fx(hid: String) -> Dictionary:
	var out := {}
	if not data.has(hid) or not VDData.HERO_SKILLS.has(hid):
		return out
	var table: Array = VDData.HERO_SKILLS[hid]
	for i in table.size():
		var lv := skill_level(hid, i)
		if lv <= 0:
			continue
		for k in table[i]["fx"]:
			out[k] = float(out.get(k, 0.0)) + float(table[i]["fx"][k]) * lv
	return out


## 보정치를 유닛에 써 넣는다 (레벨·스킬이 바뀔 때, 새 판 시작 때).
func apply(u: VDUnit) -> void:
	var f := fx(u.id)
	u.level = level_of(u.id)
	var bonus := float(f.get("bonus_hp", 0.0))
	var delta := bonus - u.bonus_hp
	if delta != 0.0:
		u.max_hp = maxf(1.0, u.max_hp + delta)
		if u.alive:
			u.hp = clampf(u.hp + maxf(delta, 0.0), 1.0, u.max_hp)
		u.bonus_hp = bonus
	u.dmg_reduce = float(f.get("dmg_reduce", 0.0))
	u.dmg_bonus = float(f.get("dmg_bonus", 0.0))
	u.crit_bonus = float(f.get("crit", 0.0))
	u.atk_speed = float(f.get("atk_speed", 0.0))
	u.mana_mult = float(f.get("mana_mult", 0.0))
	u.heal_bonus = float(f.get("heal_bonus", 0.0))
	u.freeze_chance = float(f.get("freeze_chance", 0.0))
	u._redraw()


func apply_all() -> void:
	for a in b.allies:
		apply(a)


## 고유 스킬 수치 (VDData.SKILLS 복사본에 숙련 보정): 피해·회복 배율 × (1 + active_mult), 기절·빙결 +, 대상 수 +.
func skill_def(hid: String) -> Dictionary:
	var sk: Dictionary = VDData.SKILLS[hid].duplicate()
	var f := fx(hid)
	var am := 1.0 + float(f.get("active_mult", 0.0))
	for k in ["dmg", "impact_atk", "heal_hp", "heal_atk"]:
		if sk.has(k):
			sk[k] = float(sk[k]) * am
	if sk.has("stun"):
		sk["stun"] = float(sk["stun"]) + float(f.get("active_stun", 0.0))
	if sk.has("freeze"):
		sk["freeze"] = float(sk["freeze"]) + float(f.get("active_freeze", 0.0))
	if sk.has("targets"):
		sk["targets"] = int(sk["targets"]) + int(floor(float(f.get("active_count", 0.0)) + 0.0001))
	return sk


## 궁극기 수치 (VDData.ULTS 복사본에 숙련 보정): 피해·회복 × (1 + ult_dmg), 기절 +, 튕김 +, 부활 체력 +.
func ult_def(hid: String) -> Dictionary:
	var ud: Dictionary = VDData.ULTS[hid].duplicate()
	var f := fx(hid)
	var um := 1.0 + float(f.get("ult_dmg", 0.0))
	for k in ["dmg", "tick_dmg", "heal_hp"]:
		if ud.has(k):
			ud[k] = float(ud[k]) * um
	if ud.has("stun"):
		ud["stun"] = float(ud["stun"]) + float(f.get("ult_stun", 0.0))
	if ud.has("bounces"):
		ud["bounces"] = int(ud["bounces"]) + int(floor(float(f.get("ult_bounces", 0.0)) + 0.0001))
	if ud.has("revive_hp"):
		ud["revive_hp"] = minf(1.0, float(ud["revive_hp"]) + float(f.get("ult_revive", 0.0)))
	return ud
