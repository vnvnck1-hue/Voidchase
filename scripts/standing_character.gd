## Shows the selected character on the stage. Characters with only a still image get a procedural
## idle (breathing squash/stretch + a slow sway pivoting at the feet, same period as the rigged idle);
## characters with an idle sprite sheet play it instead; the rigged character (Olivia) is shown by
## un-hiding her rig. Feet sit at this node's origin; the node's position is driven by the "entrance"
## animation exactly like the rig was.
##
## Every character also gets a drop shadow: a flat black silhouette of the character offset on the
## floor. Still / sheet characters: a second Sprite2D (same texture and frame, black modulate) drawn
## under the character. The rig: a script-less copy of the rig whose bones and parts follow the
## original every frame, composited through a CanvasGroup so overlapping body parts stay one flat
## shade instead of stacking alpha.
class_name StandingCharacter
extends Node2D

## Standing texture per character-select panel index (null = no still image).
@export var textures: Array[Texture2D] = []
## The rigged Olivia avatar node (lives in BG_all) and the panel index that shows it (-1: none).
@export var rigged_avatar: NodePath
@export var rigged_index := -1
## Rig node per panel index (empty path = none): an instanced rig scene under this node with its
## feet at its origin and its own AnimationPlayer idle (e.g. scenes/characters/maid_rig.tscn).
## Written by tools/expand/apply_standing.py (RIGS). Takes the place of the still image / sheet.
@export var rigs: Array[NodePath] = []
## Name image shown only for the rigged character (no name assets exist for the others yet).
@export var name_sprite: NodePath
## Source pixels -> world pixels (the standing art is drawn at ~1800 px tall).
@export var pixel_scale := 0.32
## Per-panel override of pixel_scale (0 or missing = use pixel_scale); for art at another resolution.
@export var texture_scales: Array[float] = []
## Optional idle sprite sheet per panel (null = still image from `textures`); built by
## tools/expand/make_idle_sheet.py. A sheet replaces the procedural idle: the frames are the idle.
@export var sheets: Array[Texture2D] = []
@export var sheet_grids: Array[Vector2i] = []   # (hframes, vframes)
@export var sheet_counts: Array[int] = []       # frames actually used (the grid may have empty cells)
@export var sheet_fps: Array[float] = []
## Idle motion, matched to the rigged idle clip (2.53 s loop).
@export var idle_period := 2.5333
@export var breath_scale := 0.014       # vertical stretch amplitude
@export var sway_degrees := 0.9         # lean amplitude, pivot at the feet
@export var sway_shift := 2.0           # horizontal drift amplitude (px)
@export_group("Drop shadow")
@export var shadow_enabled := true
## Flat black at 40 %: the silhouette keeps the art's own edge alpha, multiplied by this.
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.4)
## Where the silhouette's feet sit relative to the character's feet (world px, +x = right).
@export var shadow_offset := Vector2(56.0, 0.0)
## Lean of the silhouette around the feet (radians, + = top leans right); 0 = plain offset copy.
@export var shadow_skew := 0.0

var current := -1
var _t := 0.0
var _drop: Sprite2D            # silhouette for still / sheet characters
var _rig_shadows := {}         # rig Node2D -> CanvasGroup silhouette (built on first use)
var _rig_pairs := {}           # rig Node2D -> [[original CanvasItem, copy CanvasItem], ...]
var _rig: Node2D               # rig currently shown (null: still image / sheet / none)


func _ready() -> void:
	# run after the rig's AnimationPlayer and IK manager (priority 100): the shadow copies final poses
	process_priority = 200
	var sprite := get_node("Sprite") as Sprite2D
	_drop = Sprite2D.new()
	_drop.name = "DropShadow"
	_drop.centered = false
	_drop.modulate = shadow_color
	_drop.visible = false
	add_child(_drop)
	move_child(_drop, sprite.get_index())  # under the character, over the floor ellipse


func show_character(index: int) -> void:
	var sprite := get_node("Sprite") as Sprite2D
	var avatar := get_node_or_null(rigged_avatar) as Node2D
	var name_img := get_node_or_null(name_sprite) as CanvasItem
	var rig := _rig_for(index)
	var rigged := rig != null
	current = index
	_rig = rig
	for r in _all_rigs():
		var on: bool = r == rig
		r.visible = on
		r.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if name_img != null:
		name_img.visible = rig != null and rig == avatar  # only Olivia has a name image
	if rigged and shadow_enabled and not _rig_shadows.has(rig):
		_build_rig_shadow(rig)
	for r in _rig_shadows:
		var grp: CanvasGroup = _rig_shadows[r]
		grp.visible = r == rig and shadow_enabled
		if grp.visible:
			_sync_rig_shadow(r)
	var tex: Texture2D = null
	var sheet: Texture2D = _sheet_for(index) if not rigged else null
	if sheet != null:
		tex = sheet
	elif not rigged and index >= 0 and index < textures.size():
		tex = textures[index]
	sprite.texture = tex
	sprite.visible = tex != null
	if sheet != null:
		sprite.hframes = sheet_grids[index].x
		sprite.vframes = sheet_grids[index].y
	else:
		sprite.hframes = 1
		sprite.vframes = 1
	sprite.frame = 0
	if tex != null:
		sprite.centered = false
		sprite.offset = Vector2(-tex.get_width() / sprite.hframes / 2.0, -float(tex.get_height()) / sprite.vframes)
	_drop.texture = tex
	_drop.hframes = sprite.hframes
	_drop.vframes = sprite.vframes
	_drop.offset = sprite.offset
	_drop.visible = sprite.visible and shadow_enabled
	_t = 0.0
	_apply_idle(sprite)
	var what := "rig %s" % rig.name if rigged else (tex.resource_path.get_file() if tex else "none")
	if sheet != null:
		what += " (%d frames @ %.1f fps)" % [sheet_counts[index], sheet_fps[index]]
	print("[standing_character] panel %d -> %s" % [index, what])


