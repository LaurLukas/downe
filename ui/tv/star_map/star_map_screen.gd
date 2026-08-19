class_name StarMapScreen
extends Control

## Star map TV screen - docs/star_map_tv_display.md. Read-only, like
## TVDisplay/WolfAttackDisplay: never mutates core/ state, only renders
## StarMapProjection.build(). Structural pass - correct data/geometry
## using plain Godot Controls, not the spec's pixel-exact typography,
## draw-in animation, or the automatic "up for 45s after a jump / idle
## at 60% brightness" show/hide behavior (§8) - that belongs in
## ui/main.gd once this screen is wired in alongside TVDisplay/
## WolfAttackDisplay, not here. See TODO.md.
##
## Rebuilds freely on every GameState.mutated, same reasoning as
## TVDisplay/WolfAttackDisplay: there's no editable input here for a
## rebuild to interrupt, since this screen never mutates state.

@onready var _title_label: Label = %TitleLabel
@onready var _canvas: StarMapCanvas = %CanvasNode
@onready var _group_list: VBoxContainer = %GroupList
@onready var _idle_veil: ColorRect = %IdleVeil

## §10 idle mode - "a veil over everything, draw-in suppressed, pulse
## kept. One flag." Since this pass doesn't build the draw-in animation
## or the locator pulse (see star_map_canvas.gd's header), this is
## literally just the veil - the mechanism ui/main.gd's show/hide policy
## can flip once it decides when "idle" actually applies (still an open
## question - see TODO.md on why StarMapScreen isn't yet the TV's
## default idle screen).
var idle_dim: bool = false:
	set(value):
		idle_dim = value
		if is_node_ready():
			_idle_veil.visible = value

var game_state: GameState:
	set(value):
		if game_state != null:
			game_state.mutated.disconnect(_refresh)
		game_state = value
		if game_state != null:
			game_state.mutated.connect(_refresh)
			_refresh()

func _refresh() -> void:
	if game_state == null:
		return
	var view := StarMapProjection.build(
		game_state.chart_in_play,
		game_state.turn_manager.turn_number,
		game_state.fleet_positions,
		game_state.reveal_state,
		game_state.craft,
	)
	var groups: Array = view["groups"]
	# §8: the split chip only appears once there's something to say -
	# "when the fleet is whole the header says nothing further about
	# it", same principle as dropping a lone group token's "+n".
	var split_suffix := "   ·   FLEET SPLIT · %d GROUPS" % groups.size() if groups.size() > 1 else ""
	_title_label.text = "STAR MAP  /  TURN %d · CHART %s%s" % [int(view["turn"]), String(view["chart_id"]), split_suffix]
	_canvas.view = view
	_rebuild_group_list(view)

func _rebuild_group_list(view: Dictionary) -> void:
	# free(), not queue_free() - see TVDisplay's own comment on why: the
	# replacement children are added in this same call, and a deferred
	# free would briefly leave old and new rows coexisting as siblings.
	for child in _group_list.get_children():
		child.free()
	var groups: Array = view["groups"]
	for group: Dictionary in groups:
		_group_list.add_child(_build_group_card(group, groups.size()))
	_rebuild_scout_reports(view)

## §6.3 - the design-handoff override that moves claim *text* off the
## map entirely (the map keeps only a claim-count chip, see
## star_map_canvas.gd's _draw_info_chip()). Scanning `view["nodes"]` for
## a "claims" key is the leak-safe path already established - a claim
## only ever appears on a node the projection actually attached it to,
## same object the map itself reads.
func _rebuild_scout_reports(view: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	for node: Dictionary in (view["nodes"] as Array):
		if not node.has("claims"):
			continue
		for claim: Variant in (node["claims"] as Array):
			entries.append({"coordinate": String(node["id"]), "claim": claim as Dictionary})
	if entries.is_empty():
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int((a["claim"] as Dictionary)["turn"]) > int((b["claim"] as Dictionary)["turn"]))

	var header := Label.new()
	header.text = "SCOUT REPORTS · UNVERIFIED"
	WolfAttackTokens.apply(header, "T_CARD_NAME")
	header.add_theme_color_override("font_color", StarMapTokens.CLAIM)
	_group_list.add_child(header)

	for entry: Dictionary in entries:
		var claim: Dictionary = entry["claim"]
		var meta_line := Label.new()
		meta_line.text = "%s   %s · T%d" % [String(entry["coordinate"]), String(claim["source"]), int(claim["turn"])]
		WolfAttackTokens.apply(meta_line, "T_STAT")
		meta_line.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
		_group_list.add_child(meta_line)

		var text_line := Label.new()
		text_line.text = "“%s”" % String(claim["text"])
		WolfAttackTokens.apply(text_line, "T_STAT")
		text_line.add_theme_color_override("font_color", Color("#E4D8B4"))
		text_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		_group_list.add_child(text_line)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_group_list.add_child(spacer)

func _build_group_card(group: Dictionary, total_groups: int) -> Control:
	var box := VBoxContainer.new()

	var representative: Dictionary = group["representative"]
	var colour := StarMapTokens.group_colour(bool(representative["is_aegis"]))

	var header := Label.new()
	var prefix := "%d  " % int(group["index"]) if total_groups > 1 else ""
	header.text = "%s%s   %s" % [prefix, String(group["label"]), String(group["at"])]
	WolfAttackTokens.apply(header, "T_CARD_NAME")
	header.add_theme_color_override("font_color", colour)
	box.add_child(header)

	var members_label := Label.new()
	members_label.text = " · ".join(group["members"] as Array)
	WolfAttackTokens.apply(members_label, "T_STAT")
	members_label.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
	members_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(members_label)

	var pursuit_label := Label.new()
	pursuit_label.text = "PURSUIT %d" % int(group["pursuit"])
	WolfAttackTokens.apply(pursuit_label, "T_STAT")
	pursuit_label.add_theme_color_override("font_color", StarMapTokens.TEXT_PRIMARY)
	box.add_child(pursuit_label)

	var pending: Array = group["pending_merge_pursuits"]
	if not pending.is_empty():
		var pending_label := Label.new()
		pending_label.text = "MERGE PENDING - HOST MUST RECONCILE: %s" % [", ".join(pending.map(func(v: Variant) -> String: return str(v)))]
		WolfAttackTokens.apply(pending_label, "T_STAT")
		pending_label.add_theme_color_override("font_color", StarMapTokens.CLAIM)
		pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(pending_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	return box
