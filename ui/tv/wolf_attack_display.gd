class_name WolfAttackDisplay
extends Control

## Spectacle screen for a Wolf Attack in progress - see
## wolf_attack_tv_display.md for the original spec and
## wolf_attack_tv_display_v2_gap_spec.md for the STANDING layout's visual
## spec (supersedes that original doc's visual sections only). Read-only,
## like TVDisplay: this never mutates core/ state, only renders
## WolfAttackView.build(game_state). CLAUDE.md constraint 3 - the physical
## gathering at the battle table is the point, this just supports it.
##
## The STANDING layout (targeting + all three range phases) is authored
## against a fixed 1920×1080 design space - see ui/main.gd's tv_window
## content_scale setup, which makes this Control's local coordinates line
## up with that canvas regardless of the actual OS window size. Custom-
## drawn ship icons (ship_icon.gd) are still a first pass, not pixel-
## matched - this environment has no way to render/screenshot a live
## Godot window, so all pixel-level tuning after this pass has to come
## from someone actually looking at it running. Rebuilds freely on every
## GameState.mutated - no editable input here for a rebuild to interrupt,
## same reasoning as TVDisplay.

@onready var _title_label: Label = %TitleLabel
@onready var _incoming_panel: VBoxContainer = %IncomingPanel
@onready var _incoming_composition: Label = %IncomingComposition
@onready var _incoming_capacity: Label = %IncomingCapacity
@onready var _incoming_turn_pursuit: Label = %IncomingTurnPursuit

@onready var _standing_panel: Control = %StandingPanel
@onready var _standing_title_label: Label = %StandingTitleLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _stat_line: RichTextLabel = %StatLine
@onready var _pursuit_meter: PursuitMeter = %PursuitMeterNode
@onready var _pursuit_value_label: Label = %PursuitValueLabel
@onready var _header_rule: ColorRect = %HeaderRule
@onready var _phase_breadcrumb: HBoxContainer = %PhaseBreadcrumb
@onready var _range_bands: RangeBands = %RangeBandsNode
@onready var _wolf_force_row: HBoxContainer = %WolfForceRow
@onready var _fleet_row: HBoxContainer = %FleetRow
@onready var _attack_vectors: TargetingLines = %AttackVectors
@onready var _phase_banner: Label = %PhaseBanner
@onready var _targeting_wraps_label: Label = %TargetingWrapsLabel
@onready var _cannot_be_targeted_label: Label = %CannotBeTargetedLabel
@onready var _cannot_be_targeted_row: HBoxContainer = %CannotBeTargetedRow

@onready var _boarding_panel: VBoxContainer = %BoardingPanel
@onready var _boarding_list: HBoxContainer = %BoardingList

@onready var _resolution_panel: VBoxContainer = %ResolutionPanel
@onready var _resolution_list: VBoxContainer = %ResolutionList
@onready var _resolution_returning: Label = %ResolutionReturning
@onready var _resolution_note: Label = %ResolutionNote

