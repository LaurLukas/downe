class_name WolfAttackDisplay
extends Control

## Spectacle screen for a Wolf Attack in progress - see
## wolf_attack_tv_display.md for the original spec and
## Wolf_Ships-selection.png for the reference mockup the STANDING
## layout (targeting + all three range phases) is built to match.
## Read-only, like TVDisplay: this never mutates core/ state, only
## renders WolfAttackView.build(game_state). CLAUDE.md constraint 3 -
## the physical gathering at the battle table is the point, this just
## supports it.
##
## Custom-drawn ship icons (ship_icon.gd) and the ship-identity color
## palette (wolf_display_palette.gd) are a first pass, not pixel-
## matched - hand-derived from looking at the reference image, with no
## way in this environment to render/screenshot a live Godot window and
## check the result. Expect to iterate visually once someone actually
## runs it. Rebuilds freely on every GameState.mutated - no editable
## input here for a rebuild to interrupt, same reasoning as TVDisplay.

@onready var _incoming_panel: VBoxContainer = %IncomingPanel
@onready var _incoming_composition: Label = %IncomingComposition
@onready var _incoming_capacity: Label = %IncomingCapacity
@onready var _incoming_turn_pursuit: Label = %IncomingTurnPursuit

@onready var _standing_panel: VBoxContainer = %StandingPanel
@onready var _force_summary_label: Label = %ForceSummaryLabel
@onready var _pursuit_bar_container: HBoxContainer = %PursuitBarContainer
@onready var _pursuit_value_label: Label = %PursuitValueLabel
@onready var _phase_breadcrumb: HBoxContainer = %PhaseBreadcrumb
@onready var _battle_area: Control = %BattleArea
@onready var _wolf_capacity_label: Label = %WolfCapacityLabel
@onready var _wolf_grid: HFlowContainer = %WolfGrid
@onready var _fleet_row: HBoxContainer = %FleetRow
@onready var _targeting_lines_overlay: TargetingLines = %TargetingLinesOverlay
@onready var _targeting_wraps_label: Label = %TargetingWrapsLabel
@onready var _phase_banner: Label = %PhaseBanner
@onready var _cannot_be_targeted_row: HBoxContainer = %CannotBeTargetedRow

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
const BREADCRUMB_PHASES: Array[String] = ["targeting", "range_long", "range_medium", "range_short", "boarding", "resolution"]
const BREADCRUMB_LABELS: Dictionary[String, String] = {
	"targeting": "TARGETING", "range_long": "LONG", "range_medium": "MEDIUM",
	"range_short": "SHORT", "boarding": "BOARDING", "resolution": "RESOLVE",
}

## Wolf Commander formula (open_questions_answered.md §3.2): 10 damage
## capacity + the current Pursuit Track value. Used only for the
## "FORCE 10 + PURSUIT N = CAP" reference line the reference mockup
## shows - not a rule this screen enforces, just context for the host.
const WOLF_COMMANDER_BASE_FORCE := 10

