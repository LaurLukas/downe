class_name WolfAttackDisplay
extends Control

## Spectacle screen for a Wolf Attack in progress - see
## wolf_attack_tv_display.md for the full spec this implements a
## functional (not pixel-perfect) version of. Read-only, like
## TVDisplay: this never mutates core/ state, only renders
## WolfAttackView.build(game_state). CLAUDE.md constraint 3 - the
## physical gathering at the battle table is the point, this just
## supports it.
##
## Deliberately simplified vs. the full spec (agreed scope for this
## pass - see TODO.md): plain Controls and an HFlowContainer instead of
## a custom flow layout, no staged reveal animations or condensed
## fonts/exact pixel sizing, basic color-coding via theme overrides.
## Rebuilds freely on every GameState.mutated - no editable input here
## for a rebuild to interrupt, same reasoning as TVDisplay.

@onready var _incoming_panel: VBoxContainer = %IncomingPanel
@onready var _incoming_composition: Label = %IncomingComposition
@onready var _incoming_capacity: Label = %IncomingCapacity
@onready var _incoming_turn_pursuit: Label = %IncomingTurnPursuit

@onready var _standing_panel: VBoxContainer = %StandingPanel
@onready var _phase_tracker: Label = %PhaseTracker
@onready var _wolf_capacity_label: Label = %WolfCapacityLabel
@onready var _wolf_grid: HFlowContainer = %WolfGrid
@onready var _fleet_row: HBoxContainer = %FleetRow
@onready var _phase_banner: Label = %PhaseBanner

@onready var _boarding_panel: VBoxContainer = %BoardingPanel
@onready var _boarding_list: HBoxContainer = %BoardingList

@onready var _resolution_panel: VBoxContainer = %ResolutionPanel
@onready var _resolution_list: VBoxContainer = %ResolutionList
@onready var _resolution_returning: Label = %ResolutionReturning
@onready var _resolution_note: Label = %ResolutionNote

const STANDING_PHASES: Array[String] = ["targeting", "range_long", "range_medium", "range_short"]
const RANGE_PHASE_LABELS: Dictionary[String, String] = {
	"range_long": "LONG", "range_medium": "MEDIUM", "range_short": "SHORT",
}

var game_state: GameState:
	set(value):
		if game_state != null:
			game_state.mutated.disconnect(_refresh)
		game_state = value
		if game_state != null:
			game_state.mutated.connect(_refresh)
			_refresh()

func _refresh() -> void:
	var view := WolfAttackView.build(game_state)
	if view.is_empty():
		visible = false
		return
	visible = true

	var phase: String = view["phase"]
	_incoming_panel.visible = phase == "incoming"
	_standing_panel.visible = phase in STANDING_PHASES
	_boarding_panel.visible = phase == "boarding"
	_resolution_panel.visible = phase == "resolution"

	match phase:
		"incoming":
			_refresh_incoming(view)
		"boarding":
			_refresh_boarding(view)
		"resolution":
			_refresh_resolution(view)
		_:
			if phase in STANDING_PHASES:
				_refresh_standing(view)

func _refresh_incoming(view: Dictionary) -> void:
	var counts: Dictionary[String, int] = {}
	var total_capacity := 0
	for wolf_ship: Dictionary in view["wolf_ships"]:
		var cls: String = wolf_ship["class"]
		counts[cls] = counts.get(cls, 0) + 1
		total_capacity += wolf_ship["capacity"]
	var parts: Array[String] = []
	for cls: String in counts:
		parts.append("%d %s" % [counts[cls], cls.capitalize()])
	_incoming_composition.text = "  |  ".join(parts) if not parts.is_empty() else "(no ships added yet)"
	_incoming_capacity.text = "TOTAL DAMAGE CAPACITY: %d" % total_capacity
	_incoming_turn_pursuit.text = "TURN %d - PURSUIT %d/10" % [view["turn"], view["pursuit"]]

func _refresh_standing(view: Dictionary) -> void:
	var phase: String = view["phase"]
	_phase_tracker.text = "WOLF ATTACK - TURN %d - %s" % [view["turn"], RANGE_PHASE_LABELS.get(phase, phase.to_upper())]

	var remaining := 0
	var total := 0
	for wolf_ship: Dictionary in view["wolf_ships"]:
		total += wolf_ship["capacity"]
		remaining += wolf_ship["capacity"] - wolf_ship["damage_taken"]
	_wolf_capacity_label.text = "WOLF FORCE - %d / %d CAPACITY" % [remaining, total]

	for child in _wolf_grid.get_children():
		child.free()
	for wolf_ship: Dictionary in view["wolf_ships"]:
		_wolf_grid.add_child(_build_wolf_token(wolf_ship))

	for child in _fleet_row.get_children():
		child.free()
	for fleet_ship: Dictionary in view["fleet_ships"]:
		_fleet_row.add_child(_build_fleet_card(fleet_ship))

	var weapon_line := "LIVE: %s" % (", ".join(view["live_fleet_weapons"]) if not view["live_fleet_weapons"].is_empty() else "none")
	var fighter_wings_alive: int = view["fighter_wings_alive"]
	if phase == "range_short" and fighter_wings_alive > 0:
		_phase_banner.text = "⚠ ALL FLEET DAMAGE MUST BE ASSIGNED TO WOLF FIGHTER WINGS FIRST\n%s" % weapon_line
		_phase_banner.add_theme_color_override("font_color", Color.ORANGE)
	else:
		_phase_banner.text = weapon_line
		_phase_banner.remove_theme_color_override("font_color")