const STANDING_PHASES: Array[String] = ["targeting", "range_long", "range_medium", "range_short"]
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
## either - see WolfAttackView's own comment on why, and
## wolf_attack_tv_display_v2_gap_spec.md §9's open item #2 (their exact
## footer rules need verifying against the Facilitator Guide before they
## can be added here).
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
	var standing: bool = phase in STANDING_PHASES
	# The STANDING layout draws its own "WOLF ATTACK" title inside the
	# fixed 1920x1080 canvas (wolf_attack_tv_display_v2_gap_spec.md §4.2),
	# so the shared Root-level title - still used by the other three
	# phases, none of which are part of that spec - is hidden underneath
	# it rather than shown twice.
	_title_label.visible = not standing
	_incoming_panel.visible = phase == "incoming"
	_standing_panel.visible = standing
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
			if standing:
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

	_standing_title_label.text = WolfAttackTokens.fmt_display("Wolf Attack")
	WolfAttackTokens.apply(_standing_title_label, "T_TITLE")
	_standing_title_label.add_theme_color_override("font_color", WolfAttackTokens.INK)

	_turn_label.text = WolfAttackTokens.fmt_display("Turn %d" % view["turn"])
	WolfAttackTokens.apply(_turn_label, "T_TURN")
	_turn_label.add_theme_color_override("font_color", WolfAttackTokens.INK_DIM)

	var total_capacity := 0
	for wolf_ship: Dictionary in view["wolf_ships"]:
		total_capacity += wolf_ship["capacity"]
	var pursuit: int = view["pursuit"]
	var cap := WOLF_COMMANDER_BASE_FORCE + pursuit
	_refresh_stat_line(total_capacity, pursuit, cap)
	_refresh_pursuit_meter(pursuit)
	_header_rule.color = WolfAttackTokens.RULE
	_refresh_phase_breadcrumb(phase)
	_range_bands.visible = phase != "targeting"
	_range_bands.active_phase = phase

	for child in _wolf_force_row.get_children():
		child.free()
	var token_by_wolf_id: Dictionary[String, Control] = {}
	for wolf_ship: Dictionary in view["wolf_ships"]:
		var token := _build_wolf_item(wolf_ship)
		_wolf_force_row.add_child(token)
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
		links.append({"from": token_by_wolf_id[wolf_ship["id"]], "to": card_by_ship_id[target_id]})
	_attack_vectors.set_links(links)

	# P0-08: no "LIVE: <weapon>" debug line on the TV output - that's
	# host-console material, not something 20 players standing around a
	# battle map need to read off a screen (see the spec's §4.10).
	var fighter_wings_alive: int = view["fighter_wings_alive"]
	if phase == "range_short" and fighter_wings_alive > 0:
		_phase_banner.text = WolfAttackTokens.fmt_display("⚠ All fleet damage must be assigned to Wolf fighter wings first")
		_phase_banner.visible = true
		_phase_banner.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
	else:
		_phase_banner.visible = false

	_targeting_wraps_label.text = "TARGETING WRAPS · 7 → 1 · 0 → 6"
	WolfAttackTokens.apply(_targeting_wraps_label, "T_WRAPS")
	_targeting_wraps_label.add_theme_color_override("font_color", WolfAttackTokens.CYAN_DIM)

	_cannot_be_targeted_label.text = WolfAttackTokens.fmt_display("Cannot be targeted")
	WolfAttackTokens.apply(_cannot_be_targeted_label, "T_FOOTER_LABEL")
	_cannot_be_targeted_label.add_theme_color_override("font_color", WolfAttackTokens.INK_DIM)

	_refresh_cannot_be_targeted()

## "FORCE 10 + PURSUIT 6 = 16 CAP · 16 COMMITTED", field labels in
## INK_DIM, numbers in INK, separators in INK_GHOST, COMMITTED colored by
## whether it's under/at/over the cap (spec §4.2's fix list) - built as
## BBCode on one RichTextLabel per the spec's own suggestion, rather than
## an HBoxContainer of alternating Labels.
func _refresh_stat_line(committed: int, pursuit: int, cap: int) -> void:
	var ink := WolfAttackTokens.INK.to_html(false)
	var dim := WolfAttackTokens.INK_DIM.to_html(false)
	var ghost := WolfAttackTokens.INK_GHOST.to_html(false)
	var committed_color := WolfAttackTokens.INK_DIM if committed < cap else WolfAttackTokens.ALERT
	if committed > cap:
		push_error("WolfAttackDisplay: committed (%d) exceeds cap (%d) - should not be reachable" % [committed, cap])
	WolfAttackTokens.apply(_stat_line, "T_STAT")
	_stat_line.text = "[color=#%s]FORCE[/color] [color=#%s]%d[/color] [color=#%s]+[/color] [color=#%s]PURSUIT[/color] [color=#%s]%d[/color] [color=#%s]=[/color] [color=#%s]%d[/color] [color=#%s]CAP[/color] [color=#%s]·[/color] [color=#%s]%d[/color] [color=#%s]COMMITTED[/color]" % [
		dim, ink, WOLF_COMMANDER_BASE_FORCE, ghost,
		dim, ink, pursuit, ghost,
		ink, cap, dim, ghost,
		committed_color.to_html(false), committed, dim,
	]

