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
		_group_list.add_child(_build_group_card(group, view))
	_rebuild_wolf_presence(view)
	_rebuild_scout_reports(view)

func _node_by_id(view: Dictionary, coordinate: String) -> Dictionary:
	for node: Dictionary in (view["nodes"] as Array):
		if node["id"] == coordinate:
			return node
	return {}

## "HERE n" (§6.1) - derived from the node's own visited_turns rather
## than a stored counter: how many turns since the most recent arrival
## there, inclusive. Works for the group's *current* node specifically
## because an occupied node's visited_turns always has a real arrival
## turn as its last entry (FleetPositions records one on every
## relocate(), including the group that's still sitting there).
func _turns_here(node: Dictionary, current_turn: int) -> int:
	if not node.has("visited_turns"):
		return 0
	var turns: Array = node["visited_turns"]
	if turns.is_empty():
		return 0
	return current_turn - int(turns[-1]) + 1

## §6.2 - only ever visited/occupied wolf systems, filtered directly off
## the projection's own node array (state + class, both already leak-
## safe) - "structurally unable to read a letter the projection did not
## send."
func _rebuild_wolf_presence(view: Dictionary) -> void:
	var wolf_nodes: Array = (view["nodes"] as Array).filter(func(n: Dictionary) -> bool:
		return String(n.get("class", "")) == "wolf" and (n["state"] == "visited" or n["state"] == "occupied")
	)
	if wolf_nodes.is_empty():
		return

	var group_at_coordinate: Dictionary[String, Dictionary] = {}
	for group: Dictionary in (view["groups"] as Array):
		group_at_coordinate[String(group["at"])] = group

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var wolf := StarMapTokens.WOLF
	style.bg_color = Color(wolf.r, wolf.g, wolf.b, 0.06)
	style.border_color = Color(wolf.r, wolf.g, wolf.b, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var header := HBoxContainer.new()
	var header_label := Label.new()
	header_label.text = "WOLF PRESENCE"
	WolfAttackTokens.apply(header_label, "T_CARD_NAME")
	header_label.add_theme_color_override("font_color", wolf)
	header_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(header_label)
	var count_label := Label.new()
	count_label.text = "CONFIRMED %d" % wolf_nodes.size()
	WolfAttackTokens.apply(count_label, "T_STAT")
	count_label.add_theme_color_override("font_color", wolf)
	header.add_child(count_label)
	box.add_child(header)

	for node: Dictionary in wolf_nodes:
		var row := HBoxContainer.new()
		var left := Label.new()
		left.text = "[%s] %s  %s" % [String(node["letter"]), String(node["id"]), String(node.get("short_name", ""))]
		WolfAttackTokens.apply(left, "T_STAT")
		left.add_theme_color_override("font_color", StarMapTokens.TEXT_PRIMARY)
		left.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(left)

		var right := Label.new()
		WolfAttackTokens.apply(right, "T_STAT")
		var coordinate := String(node["id"])
		if group_at_coordinate.has(coordinate):
			var occupying: Dictionary = group_at_coordinate[coordinate]
			var occupying_representative: Dictionary = occupying["representative"]
			right.text = "%s HERE" % String(occupying_representative["abbr"])
			right.add_theme_color_override("font_color", StarMapTokens.group_colour(bool(occupying_representative["is_aegis"])))
		elif node.has("left_turn"):
			right.text = "LEFT T%d" % int(node["left_turn"])
			right.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
		row.add_child(right)
		box.add_child(row)

	_group_list.add_child(panel)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	_group_list.add_child(spacer)

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

## §6.1's full group card: title/coordinate/letter-badge header,
## members, the current node's consequence summary (if it has one),
## scout reach, pursuit pips, and "HERE n". A 4px top accent bar in the
## group's colour stands in for the spec's full-width rule.
func _build_group_card(group: Dictionary, view: Dictionary) -> Control:
	var representative: Dictionary = group["representative"]
	var is_aegis: bool = bool(representative["is_aegis"])
	var colour := StarMapTokens.group_colour(is_aegis)
	var node_at := _node_by_id(view, String(group["at"]))
	var total_groups: int = (view["groups"] as Array).size()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = colour
	style.border_width_top = 4
	style.content_margin_top = 10.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	var index_part := "(%d) " % int(group["index"]) if total_groups > 1 else ""
	var letter_badge := ""
	if node_at.has("letter"):
		var class_colour := StarMapTokens.class_tint(String(node_at.get("class", "")))
		letter_badge = "  [bgcolor=#%s][color=#0B0F1C] %s [/color][/bgcolor]" % [class_colour.to_html(false), String(node_at["letter"])]
	header.text = "[font_size=26][b][color=#%s]%s%s[/color][/b]  [color=#%s]%s[/color]%s[/font_size]" % [
		colour.to_html(false), index_part, String(group["label"]),
		colour.to_html(false), String(group["at"]), letter_badge,
	]
	box.add_child(header)

	var members_label := Label.new()
	members_label.text = " · ".join((group["members"] as Array).map(func(m: Variant) -> String: return String(m).to_upper()))
	WolfAttackTokens.apply(members_label, "T_STAT")
	members_label.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
	members_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(members_label)

	# Consequence summary (§6.1's line 3) - "why the fleet's situation is
	# legible without anyone reading the paper chart." Only present when
	# the current node actually has one (StarMapProjection already gates
	# this the same way it gates letter/name/class).
	if node_at.has("consequence_summary"):
		var consequence_label := Label.new()
		consequence_label.text = String(node_at["consequence_summary"])
		WolfAttackTokens.apply(consequence_label, "T_STAT")
		consequence_label.add_theme_color_override("font_color", StarMapTokens.class_tint(String(node_at.get("class", ""))))
		box.add_child(consequence_label)

	# Scout reach - "a scout's range follows its parent hull, and hulls
	# live in groups" (§6.1). Ranged scouts share one line; each
	# unlimited-range scout gets its own ("ENDEAVOUR · ANY SYSTEM").
	var scouts: Array = group["scouts"]
	var ranged: Array[String] = []
	var unlimited: Array[String] = []
	for scout: Variant in scouts:
		var scout_dict: Dictionary = scout
		if bool(scout_dict.get("unlimited", false)):
			unlimited.append(String(scout_dict["label"]))
		else:
			ranged.append("%s %d" % [String(scout_dict["label"]), int(scout_dict["jumps"])])
	if not ranged.is_empty():
		var reach_label := Label.new()
		reach_label.text = "SCOUT REACH · %s" % " · ".join(ranged)
		WolfAttackTokens.apply(reach_label, "T_STAT")
		reach_label.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
		box.add_child(reach_label)
	for scout_label: String in unlimited:
		var unlimited_label := Label.new()
		unlimited_label.text = "%s · ANY SYSTEM" % scout_label
		WolfAttackTokens.apply(unlimited_label, "T_STAT")
		unlimited_label.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
		box.add_child(unlimited_label)

	var pursuit_row := HBoxContainer.new()
	var pursuit_caption := Label.new()
	pursuit_caption.text = "PURSUIT "
	WolfAttackTokens.apply(pursuit_caption, "T_STAT")
	pursuit_caption.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
	pursuit_row.add_child(pursuit_caption)
	var pips := StarMapPursuitPips.new()
	pips.value = int(group["pursuit"])
	pursuit_row.add_child(pips)
	var pursuit_value_label := Label.new()
	pursuit_value_label.text = " %d" % int(group["pursuit"])
	WolfAttackTokens.apply(pursuit_value_label, "T_STAT")
	pursuit_value_label.add_theme_color_override("font_color", StarMapTokens.CLAIM)
	pursuit_row.add_child(pursuit_value_label)
	var here_spacer := Control.new()
	here_spacer.custom_minimum_size = Vector2(20, 0)
	here_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	pursuit_row.add_child(here_spacer)
	var turns_here := _turns_here(node_at, int(view["turn"]))
	if turns_here > 0:
		var here_label := Label.new()
		here_label.text = "HERE %d" % turns_here
		WolfAttackTokens.apply(here_label, "T_STAT")
		here_label.add_theme_color_override("font_color", StarMapTokens.TEXT_SECONDARY)
		pursuit_row.add_child(here_label)
	box.add_child(pursuit_row)

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

	return panel
