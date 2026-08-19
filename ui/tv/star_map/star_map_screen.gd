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
	)
	_title_label.text = "TURN %d  ·  CHART %s IN PLAY" % [int(view["turn"]), String(view["chart_id"])]
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

func _build_group_card(group: Dictionary, total_groups: int) -> Control:
	var box := VBoxContainer.new()

	var representative: Dictionary = group["representative"]
	var colour := Color(String(representative["colour"]))

	var header := Label.new()
	var prefix := "%d  " % int(group["index"]) if total_groups > 1 else ""
	header.text = "%s%s   %s" % [prefix, String(group["label"]), String(group["at"])]
	WolfAttackTokens.apply(header, "T_CARD_NAME")
	header.add_theme_color_override("font_color", colour)
	box.add_child(header)

	var members_label := Label.new()
	members_label.text = " · ".join(group["members"] as Array)
	WolfAttackTokens.apply(members_label, "T_STAT")
	members_label.add_theme_color_override("font_color", WolfAttackTokens.INK_DIM)
	members_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(members_label)

	var pursuit_label := Label.new()
	pursuit_label.text = "PURSUIT %d" % int(group["pursuit"])
	WolfAttackTokens.apply(pursuit_label, "T_STAT")
	pursuit_label.add_theme_color_override("font_color", WolfAttackTokens.INK)
	box.add_child(pursuit_label)

	var pending: Array = group["pending_merge_pursuits"]
	if not pending.is_empty():
		var pending_label := Label.new()
		pending_label.text = "MERGE PENDING - HOST MUST RECONCILE: %s" % [", ".join(pending.map(func(v: Variant) -> String: return str(v)))]
		WolfAttackTokens.apply(pending_label, "T_STAT")
		pending_label.add_theme_color_override("font_color", WolfAttackTokens.AMBER)
		pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(pending_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	return box