func _refresh_pursuit_meter(pursuit: int) -> void:
	_pursuit_meter.pursuit = pursuit
	_pursuit_value_label.text = "%d / %d" % [pursuit, PursuitTrack.MAX_VALUE]
	WolfAttackTokens.apply(_pursuit_value_label, "T_PURSUIT_NUM")
	_pursuit_value_label.add_theme_color_override("font_color", WolfAttackTokens.AMBER)

## Inactive phases are almost invisible (INK_GHOST); the active one is
## larger, bold, CYAN, preceded by a filled dot. Each item's width is
## fixed to its own active-state width so the row doesn't reflow visibly
## as the active item's size changes across phase transitions (spec §4.4).
func _refresh_phase_breadcrumb(current_phase: String) -> void:
	for child in _phase_breadcrumb.get_children():
		child.free()
	_phase_breadcrumb.add_theme_constant_override("separation", 18)
	for i in BREADCRUMB_PHASES.size():
		var phase_id := BREADCRUMB_PHASES[i]
		var active := phase_id == current_phase
		_phase_breadcrumb.add_child(_build_phase_item(phase_id, active))
		if i < BREADCRUMB_PHASES.size() - 1:
			var dash := Label.new()
			dash.text = "—"
			dash.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
			_phase_breadcrumb.add_child(dash)

func _build_phase_item(phase_id: String, active: bool) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 6)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_color_override("font_color", WolfAttackTokens.CYAN if active else WolfAttackTokens.INK_GHOST)
	dot.add_theme_font_size_override("font_size", 12)
	item.add_child(dot)

	var label := Label.new()
	label.text = WolfAttackTokens.fmt_display(BREADCRUMB_LABELS[phase_id])
	var token := "T_PHASE_ACTIVE" if active else "T_PHASE"
	WolfAttackTokens.apply(label, token)
	label.add_theme_color_override("font_color", WolfAttackTokens.CYAN if active else WolfAttackTokens.INK_GHOST)
	item.add_child(label)

	var active_font := WolfAttackTokens.font("T_PHASE_ACTIVE")
	var active_size := WolfAttackTokens.font_size("T_PHASE_ACTIVE")
	var active_width := 12.0 + 6.0 + active_font.get_string_size(WolfAttackTokens.fmt_display(BREADCRUMB_LABELS[phase_id]), HORIZONTAL_ALIGNMENT_LEFT, -1, active_size).x
	item.custom_minimum_size.x = active_width
	return item

## One wolf ship class silhouette + a code/pips/returns line + an
## ability label + a target line, no panel/border (spec §4.5, P0-04).
func _build_wolf_item(wolf_ship: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 12)

	var icon := ShipIcon.new()
	icon.icon_id = wolf_ship["class"]
	icon.icon_color = WolfAttackTokens.INK_GHOST if wolf_ship["destroyed"] else WolfAttackTokens.INK
	icon.custom_minimum_size = Vector2(0, 95)
	icon.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_child(icon)

	var code_pips := WolfCodePips.new()
	code_pips.code_text = WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[wolf_ship["class"].to_upper()], "??")
	code_pips.capacity = wolf_ship["capacity"]
	code_pips.damage_taken = wolf_ship["damage_taken"]
	code_pips.show_returns = wolf_ship["returns_if_survives"]
	code_pips.destroyed = wolf_ship["destroyed"]
	code_pips.custom_minimum_size = Vector2(0, 40)
	column.add_child(code_pips)

	var ability := Label.new()
	ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	WolfAttackTokens.apply(ability, "T_WOLF_ABILITY")
	ability.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
	if wolf_ship["destroyed"]:
		ability.text = WolfAttackTokens.fmt_display("Destroyed")
		ability.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
	elif wolf_ship["immune_this_phase"]:
		ability.text = WolfAttackTokens.fmt_display("Immune")
	else:
		match wolf_ship["class"]:
			"battlestation":
				ability.text = "SIEGE BATTERY"
			"strikecarrier":
				ability.text = "STOPS FW BUFF"
			"assault_transport":
				ability.text = "PREVENTS %d BP" % wolf_ship["boarders"]
			_:
				ability.text = "PREVENTS %d" % wolf_ship["prevents"] if wolf_ship["prevents"] != null else ""
	column.add_child(ability)

	if wolf_ship.has("target") and not wolf_ship["target"].is_empty():
		var target_label := Label.new()
		target_label.text = WolfAttackTokens.fmt_display("→ %s" % ShipRegistry.display_name(wolf_ship["target"]))
		WolfAttackTokens.apply(target_label, "T_WOLF_TARGET")
		target_label.add_theme_color_override("font_color", WolfAttackTokens.INK_DIM)
		column.add_child(target_label)

	return column

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
## only ever shown during targeting/range phases, before that happens, so
## boarders_inbound would always read 0 here. Summed the same way the
## wolf item's own "PREVENTS N BP" label already does, from each live
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