## Combat craft the fleet can commit - the "cannot be targeted" strip.
## Only what's actually modeled: fighter wings + the PDF Escort. Console
## weapons (Missile Launchers etc.) and Small Ship consoles (Gorgoneion's
## Missile Array, Vulcan's Laser Cannon) aren't in live_fleet_weapons
## either - see WolfAttackView's own comment on why.
const FIGHTER_CRAFT_IDS: Array[String] = ["fighter_wing_alpha", "fighter_wing_bravo", "pdf_escort_wing"]

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

	var total_capacity := 0
	for wolf_ship: Dictionary in view["wolf_ships"]:
		total_capacity += wolf_ship["capacity"]
	var pursuit: int = view["pursuit"]
	_force_summary_label.text = "FORCE %d + PURSUIT %d = %d CAP  ·  %d COMMITTED" % [
		WOLF_COMMANDER_BASE_FORCE, pursuit, WOLF_COMMANDER_BASE_FORCE + pursuit, total_capacity,
	]
	_refresh_pursuit_bar(pursuit)
	_refresh_phase_breadcrumb(phase)

	var remaining := 0
	for wolf_ship: Dictionary in view["wolf_ships"]:
		remaining += wolf_ship["capacity"] - wolf_ship["damage_taken"]
	_wolf_capacity_label.text = "WOLF FORCE - %d / %d CAPACITY" % [remaining, total_capacity]

	for child in _wolf_grid.get_children():
		child.free()
	var token_by_wolf_id: Dictionary[String, Control] = {}
	for wolf_ship: Dictionary in view["wolf_ships"]:
		var token := _build_wolf_token(wolf_ship)
		_wolf_grid.add_child(token)
		token_by_wolf_id[wolf_ship["id"]] = token

	for child in _fleet_row.get_children():
		child.free()
	var card_by_ship_id: Dictionary[String, Control] = {}
	for fleet_ship: Dictionary in view["fleet_ships"]:
		var card := _build_fleet_card(fleet_ship, view["wolf_ships"])
		_fleet_row.add_child(card)
		card_by_ship_id[fleet_ship["id"]] = card

	var links: Array[Dictionary] = []
	for wolf_ship: Dictionary in view["wolf_ships"]:
		if wolf_ship["destroyed"] or not wolf_ship.has("target"):
			continue
		var target_id: String = wolf_ship["target"]
		if target_id.is_empty() or not card_by_ship_id.has(target_id):
			continue
		links.append({
			"from": token_by_wolf_id[wolf_ship["id"]],
			"to": card_by_ship_id[target_id],
			"color": WolfDisplayPalette.WOLF_RED,
		})
	_targeting_lines_overlay.set_links(links)

	var weapon_line := "LIVE: %s" % (", ".join(view["live_fleet_weapons"]) if not view["live_fleet_weapons"].is_empty() else "none")
	var fighter_wings_alive: int = view["fighter_wings_alive"]
	if phase == "range_short" and fighter_wings_alive > 0:
		_phase_banner.text = "⚠ ALL FLEET DAMAGE MUST BE ASSIGNED TO WOLF FIGHTER WINGS FIRST\n%s" % weapon_line
		_phase_banner.add_theme_color_override("font_color", WolfDisplayPalette.ALERT)
	else:
		_phase_banner.text = weapon_line
		_phase_banner.remove_theme_color_override("font_color")

	_refresh_cannot_be_targeted()

func _refresh_pursuit_bar(pursuit: int) -> void:
	for child in _pursuit_bar_container.get_children():
		child.free()
	for i in PursuitTrack.MAX_VALUE:
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(18, 20)
		if i < pursuit:
			segment.color = WolfDisplayPalette.PURSUIT_FILLED
		elif i == PursuitTrack.MAX_VALUE - 1:
			segment.color = WolfDisplayPalette.PURSUIT_DANGER
		else:
			segment.color = WolfDisplayPalette.PURSUIT_EMPTY
		_pursuit_bar_container.add_child(segment)
	_pursuit_value_label.text = "%d / %d" % [pursuit, PursuitTrack.MAX_VALUE]

func _refresh_phase_breadcrumb(current_phase: String) -> void:
	for child in _phase_breadcrumb.get_children():
		child.free()
	for i in BREADCRUMB_PHASES.size():
		var phase_id := BREADCRUMB_PHASES[i]
		var active := phase_id == current_phase
		var label := Label.new()
		label.text = "%s %s" % ["⦿" if active else "•", BREADCRUMB_LABELS[phase_id]]
		label.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_PRIMARY if active else WolfDisplayPalette.TEXT_MUTED)
		_phase_breadcrumb.add_child(label)
		if i < BREADCRUMB_PHASES.size() - 1:
			var dash := Label.new()
			dash.text = " — "
			dash.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_MUTED)
			_phase_breadcrumb.add_child(dash)