## The rig node shown for a panel: the Olivia avatar for rigged_index, else rigs[index]; null if none.
func _rig_for(index: int) -> Node2D:
	if index == rigged_index:
		var av := get_node_or_null(rigged_avatar) as Node2D
		if av != null:
			return av
	if index >= 0 and index < rigs.size() and not rigs[index].is_empty():
		return get_node_or_null(rigs[index]) as Node2D
	return null


func _all_rigs() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var av := get_node_or_null(rigged_avatar) as Node2D
	if av != null:
		out.append(av)
	for p in rigs:
		if p.is_empty():
			continue
		var r := get_node_or_null(p) as Node2D
		if r != null and not out.has(r):
			out.append(r)
	return out


func _sheet_for(index: int) -> Texture2D:
	if index < 0 or index >= sheets.size() or sheets[index] == null:
		return null
	if index >= sheet_grids.size() or index >= sheet_counts.size() or index >= sheet_fps.size():
		return null
	return sheets[index]


func _scale_for(index: int) -> float:
	if index >= 0 and index < texture_scales.size() and texture_scales[index] > 0.0:
		return texture_scales[index]
	return pixel_scale


func _process(delta: float) -> void:
	var sprite := get_node("Sprite") as Sprite2D
	if sprite.visible:
		_t += delta
		_apply_idle(sprite)
	if _rig != null and _rig_shadows.has(_rig) and (_rig_shadows[_rig] as CanvasGroup).visible:
		_sync_rig_shadow(_rig)


func _apply_idle(sprite: Sprite2D) -> void:
	var base := _scale_for(current)
	if _sheet_for(current) != null:
		# sheet animation: the frames carry the idle motion, no procedural breath/sway on top
		sprite.frame = int(_t * sheet_fps[current]) % maxi(sheet_counts[current], 1)
		sprite.scale = Vector2(base, base)
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
		_sync_drop(sprite)
		return
	var w := TAU * _t / idle_period
	var breath := sin(w)
	var sway := sin(w * 0.5 + 0.8)  # one lean per two breaths
	sprite.scale = Vector2(base * (1.0 - breath_scale * 0.5 * breath), base * (1.0 + breath_scale * breath))
	sprite.rotation = deg_to_rad(sway_degrees) * sway
	sprite.position = Vector2(sway_shift * sway, 0.0)
	_sync_drop(sprite)


## Offset + lean applied around the feet (this node's origin / the avatar's origin).
func _shadow_xform() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE, shadow_skew, shadow_offset)


func _sync_drop(sprite: Sprite2D) -> void:
	if _drop == null or not _drop.visible:
		return
	_drop.frame = sprite.frame
	_drop.transform = _shadow_xform() * sprite.transform


## A nodes-only copy of the rig (no scripts, signals or groups: the IK and particle scripts stay on
## the original), stripped of its AnimationPlayers and floor ellipse, every part forced to the
## group's own z order, wrapped in a CanvasGroup that paints the whole composite in shadow_color.
func _build_rig_shadow(avatar: Node2D) -> void:
	var copy := avatar.duplicate(0) as Node2D
	copy.name = "RigCopy"
	copy.transform = Transform2D.IDENTITY
	copy.visible = true
	copy.process_mode = Node.PROCESS_MODE_INHERIT
	for n in copy.find_children("*", "AnimationPlayer", true, false):
		n.get_parent().remove_child(n)
		n.free()
	var ellipse := copy.get_node_or_null("Shadow")
	if ellipse != null:
		ellipse.get_parent().remove_child(ellipse)
		ellipse.free()
	for ci in copy.find_children("*", "CanvasItem", true, false):
		ci.z_index = 0
		ci.z_as_relative = true
	var grp := CanvasGroup.new()
	grp.name = "%sDropShadow" % avatar.name
	grp.self_modulate = shadow_color  # self_modulate: tints the composite, not each part
	grp.add_child(copy)
	var parent := avatar.get_parent()
	parent.add_child(grp)
	parent.move_child(grp, avatar.get_index())  # drawn right under the rig
	var pairs: Array = []
	for o in avatar.find_children("*", "CanvasItem", true, false):
		var c := copy.get_node_or_null(avatar.get_path_to(o))
		if c != null:
			pairs.append([o, c])
	_rig_shadows[avatar] = grp
	_rig_pairs[avatar] = pairs
	print("[standing_character] rig drop shadow for %s: %d parts mirrored" % [avatar.name, pairs.size()])


func _sync_rig_shadow(avatar: Node2D) -> void:
	if avatar == null or not _rig_shadows.has(avatar):
		return
	(_rig_shadows[avatar] as CanvasGroup).transform = _shadow_xform() * avatar.transform
	for pr in _rig_pairs[avatar]:
		var o: CanvasItem = pr[0]
		var c: CanvasItem = pr[1]
		c.visible = o.visible
		if o is Node2D:
			(c as Node2D).transform = (o as Node2D).transform
		if o is Sprite2D:
			var os := o as Sprite2D
			var cs := c as Sprite2D
			cs.texture = os.texture
			cs.frame = os.frame
			cs.offset = os.offset
			cs.flip_h = os.flip_h
			cs.flip_v = os.flip_v
		elif o is Polygon2D:
			(c as Polygon2D).texture = (o as Polygon2D).texture
