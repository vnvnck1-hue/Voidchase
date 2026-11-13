## 게임 진행 저장 (메타 고리): 첫 실행 여부 · 의뢰별 회기/클리어 · 시간의 결정 · 강화 · 엽서 · 본 안내.
## user://save.cfg 한 파일. 값이 바뀌면 바로 저장한다. (docs/FTUE_분석_및_구조설계.md 3.7)
## 테스트는 명령줄 `-- --save=<경로>` 또는 GameSave.use_path() 로 다른 파일을 쓴다 (실제 세이브를 건드리지 않게).
class_name GameSave
extends RefCounted

const DEFAULT_PATH := "user://save.cfg"

## 강화 (허브 [강화] 탭). cost[i] = i → i+1 단계 값(시간의 결정). 효과는 VDCaseRun.apply_upgrades 가 다이브 시작 때 적용.
const UPGRADES := {
	"vital": {"name": "든든한 야식", "desc": "분대 전원 최대 체력 +6%", "unit": "+%d%%", "per": 6, "cost": [3, 5, 8, 12, 16]},
	"rest": {"name": "쪽잠 캡슐", "desc": "방 클리어 회복량 +20%", "unit": "+%d%%", "per": 20, "cost": [3, 6, 10]},
	"pocket": {"name": "비상금 서랍", "desc": "다이브 시작 정수 +15", "unit": "+%d", "per": 15, "cost": [2, 5, 9]},
	"spark": {"name": "예열 헤드셋", "desc": "다이브 시작 궁극기 게이지 +20%", "unit": "+%d%%", "per": 20, "cost": [4, 7, 11]},
}
const UPGRADE_ORDER := ["vital", "rest", "pocket", "spark"]

static var _path := ""
static var _cfg: ConfigFile


static func use_path(p: String) -> void:
	_path = p
	_cfg = null


static func _ensure() -> void:
	if _cfg != null:
		return
	if _path == "":
		_path = DEFAULT_PATH
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--save="):
				_path = arg.substr(7)
	_cfg = ConfigFile.new()
	_cfg.load(_path)   # 없으면 빈 채로 시작


static func _val(section: String, key: String, default: Variant) -> Variant:
	_ensure()
	return _cfg.get_value(section, key, default)


static func _store(section: String, key: String, value: Variant) -> void:
	_ensure()
	_cfg.set_value(section, key, value)
	_cfg.save(_path)


## 세이브를 통째로 지운다 (허브 설정 [처음부터 다시]).
static func wipe() -> void:
	_ensure()
	_cfg = ConfigFile.new()
	_cfg.save(_path)


# ---------------------------------------------------------------- 첫 실행 · 허브 해금

## 프롤로그를 아직 안 봤다 = 완전 첫 실행.
static func is_first_run() -> bool:
	return not bool(_val("profile", "prologue_seen", false))


static func mark_prologue_seen() -> void:
	_store("profile", "prologue_seen", true)


## 허브 메뉴(분대·강화·엽서 벽)는 첫 의뢰를 한 번 다녀오면 열린다 (이기든 지든).
static func hub_unlocked() -> bool:
	return total_sessions() > 0


## 허브에서 아직 "NEW" 를 안 본 탭 id 들.
static func take_new_tabs() -> Array:
	var seen: Array = _val("profile", "tabs_seen", [])
	var fresh: Array = []
	if hub_unlocked():
		for id in ["squad", "upgrade", "postcards"]:
			if not seen.has(id):
				fresh.append(id)
	return fresh


static func mark_tab_seen(id: String) -> void:
	var seen: Array = _val("profile", "tabs_seen", [])
	if not seen.has(id):
		seen.append(id)
		_store("profile", "tabs_seen", seen)


# ---------------------------------------------------------------- 의뢰 기록

static func sessions(case_id: String) -> int:
	return int(_val("case_" + case_id, "sessions", 0))


static func total_sessions() -> int:
	return int(_val("profile", "sessions", 0))


static func is_cleared(case_id: String) -> bool:
	return int(_val("case_" + case_id, "clears", 0)) > 0


static func best_room(case_id: String) -> int:
	return int(_val("case_" + case_id, "best_room", 0))


## 마지막 다이브 결과: "" (없음) · "clear" · "retreat" (전멸·중단). 허브의 반장 대사가 이걸 본다.
static func last_result() -> String:
	return String(_val("profile", "last_result", ""))


## 다이브 한 번이 끝났다 (완료·전멸·중단 모두). rooms = 정리한 방 수. 받은 결정을 돌려준다.
static func record_session(case_id: String, cleared: bool, rooms: int, crystals_gain: int) -> void:
	var sec := "case_" + case_id
	_ensure()
	_cfg.set_value(sec, "sessions", sessions(case_id) + 1)
	_cfg.set_value(sec, "best_room", maxi(best_room(case_id), rooms))
	if cleared:
		_cfg.set_value(sec, "clears", int(_cfg.get_value(sec, "clears", 0)) + 1)
		var cards: Array = _cfg.get_value("profile", "postcards", [])
		if not cards.has(case_id):
			cards.append(case_id)
			_cfg.set_value("profile", "postcards", cards)
	_cfg.set_value("profile", "sessions", total_sessions() + 1)
	_cfg.set_value("profile", "last_result", "clear" if cleared else "retreat")
	_cfg.set_value("profile", "crystals", crystals() + crystals_gain)
	_cfg.save(_path)


static func postcards() -> Array:
	return _val("profile", "postcards", [])


## 무한 야근(끝없는 모드)은 의뢰를 하나라도 완료하면 열린다.
static func endless_unlocked() -> bool:
	return not postcards().is_empty()


# ---------------------------------------------------------------- 시간의 결정 · 강화

static func crystals() -> int:
	return int(_val("profile", "crystals", 0))


static func upgrade_level(id: String) -> int:
	return int(_val("upgrades", id, 0))


static func upgrade_max(id: String) -> int:
	return (UPGRADES[id]["cost"] as Array).size()


## 다음 단계 값. 다 올렸으면 -1.
static func upgrade_cost(id: String) -> int:
	var lv := upgrade_level(id)
	var costs: Array = UPGRADES[id]["cost"]
	return int(costs[lv]) if lv < costs.size() else -1


## 지금 효과의 합 (per × 단계).
static func upgrade_value(id: String) -> int:
	return int(UPGRADES[id]["per"]) * upgrade_level(id)


static func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or crystals() < cost:
		return false
	_ensure()
	_cfg.set_value("profile", "crystals", crystals() - cost)
	_cfg.set_value("upgrades", id, upgrade_level(id) + 1)
	_cfg.save(_path)
	return true


# ---------------------------------------------------------------- 튜토리얼 안내

static func hint_seen(id: String) -> bool:
	return (_val("profile", "hints", []) as Array).has(id)


static func mark_hint(id: String) -> void:
	var seen: Array = _val("profile", "hints", [])
	if not seen.has(id):
		seen.append(id)
		_store("profile", "hints", seen)


static func reset_hints() -> void:
	_store("profile", "hints", [])


static func hints_enabled() -> bool:
	return bool(_val("profile", "hints_on", true))


static func set_hints_enabled(on: bool) -> void:
	_store("profile", "hints_on", on)


## 의뢰 기록 없이 결정만 더한다 (무한 야근 정산).
static func add_crystals(n: int) -> void:
	_ensure()
	_cfg.set_value("profile", "crystals", crystals() + n)
	_cfg.set_value("profile", "last_result", "retreat")
	_cfg.save(_path)