func _build_wolf_token(wolf_ship: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(150, 130)
	var column := VBoxContainer.new()
	box.add_child(column)

	var icon := ShipIcon.new()
	icon.icon_id = wolf_ship["class"]
	icon.icon_color = WolfDisplayPalette.WOLF_DIM if wolf_ship["destroyed"] else WolfDisplayPalette.TEXT_PRIMARY
	icon.custom_minimum_size = Vector2(130, 50)
	column.add_child(icon)

	var code_row := Label.new()
	code_row.text = "%s  %s%s" % [
		WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[wolf_ship["class"].to_upper()], "??"),
		"●".repeat(wolf_ship["damage_taken"]), "○".repeat(maxi(wolf_ship["capacity"] - wolf_ship["damage_taken"], 0)),
	]
	code_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(code_row)

	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wolf_ship["destroyed"]:
		detail.text = "DESTROYED"
		box.modulate = Color(0.6, 0.45, 0.45)
	elif wolf_ship["immune_this_phase"]:
		detail.text = "IMMUNE"
	else:
		match wolf_ship["class"]:
			"battlestation":
				detail.text = "SIEGE BATTERY"
			"strikecarrier":
				detail.text = "STOPS FW BUFF"
			"assault_transport":
				detail.text = "PREVENTS %d BP" % wolf_ship["boarders"]
			_:
				if wolf_ship["prevents"] != null:
					detail.text = "PREVENTS %d" % wolf_ship["prevents"]
	detail.add_theme_color_override("font_color", WolfDisplayPalette.WOLF_RED)
	column.add_child(detail)

	if wolf_ship.has("target") and not wolf_ship["target"].is_empty():
		var target_label := Label.new()
		target_label.text = "→ %s" % ShipRegistry.display_name(wolf_ship["target"])
		target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_label.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_MUTED)
		column.add_child(target_label)

	if wolf_ship["returns_if_survives"] and not wolf_ship["destroyed"]:
		var returns_label := Label.new()
		returns_label.text = "↻ returns"
		returns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(returns_label)

	return box

## Which wolf ship classes (one tag per live wolf ship, not
## deduplicated) currently target this fleet ship - not part of
## WolfAttackView's contract, computed here from data the view already
## exposes (each wolf ship's own target/class/destroyed fields).
func _targeting_classes_for(ship_id: String, wolf_ships: Array) -> Array[String]:
	var codes: Array[String] = []
	for wolf_ship: Dictionary in wolf_ships:
		if wolf_ship["destroyed"] or not wolf_ship.has("target"):
			continue
		if wolf_ship["target"] != ship_id:
			continue
		codes.append(WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[wolf_ship["class"].to_upper()], "??"))
	return codes

## Boarding parties this fleet ship would take if its attackers survive
## to the boarding phase - deliberately NOT fleet_ship["boarders_inbound"],
## which WolfAttackView only populates once the attack actually reaches
## Phase.BOARDING (see wolf_attack.gd's _start_boarding()). This card is
## only ever shown during targeting/range phases, before that happens,
## so boarders_inbound would always read 0 here. Summed the same way the
## wolf token's own "PREVENTS N BP" preview already does, from each live
## wolf ship's own "boarders" field.
func _projected_boarders_for(ship_id: String, wolf_ships: Array) -> int:
	var total := 0
	for wolf_ship: Dictionary in wolf_ships:
		if wolf_ship["destroyed"] or not wolf_ship.has("target"):
			continue
		if wolf_ship["target"] != ship_id:
			continue
		total += wolf_ship.get("boarders", 0)
	return total