## Fixed-height card, dark translucent backing, 3px signature-color bar
## inside the top padding, colored index number + filled icon, name,
## damage line, bottom chip row. Targeted cards get an ALERT border +
## glow (spec §4.8, P1-09..P1-12, P1-18 - landed together with P0-04's
## wolf-item rebuild since both needed the same card_by_ship_id plumbing).
func _build_fleet_card(fleet_ship: Dictionary, wolf_ships: Array) -> Control:
	var ship_id: String = fleet_ship["id"]
	var color := WolfAttackTokens.ship_color(ship_id)
	var incoming: int = fleet_ship["incoming_damage"]
	var critical: bool = fleet_ship["critical"]
	var projected_boarders := _projected_boarders_for(ship_id, wolf_ships)
	var targeted := incoming > 0 or projected_boarders > 0

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 4)

	var sec_label := Label.new()
	sec_label.text = "SEC %d" % fleet_ship["security_teams"]
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	WolfAttackTokens.apply(sec_label, "T_SEC")
	sec_label.add_theme_color_override("font_color", color)
	outer.add_child(sec_label)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, WolfAttackTokens.FLEET_CARD_HEIGHT)
	box.size_flags_vertical = SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(18)
	style.set_border_width_all(2 if targeted else 1)
	style.border_color = WolfAttackTokens.ALERT if targeted else WolfAttackTokens.RULE
	style.bg_color = WolfAttackTokens.CARD_BG_TARGETED if targeted else WolfAttackTokens.CARD_BG
	if targeted:
		style.shadow_color = Color(WolfAttackTokens.ALERT, 0.25)
		style.shadow_size = 14
	box.add_theme_stylebox_override("panel", style)
	if critical:
		box.modulate = Color(1.0, 0.6, 0.6)
	outer.add_child(box)

	var column := VBoxContainer.new()
	box.add_child(column)

	var top_bar := ColorRect.new()
	top_bar.color = color
	top_bar.custom_minimum_size = Vector2(0, 3)
	column.add_child(top_bar)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var index_label := Label.new()
	var index: Variant = WolfShipDefinitions.TARGETING_TABLE.find_key(ship_id)
	index_label.text = str(index) if index != null else "?"
	WolfAttackTokens.apply(index_label, "T_CARD_INDEX")
	index_label.add_theme_color_override("font_color", color)
	header_row.add_child(index_label)
	var icon := ShipIcon.new()
	icon.icon_id = ship_id
	icon.icon_color = color
	icon.custom_minimum_size = Vector2(90, 34)
	header_row.add_child(icon)
	column.add_child(header_row)

	var name_label := Label.new()
	name_label.text = WolfAttackTokens.fmt_display(ShipRegistry.display_name(ship_id))
	WolfAttackTokens.apply(name_label, "T_CARD_NAME")
	name_label.add_theme_color_override("font_color", WolfAttackTokens.INK)
	column.add_child(name_label)

	var damage_row := HBoxContainer.new()
	damage_row.add_theme_constant_override("separation", 4)
	if incoming > 0:
		var dmg_marker := Label.new()
		dmg_marker.text = "◄"
		WolfAttackTokens.apply(dmg_marker, "T_DMG_SUFFIX")
		dmg_marker.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
		damage_row.add_child(dmg_marker)
		var dmg_label := Label.new()
		dmg_label.text = str(incoming)
		WolfAttackTokens.apply(dmg_label, "T_DMG_NUM")
		dmg_label.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
		damage_row.add_child(dmg_label)
		var dmg_caption := Label.new()
		dmg_caption.text = "DMG"
		WolfAttackTokens.apply(dmg_caption, "T_DMG_SUFFIX")
		dmg_caption.add_theme_color_override("font_color", Color(WolfAttackTokens.ALERT, 0.8))
		damage_row.add_child(dmg_caption)
	else:
		var dash_label := Label.new()
		dash_label.text = "—"
		WolfAttackTokens.apply(dash_label, "T_DMG_SUFFIX")
		dash_label.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		damage_row.add_child(dash_label)
	column.add_child(damage_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(spacer)

	var tags_row := HBoxContainer.new()
	tags_row.add_theme_constant_override("separation", 6)
	for code in _targeting_classes_for(ship_id, wolf_ships):
		tags_row.add_child(_make_chip(code, WolfAttackTokens.ALERT, WolfAttackTokens.ALERT, false))
	if projected_boarders > 0:
		tags_row.add_child(_make_chip("%d BP" % projected_boarders, WolfAttackTokens.ALERT_DEEP, WolfAttackTokens.INK, true))
	column.add_child(tags_row)

	return outer

## A small bordered tag chip, matching the reference's class-code and
## boarding-party markers. filled draws a solid ALERT_DEEP background
## (the highlighted "N BP" tag, deliberately a different visual category
## from ship-type tags since boarding is a separate resolution step, not
## another damage source - spec §4.8); otherwise just an outline.
func _make_chip(text: String, border_color: Color, text_color: Color, filled: bool) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.border_color = border_color
	style.set_border_width_all(0 if filled else 1)
	style.set_content_margin_all(6)
	style.bg_color = border_color if filled else Color(0, 0, 0, 0)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = WolfAttackTokens.fmt_display(text)
	WolfAttackTokens.apply(label, "T_CHIP")
	label.add_theme_color_override("font_color", text_color)
	chip.add_child(label)
	return chip

## The fleet's own combat craft the Wolves can't target - short names,
## cyan triangles, optional numeric value (spec §4.9). Small Ship
## defensive assets (Gorgoneion's shield, Vulcan's laser) belong here too
## per the spec but aren't modeled as core/ objects yet - see this file's
## FIGHTER_CRAFT_IDS comment and TODO.md's open item.
func _refresh_cannot_be_targeted() -> void:
	for child in _cannot_be_targeted_row.get_children():
		child.free()
	for craft_id: String in FIGHTER_CRAFT_IDS:
		var craft_state := game_state.get_craft(craft_id)
		if craft_state == null:
			continue
		var definition := CraftDefinitions.get_definition(craft_id)
		var short_name: String = definition.short_name if definition != null else craft_id
		_cannot_be_targeted_row.add_child(_build_untargetable_entry(short_name, definition))

func _build_untargetable_entry(short_name: String, definition: CraftDefinition) -> Control:
	var craft_state := game_state.get_craft(definition.id) if definition != null else null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var triangle := Label.new()
	triangle.text = "▲"
	triangle.add_theme_font_size_override("font_size", 14)
	triangle.add_theme_color_override("font_color", WolfAttackTokens.CYAN)
	row.add_child(triangle)

	var name_label := Label.new()
	name_label.text = WolfAttackTokens.fmt_display(short_name)
	WolfAttackTokens.apply(name_label, "T_FOOTER_ITEM")
	name_label.add_theme_color_override("font_color", WolfAttackTokens.CYAN)
	row.add_child(name_label)

	if definition != null and definition.craft_class == CraftDefinition.Class.FIGHTER_WING and craft_state != null:
		var value_label := Label.new()
		value_label.text = str(craft_state.fighter_count)
		WolfAttackTokens.apply(value_label, "T_FOOTER_VALUE")
		value_label.add_theme_color_override("font_color", Color(WolfAttackTokens.CYAN, 0.6))
		row.add_child(value_label)

	return row

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