func _build_wolf_token(wolf_ship: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(140, 100)
	var column := VBoxContainer.new()
	box.add_child(column)

	if wolf_ship.has("target"):
		var target_label := Label.new()
		target_label.text = ShipRegistry.display_name(wolf_ship["target"])
		target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(target_label)

	var class_label := Label.new()
	class_label.text = WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[wolf_ship["class"].to_upper()], "??")
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(class_label)

	var pips := Label.new()
	pips.text = "%s%s" % ["●".repeat(wolf_ship["damage_taken"]), "○".repeat(maxi(wolf_ship["capacity"] - wolf_ship["damage_taken"], 0))]
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pips)

	var detail := Label.new()
	if wolf_ship["destroyed"]:
		detail.text = "DESTROYED"
		box.modulate = Color(0.5, 0.3, 0.3)
	elif wolf_ship["immune_this_phase"]:
		detail.text = "IMMUNE"
	elif wolf_ship["prevents"] != null:
		detail.text = "PREVENTS %d" % wolf_ship["prevents"]
	elif wolf_ship["boarders"] > 0:
		detail.text = "%d BOARDERS" % wolf_ship["boarders"]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)

	if wolf_ship["returns_if_survives"] and not wolf_ship["destroyed"]:
		var returns_label := Label.new()
		returns_label.text = "↻ returns"
		returns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(returns_label)

	return box

func _build_fleet_card(fleet_ship: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	box.add_child(column)

	var name_label := Label.new()
	name_label.text = ShipRegistry.display_name(fleet_ship["id"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var incoming_label := Label.new()
	var incoming: int = fleet_ship["incoming_damage"]
	incoming_label.text = str(incoming)
	incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(incoming_label)

	var status_label := Label.new()
	status_label.text = "CLEAR" if incoming == 0 else "INCOMING"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.GREEN if incoming == 0 else Color.ORANGE_RED)
	column.add_child(status_label)

	var security_label := Label.new()
	security_label.text = "SEC TEAMS %d" % fleet_ship["security_teams"]
	security_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(security_label)

	if fleet_ship["boarders_inbound"] > 0:
		var boarders_label := Label.new()
		boarders_label.text = "⚔ %d BOARDERS INBOUND" % fleet_ship["boarders_inbound"]
		boarders_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boarders_label.add_theme_color_override("font_color", Color.RED)
		column.add_child(boarders_label)

	if fleet_ship["critical"]:
		box.modulate = Color(1.0, 0.6, 0.6)

	if incoming == 0 and fleet_ship["boarders_inbound"] == 0:
		box.modulate = Color(1, 1, 1, 0.6)

	return box

func _refresh_boarding(view: Dictionary) -> void:
	for child in _boarding_list.get_children():
		child.free()
	for fleet_ship: Dictionary in view["fleet_ships"]:
		if fleet_ship["boarders_inbound"] <= 0:
			continue
		_boarding_list.add_child(_build_boarding_card(view, fleet_ship))

func _build_boarding_card(view: Dictionary, fleet_ship: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(360, 260)
	var column := VBoxContainer.new()
	box.add_child(column)

	var name_label := Label.new()
	name_label.text = ShipRegistry.display_name(fleet_ship["id"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var numbers_row := HBoxContainer.new()
	var boarders_col := VBoxContainer.new()
	var boarders_number := Label.new()
	boarders_number.text = str(fleet_ship["boarders_inbound"])
	boarders_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boarders_caption := Label.new()
	boarders_caption.text = "BOARDERS"
	boarders_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boarders_col.add_child(boarders_number)
	boarders_col.add_child(boarders_caption)
	var teams_col := VBoxContainer.new()
	var teams_number := Label.new()
	teams_number.text = str(fleet_ship["security_teams"])
	teams_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var teams_caption := Label.new()
	teams_caption.text = "SEC TEAMS"
	teams_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teams_col.add_child(teams_number)
	teams_col.add_child(teams_caption)
	numbers_row.add_child(boarders_col)
	numbers_row.add_child(teams_col)
	column.add_child(numbers_row)

	for support: Dictionary in fleet_ship["support_craft"]:
		var support_label := Label.new()
		var definition := CraftDefinitions.get_definition(support["id"])
		var craft_name: String = definition.display_name if definition != null else support["id"]
		support_label.text = "⬡ %s DOCKED - %s" % [craft_name, support["effect"]]
		support_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		column.add_child(support_label)

	if view["wolf_commander_leading_boarding"] and view["wolf_commander_leading_boarding_ship_id"] == fleet_ship["id"]:
		var commander_label := Label.new()
		commander_label.text = "⚔ WOLF COMMANDER LEADING +2"
		commander_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		commander_label.add_theme_color_override("font_color", Color.RED)
		column.add_child(commander_label)

	if fleet_ship["critical"]:
		box.modulate = Color(1.0, 0.6, 0.6)

	return box

func _refresh_resolution(view: Dictionary) -> void:
	for child in _resolution_list.get_children():
		child.free()
	for fleet_ship: Dictionary in view["fleet_ships"]:
		var line := Label.new()
		var damage: int = fleet_ship["damage_this_attack"]
		line.text = "%s      %s" % [
			ShipRegistry.display_name(fleet_ship["id"]),
			("●".repeat(damage) + "  %d DAMAGE" % damage) if damage > 0 else "—  NO DAMAGE",
		]
		_resolution_list.add_child(line)

	var returning: Array = view["returning"]
	var parts: Array[String] = []
	for entry: Dictionary in returning:
		parts.append("↻ %d %s" % [entry["count"], WolfShipDefinitions.class_name_for(WolfShipDefinitions.Class[entry["class"].to_upper()])])
	_resolution_returning.text = "RETURNING: %s" % (" · ".join(parts) if not parts.is_empty() else "none")

	_resolution_note.text = "(Survivor loss per damage point is not modeled yet - unconfirmed, see TODO.md. Only damage pips are shown above.)"