func _build_fleet_card(fleet_ship: Dictionary, wolf_ships: Array) -> Control:
	var ship_id: String = fleet_ship["id"]
	var color := WolfDisplayPalette.ship_color(ship_id)
	var incoming: int = fleet_ship["incoming_damage"]
	var critical: bool = fleet_ship["critical"]
	var projected_boarders := _projected_boarders_for(ship_id, wolf_ships)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = SIZE_EXPAND_FILL

	var top_strip := ColorRect.new()
	top_strip.color = WolfDisplayPalette.WOLF_RED if critical else color
	top_strip.custom_minimum_size = Vector2(0, 4)
	outer.add_child(top_strip)

	var sec_label := Label.new()
	sec_label.text = "SEC %d" % fleet_ship["security_teams"]
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sec_label.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_MUTED)
	outer.add_child(sec_label)

	var box := PanelContainer.new()
	if critical:
		box.modulate = Color(1.0, 0.6, 0.6)
	elif incoming == 0 and projected_boarders == 0:
		box.modulate = Color(1, 1, 1, 0.6)
	outer.add_child(box)

	var column := VBoxContainer.new()
	box.add_child(column)

	var header_row := HBoxContainer.new()
	var index_label := Label.new()
	var index: Variant = WolfShipDefinitions.TARGETING_TABLE.find_key(ship_id)
	index_label.text = str(index) if index != null else "?"
	index_label.add_theme_color_override("font_color", color)
	header_row.add_child(index_label)
	var icon := ShipIcon.new()
	icon.icon_id = ship_id
	icon.icon_color = color
	icon.custom_minimum_size = Vector2(90, 40)
	header_row.add_child(icon)
	column.add_child(header_row)

	var name_label := Label.new()
	name_label.text = ShipRegistry.display_name(ship_id)
	column.add_child(name_label)

	var damage_row := HBoxContainer.new()
	if incoming > 0:
		var dmg_label := Label.new()
		dmg_label.text = "◄ %d" % incoming
		dmg_label.add_theme_color_override("font_color", WolfDisplayPalette.WOLF_RED)
		damage_row.add_child(dmg_label)
		var dmg_caption := Label.new()
		dmg_caption.text = "DMG"
		dmg_caption.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_MUTED)
		damage_row.add_child(dmg_caption)
	else:
		var dash_label := Label.new()
		dash_label.text = "—"
		dash_label.add_theme_color_override("font_color", WolfDisplayPalette.TEXT_MUTED)
		damage_row.add_child(dash_label)
	column.add_child(damage_row)

	var tags_row := HBoxContainer.new()
	for code in _targeting_classes_for(ship_id, wolf_ships):
		tags_row.add_child(_make_chip(code, WolfDisplayPalette.WOLF_RED, WolfDisplayPalette.WOLF_RED, false))
	if projected_boarders > 0:
		tags_row.add_child(_make_chip("%d BP" % projected_boarders, WolfDisplayPalette.WOLF_RED, WolfDisplayPalette.TEXT_PRIMARY, true))
	column.add_child(tags_row)

	return outer

## A small bordered tag chip, matching the reference's class-code and
## boarding-party markers. filled draws a solid background (the
## highlighted "N BP" tag); otherwise just a border with transparent
## fill (the plain class-code tags).
func _make_chip(text: String, border_color: Color, text_color: Color, filled: bool) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	style.bg_color = border_color if filled else Color(0, 0, 0, 0)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", text_color)
	chip.add_child(label)
	return chip

func _refresh_cannot_be_targeted() -> void:
	for child in _cannot_be_targeted_row.get_children():
		child.free()
	for craft_id: String in FIGHTER_CRAFT_IDS:
		var craft_state := game_state.get_craft(craft_id)
		if craft_state == null:
			continue
		var definition := CraftDefinitions.get_definition(craft_id)
		var label := Label.new()
		var name: String = definition.display_name if definition != null else craft_id
		if definition != null and definition.craft_class == CraftDefinition.Class.FIGHTER_WING:
			label.text = "▲ %s %d" % [name, craft_state.fighter_count]
		else:
			label.text = "▲ %s" % name
		label.add_theme_color_override("font_color", WolfDisplayPalette.OK)
		_cannot_be_targeted_row.add_child(label)

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
