class_name WolfAttackDisplay
extends Control

## Spectacle screen for a Wolf Attack in progress - see
## wolf_attack_tv_display.md for the original spec,
## wolf_attack_tv_display_v2_gap_spec.md for the STANDING layout's first
## visual pass, and
## ui/design_handoff_wolf_attack_lanes/wolf_attack_tv_display_v3_lanes.md
## for the lane-layout rebuild this file now implements (supersedes v2's
## §4.5-4.8/§6 - single wolf row, bezier vectors, gutter bands, attacker
## chip row - all deleted per that spec's §7; v2's backdrop/header/
## pursuit-meter/phase-rail/footer stay in force unchanged). Read-only,
## like TVDisplay: this never mutates core/ state, only renders
## WolfAttackView.build(game_state). CLAUDE.md constraint 3 - the physical
## gathering at the battle table is the point, this just supports it.
##
## The STANDING layout is authored against a fixed 1920×1080 design space
## - see ui/main.gd's tv_window content_scale setup, which makes this
## Control's local coordinates line up with that canvas regardless of the
## actual OS window size. Rebuilds freely on every GameState.mutated - no
## editable input here for a rebuild to interrupt, same reasoning as
## TVDisplay.
##
## Deliberately NOT built in this pass (documented, not silently skipped -
## see TODO.md for the full writeup):
## - Token pooling and the targeting-phase "tween from staging pool into
##   lane" spectacle (spec §6.1/§11). This project's own established
##   pattern for a first structural pass is data/geometry-correct now,
##   animation polish later (see the v2 P0/P1/P2 split) - there's no way
##   to visually verify a tween's feel without a human watching a live
##   window. Every element rebuilds fresh each refresh, same as v2's
##   WolfForceRow/FleetRow always did.
## - The staging pool is, in this project's actual WolfAttack state
##   machine, structurally unreachable: targets are pre-rolled the instant
##   a wolf ship is added and revealed in full the moment the attack
##   leaves Phase.INCOMING (core/combat/wolf_attack_view.gd's
##   targets_visible gate), so no wolf ever reaches "targeting" with an
##   empty target_ship_id. The render path below is still implemented
##   correctly for a wolf that genuinely has none.
## - The impact arc's ±14px "settle" tween on phase change.

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

@onready var _wolf_tally_label: RichTextLabel = %WolfTallyLabel
@onready var _range_label: Label = %RangeLabel
@onready var _lane_row: HBoxContainer = %LaneRow
@onready var _lane_spines: LaneSpines = %LaneSpinesNode
@onready var _impact_arc: ImpactArc = %ImpactArcNode
@onready var _staging_pool: Control = %StagingPool
@onready var _staging_pool_label: Label = %StagingPoolLabel
@onready var _staging_pool_flow: HFlowContainer = %StagingPoolFlow

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
## either - see WolfAttackView's own comment on why. Their exact footer
## numbers are now known (TODO.md) but they still aren't core/ objects,
## so there's nothing here yet to read a charged/damaged state from.
const FIGHTER_CRAFT_IDS: Array[String] = ["fighter_wing_alpha", "fighter_wing_bravo", "pdf_escort_wing"]

## Lane geometry that never moves regardless of the roomy-case shift -
## the card band always ends at y 906 (spec §2), so a lane's total height
## is always this fixed span from the top of the stack zone.
const LANE_HEIGHT := 906.0 - WolfAttackTokens.Y_STACK_ZONE_TOP

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
	# fixed 1920x1080 canvas, so the shared Root-level title - still used
	# by the other three phases, none of which are part of that layout -
	# is hidden underneath it rather than shown twice.
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

	var wolf_ships: Array = view["wolf_ships"]
	var fleet_ships: Array = view["fleet_ships"]

	var total_capacity := 0
	for wolf_ship: Dictionary in wolf_ships:
		total_capacity += wolf_ship["capacity"]
	var pursuit: int = view["pursuit"]
	var cap := WOLF_COMMANDER_BASE_FORCE + pursuit
	_refresh_stat_line(total_capacity, pursuit, cap)
	_refresh_pursuit_meter(pursuit)
	_header_rule.color = WolfAttackTokens.RULE
	_refresh_phase_breadcrumb(phase)

	_refresh_wolf_tally(wolf_ships)
	_range_label.text = WolfAttackTokens.fmt_display("Range · %s" % BREADCRUMB_LABELS.get(phase, phase))
	WolfAttackTokens.apply(_range_label, "T_RANGE_LABEL")
	_range_label.add_theme_color_override("font_color", WolfAttackTokens.CYAN)

	fleet_ships = WolfLaneLayout.sort_fleet_ships_by_targeting_order(fleet_ships)
	var fleet_ship_ids: Array = fleet_ships.map(func(f: Dictionary): return f["id"])
	var lanes := WolfLaneLayout.group_by_lane(wolf_ships, fleet_ship_ids)
	var stack_value := WolfLaneLayout.max_stack(lanes)
	var tier := WolfLaneLayout.tier_for(stack_value)
	var geo := WolfLaneLayout.stack_zone_geometry(stack_value)
	var n_lanes: int = fleet_ship_ids.size()
	var lane_width := WolfLaneLayout.lane_width_for(n_lanes)

	_impact_arc.impact_y = geo["impact_y"]
	_impact_arc.active_phase = phase
	_impact_arc.visible = phase != "targeting"

	for child in _lane_row.get_children():
		child.free()
	var centred := n_lanes <= 4
	_lane_row.alignment = BoxContainer.ALIGNMENT_CENTER if centred else BoxContainer.ALIGNMENT_BEGIN

	# LaneSpines shares StandingPanel's coordinate space, not LaneRow's -
	# so this has to independently reproduce wherever the row's own
	# ALIGNMENT_CENTER puts its first child, not just start from
	# SAFE_MARGIN_X unconditionally.
	var spines: Array[Dictionary] = []
	var row_content_width := float(n_lanes) * lane_width + maxf(float(n_lanes - 1), 0.0) * WolfLaneLayout.LANE_GAP
	var lane_x := WolfAttackTokens.SAFE_MARGIN_X
	if centred:
		lane_x += (WolfLaneLayout.CONTENT_WIDTH - row_content_width) * 0.5
	for fleet_ship: Dictionary in fleet_ships:
		var ship_id: String = fleet_ship["id"]
		var wolves: Array = lanes.get(ship_id, [])
		var lane := _build_lane(fleet_ship, wolves, tier, lane_width, geo, phase, spines, lane_x)
		_lane_row.add_child(lane)
		lane_x += lane_width + WolfLaneLayout.LANE_GAP

	_lane_spines.set_spines(spines)

	_refresh_staging_pool(lanes.get(WolfLaneLayout.STAGING_POOL_KEY, []), tier, phase)

	# P0-08: no "LIVE: <weapon>" debug line on the TV output - that's
	# host-console material, not something 20 players standing around a
	# battle map need to read off a screen.
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
## whether it's under/at/over the cap - built as BBCode on one
## RichTextLabel. Over-cap gets a visible CAP EXCEEDED chip (spec §10.1).
##
## Deliberately NOT a push_error (v2 had one here; removed after it fired
## in real host-console use, not just synthetic test data): the base-10-
## plus-pursuit cap is advisory context for the host, not a rule the game
## enforces, and the Facilitator's Guide's own worked examples exceed it
## on purpose - the printed turn-1 attack is "10 Wolf Fighter Wings and 5
## Wolf Assault Transports" against a pursuit-0 cap of 10, and later
## attacks are sized by total damage capacity (15-24), not by this
## formula at all. Exceeding it is normal play, not a bug to report.
func _refresh_stat_line(committed: int, pursuit: int, cap: int) -> void:
	var ink := WolfAttackTokens.INK.to_html(false)
	var dim := WolfAttackTokens.INK_DIM.to_html(false)
	var ghost := WolfAttackTokens.INK_GHOST.to_html(false)
	var over_cap := committed > cap
	var committed_color := WolfAttackTokens.INK_DIM if not over_cap else WolfAttackTokens.ALERT
	WolfAttackTokens.apply(_stat_line, "T_STAT")
	var text := "[color=#%s]FORCE[/color] [color=#%s]%d[/color] [color=#%s]+[/color] [color=#%s]PURSUIT[/color] [color=#%s]%d[/color] [color=#%s]=[/color] [color=#%s]%d[/color] [color=#%s]CAP[/color] [color=#%s]·[/color] [color=#%s]%d[/color] [color=#%s]COMMITTED[/color]" % [
		dim, ink, WOLF_COMMANDER_BASE_FORCE, ghost,
		dim, ink, pursuit, ghost,
		ink, cap, dim, ghost,
		committed_color.to_html(false), committed, dim,
	]
	if over_cap:
		var warn := WolfAttackTokens.AMBER.to_html(false)
		text += "   [bgcolor=#%s][color=#%s] CAP EXCEEDED [/color][/bgcolor]" % [Color(WolfAttackTokens.AMBER, 0.16).to_html(true), warn]
	_stat_line.text = text

func _refresh_pursuit_meter(pursuit: int) -> void:
	_pursuit_meter.pursuit = pursuit
	_pursuit_value_label.text = "%d / %d" % [pursuit, PursuitTrack.MAX_VALUE]
	WolfAttackTokens.apply(_pursuit_value_label, "T_PURSUIT_NUM")
	_pursuit_value_label.add_theme_color_override("font_color", WolfAttackTokens.AMBER)

## Inactive phases are almost invisible (INK_GHOST); the active one is
## larger, bold, CYAN, preceded by a filled dot. Each item's width is
## fixed to its own active-state width so the row doesn't reflow visibly
## as the active item's size changes across phase transitions.
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

## §8: one derived, never-stored line - live hull counts only, omitted
## when a hull has none, plus "N DESTROYED" (omitted when zero, per the
## .md spec; its README wants "NONE DESTROYED" instead - the .md is the
## authoritative target per its own supersession note, so that's what
## this follows, see TODO.md).
func _refresh_wolf_tally(wolf_ships: Array) -> void:
	var counts: Dictionary[String, int] = {}
	var order: Array[String] = []
	var destroyed_count := 0
	for wolf: Dictionary in wolf_ships:
		if wolf["destroyed"]:
			destroyed_count += 1
			continue
		var cls: String = wolf["class"]
		if not counts.has(cls):
			order.append(cls)
		counts[cls] = counts.get(cls, 0) + 1

	var dim := WolfAttackTokens.INK_DIM.to_html(false)
	var ink := WolfAttackTokens.INK.to_html(false)
	var ghost := WolfAttackTokens.INK_GHOST.to_html(false)
	var parts: Array[String] = []
	for cls: String in order:
		var code: String = WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[cls.to_upper()], "??")
		parts.append("[color=#%s]%s[/color][color=#%s]×[/color][color=#%s]%d[/color]" % [dim, code, ghost, ink, counts[cls]])
	var text := "   ".join(parts)
	if destroyed_count > 0:
		if not text.is_empty():
			text += "   [color=#%s]·[/color]   " % ghost
		text += "[color=#%s]%d DESTROYED[/color]" % [ghost, destroyed_count]
	WolfAttackTokens.apply(_wolf_tally_label, "T_TALLY")
	_wolf_tally_label.text = text if not text.is_empty() else "[color=#%s](no wolves added yet)[/color]" % ghost

## Builds one lane's full Control tree (Wash, Stack, IncomingLine,
## FleetCard). Appends this lane's spine descriptor (if attacked) to
## out_spines - the actual spine bar is drawn once for every lane by
## LaneSpines, not per-lane here, per §11's "one _draw() for all spines".
func _build_lane(fleet_ship: Dictionary, wolves: Array, tier: Dictionary, lane_width: float, geo: Dictionary, phase: String, out_spines: Array[Dictionary], lane_x: float) -> Control:
	var ordered := WolfLaneLayout.order_lane(wolves)
	var incoming_damage := WolfLaneLayout.incoming_damage_for_lane(ordered)
	var incoming_bp := WolfLaneLayout.incoming_bp_for_lane(ordered)
	var attacked := incoming_damage > 0 or incoming_bp > 0
	var ship_id: String = fleet_ship["id"]
	var color := WolfAttackTokens.ship_color(ship_id)

	var stack_zone_bottom: float = geo["impact_y"] - 16.0 - WolfAttackTokens.Y_STACK_ZONE_TOP
	var incoming_local_top: float = (geo["impact_y"] - WolfAttackTokens.Y_STACK_ZONE_TOP) + WolfAttackTokens.Y_INCOMING_LINE_OFFSET
	var card_local_top: float = geo["card_top"] - WolfAttackTokens.Y_STACK_ZONE_TOP
	var card_height: float = geo["card_height"]

	var outer := Control.new()
	outer.custom_minimum_size = Vector2(lane_width, LANE_HEIGHT)
	outer.clip_contents = false

	# Wash - binds the stack to its card without a line (§3).
	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = Vector2(lane_width, stack_zone_bottom)
	var wash_alpha := 0.02
	if phase != "targeting" and attacked:
		wash_alpha = 0.07
	wash.color = Color(color, wash_alpha)
	outer.add_child(wash)

	var wash_edge := ColorRect.new()
	wash_edge.position = Vector2.ZERO
	wash_edge.size = Vector2(lane_width, 2.0)
	wash_edge.color = Color(color, 0.5 if (phase != "targeting" and attacked) else 0.15)
	outer.add_child(wash_edge)

	# Stack - manual bottom-aligned layout, not a container (§11).
	var stack := Control.new()
	stack.position = Vector2.ZERO
	stack.size = Vector2(lane_width, stack_zone_bottom)
	outer.add_child(stack)
	_populate_stack(stack, ordered, tier, lane_width, stack_zone_bottom, phase)

	# Spine - collected for LaneSpines to draw in a single pass.
	if attacked:
		var spine_width: float = clampf(float(incoming_damage), 2.0, 10.0)
		out_spines.append({
			"x": lane_x + lane_width * 0.5,
			"width": spine_width,
			"top": WolfAttackTokens.Y_STACK_ZONE_TOP + stack_zone_bottom,
			"bottom": WolfAttackTokens.Y_STACK_ZONE_TOP + card_local_top + 6.0,
		})

	# Incoming line.
	var incoming_line := _build_incoming_line(attacked, phase, incoming_damage, incoming_bp)
	incoming_line.position = Vector2(0.0, incoming_local_top)
	outer.add_child(incoming_line)

	# Fleet card.
	var card := _build_fleet_card(fleet_ship, color, attacked, incoming_damage, incoming_bp, lane_width, card_height)
	card.position = Vector2(0.0, card_local_top)
	card.size = Vector2(lane_width, card_height)
	outer.add_child(card)

	return outer

## Fills Stack with tokens, bottom-up left-to-right (§5.1), reserving the
## last slot for a "+N MORE" overflow chip when the lane exceeds the
## tier's per-lane capacity.
func _populate_stack(stack: Control, ordered: Array, tier: Dictionary, lane_width: float, stack_zone_bottom: float, phase: String) -> void:
	var slots := WolfLaneLayout.lane_display_slots(ordered.size(), tier)
	var shown: int = slots["shown"]
	var overflow: int = slots["overflow"]
	var cols: int = tier["cols"]
	var height: float = tier["height"]
	var gap: float = tier["gap"]
	var content_level := WolfLaneLayout.compact_content_level(lane_width)
	var token_width := (lane_width - float(cols - 1) * gap) / float(cols)

	for k in shown:
		var wolf: Dictionary = ordered[k]
		var slot := WolfLaneLayout.stack_slot(k, cols)
		var wolf_class: String = wolf["class"]
		var wolf_destroyed: bool = wolf["destroyed"]
		var must_target_first: bool = phase == "range_short" and wolf_class == "fighter_wing" and not wolf_destroyed
		var token := _build_wolf_token(wolf, tier["form"], content_level, must_target_first, height)
		token.position = Vector2(float(slot.x) * (token_width + gap), stack_zone_bottom - float(slot.y + 1) * height - float(slot.y) * gap)
		token.size = Vector2(token_width, height)
		stack.add_child(token)

	if overflow > 0:
		var overflow_slot := WolfLaneLayout.stack_slot(shown, cols)
		var chip := _build_overflow_chip(overflow)
		chip.position = Vector2(0.0, stack_zone_bottom - float(overflow_slot.y + 1) * height - float(overflow_slot.y) * gap)
		chip.size = Vector2(lane_width, height)
		stack.add_child(chip)

func _build_overflow_chip(count: int) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WolfAttackTokens.ALERT, 0.1)
	style.border_color = Color(WolfAttackTokens.ALERT, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = WolfAttackTokens.fmt_display("+%d more" % count)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WolfAttackTokens.apply(label, "T_COMPACT_CODE")
	label.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
	chip.add_child(label)
	return chip

## One wolf token, full or compact form depending on the tier chosen for
## the whole attack (§4.1/§4.2). Destroyed state per §4.4, the user's
## chosen reading: the WHOLE token dims (modulate.a = 0.3), code in
## INK_GHOST, every pip hollow (WolfCodePips.destroyed), ability text
## replaced, plus a strikethrough - not the README's "keep full opacity,
## dim only the contents" alternative (see TODO.md).
##
## available_height is the actual pixel budget the token will be placed
## into (tier["height"]) - the full form needs it to size its icon
## correctly (see _build_full_token); the compact form ignores it, its
## single HBoxContainer row already fits comfortably in every tier's
## fixed height.
func _build_wolf_token(wolf: Dictionary, form: String, content_level: int, must_target_first: bool, available_height: float) -> Control:
	var destroyed: bool = wolf["destroyed"]
	var code: String = WolfShipDefinitions.CLASS_CODES.get(WolfShipDefinitions.Class[wolf["class"].to_upper()], "??")

	var content: Control
	if form == "full":
		content = _build_full_token(wolf, code, available_height)
	else:
		content = _build_compact_token(wolf, code, content_level, must_target_first)

	# content is a VBoxContainer/PanelContainer - adding the strikethrough
	# as ITS child would have the container lay it out as another row/
	# item instead of overlaying it. A plain Control holder lets both
	# content (anchored to fill) and the strikethrough overlay sit as
	# independent siblings on top of each other. clip_contents is a
	# defensive last resort, not the real fix (see _build_full_token) -
	# a real bug had ability text bleed down into the impact line/incoming
	# line below because the VBoxContainer's children's combined minimum
	# size exceeded the space this holder was actually given, and Godot
	# Controls don't clip their children by default.
	var holder := Control.new()
	holder.clip_contents = true
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	holder.add_child(content)

	if destroyed:
		holder.modulate.a = 0.3
		var strike := StrikeThrough.new()
		strike.anchor_right = 1.0
		strike.anchor_bottom = 1.0
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(strike)
	return holder

## Real bug fixed here (reported from a live screenshot, not caught by
## the earlier structural driving script - that script only checked
## token/lane counts, never each token's actual rendered layout): the
## icon/code-row/ability-text stack used fixed guessed heights (52 + 34 +
## an unmeasured Label) that summed to well over the tier's 100px slot,
## and VBoxContainer/Control don't clip children that exceed their
## parent's rect by default - the ability text (e.g. "PREVENTS 1") bled
## straight down through the impact arc and incoming-damage line below
## it. Fixed by measuring the code-row and ability rows from their real
## font metrics and giving the icon whatever's actually left, so the
## three rows are guaranteed to sum to exactly available_height - no
## guessed constant can silently stop fitting again. holder.clip_contents
## (see _build_wolf_token) is kept as a defensive backstop, not a
## substitute for this.
func _build_full_token(wolf: Dictionary, code: String, available_height: float) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	var gap := 4.0
	column.add_theme_constant_override("separation", int(gap))

	# code_pips is a bare Control (WolfCodePips) with no intrinsic minimum
	# size - unlike the ability Label below, it never enforces a real
	# metric-driven height on its own, so a tight fixed multiple of the
	# font size (comfortably covers baseline + descenders + pip circles,
	# per WolfCodePips._draw()'s own offsets) is enough room and leaves
	# more of the budget for the icon than the font's full technical
	# line-height (ascent+descent+line-gap) would.
	var code_row_height := WolfAttackTokens.font_size("T_WOLF_CODE") * 1.05
	# The ability Label DOES enforce its own real font-metric minimum
	# size regardless of what's requested here, so this has to match
	# that real metric or the label wins the size fight and overflows
	# again.
	var ability_row_height := WolfAttackTokens.font("T_WOLF_ABILITY").get_height(WolfAttackTokens.font_size("T_WOLF_ABILITY"))
	var icon_height := maxf(available_height - gap * 2.0 - code_row_height - ability_row_height, 18.0)

	var icon := ShipIcon.new()
	icon.icon_id = wolf["class"]
	icon.icon_color = WolfAttackTokens.INK_GHOST if wolf["destroyed"] else WolfAttackTokens.INK
	icon.custom_minimum_size = Vector2(0, icon_height)
	icon.size_flags_horizontal = SIZE_EXPAND_FILL
	column.add_child(icon)

	var code_pips := WolfCodePips.new()
	code_pips.code_text = code
	code_pips.capacity = wolf["capacity"]
	code_pips.damage_taken = wolf["damage_taken"]
	code_pips.show_returns = wolf["returns_if_survives"]
	code_pips.destroyed = wolf["destroyed"]
	code_pips.custom_minimum_size = Vector2(0, code_row_height)
	column.add_child(code_pips)

	var ability := Label.new()
	ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability.clip_text = true
	ability.text = WolfAttackTokens.fmt_display(WolfLaneLayout.ability_label_full(wolf))
	WolfAttackTokens.apply(ability, "T_WOLF_ABILITY")
	ability.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST if wolf["destroyed"] else WolfAttackTokens.ALERT)
	column.add_child(ability)

	return column

func _build_compact_token(wolf: Dictionary, code: String, content_level: int, must_target_first: bool) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WolfAttackTokens.CARD_BG, 0.86)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_RIGHT, 8)
	if must_target_first:
		style.set_border_width(SIDE_LEFT, 2)
		style.border_color = WolfAttackTokens.CYAN
	else:
		style.set_border_width_all(1)
		style.border_color = WolfAttackTokens.RULE
	row.add_theme_stylebox_override("panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(content)

	if content_level == 0:
		var icon := ShipIcon.new()
		icon.icon_id = wolf["class"]
		icon.icon_color = WolfAttackTokens.INK_GHOST if wolf["destroyed"] else WolfAttackTokens.INK
		icon.custom_minimum_size = Vector2(28, 0)
		content.add_child(icon)

	if content_level < 3:
		var code_pips := WolfCodePips.new()
		code_pips.code_text = code
		code_pips.capacity = wolf["capacity"]
		code_pips.damage_taken = wolf["damage_taken"]
		code_pips.show_returns = wolf["returns_if_survives"]
		code_pips.destroyed = wolf["destroyed"]
		code_pips.font_token = "T_COMPACT_CODE"
		code_pips.pip_radius = 3.5
		code_pips.pip_gap = 9.0
		code_pips.custom_minimum_size = Vector2(0, 0)
		code_pips.size_flags_horizontal = SIZE_EXPAND_FILL
		content.add_child(code_pips)
	else:
		var numeric := Label.new()
		numeric.text = "%s %d/%d" % [code, wolf["capacity"] - wolf["damage_taken"], wolf["capacity"]]
		WolfAttackTokens.apply(numeric, "T_COMPACT_CODE")
		numeric.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST if wolf["destroyed"] else WolfAttackTokens.INK)
		numeric.size_flags_horizontal = SIZE_EXPAND_FILL
		content.add_child(numeric)

	if content_level <= 1:
		var ability := Label.new()
		ability.text = WolfAttackTokens.fmt_display(WolfLaneLayout.ability_abbrev(wolf))
		ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		WolfAttackTokens.apply(ability, "T_COMPACT_ABILITY")
		ability.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST if wolf["destroyed"] else WolfAttackTokens.ALERT)
		content.add_child(ability)

	return row

func _build_incoming_line(attacked: bool, phase: String, incoming_damage: int, incoming_bp: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	if phase == "targeting" and not attacked:
		var dash := Label.new()
		dash.text = "—"
		WolfAttackTokens.apply(dash, "T_DMG_SUFFIX")
		dash.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		row.add_child(dash)
		var waiting := Label.new()
		waiting.text = WolfAttackTokens.fmt_display("Awaiting targets")
		WolfAttackTokens.apply(waiting, "T_DMG_SUFFIX")
		waiting.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		row.add_child(waiting)
		return row

	if not attacked:
		var dash := Label.new()
		dash.text = "·"
		WolfAttackTokens.apply(dash, "T_DMG_SUFFIX")
		dash.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		row.add_child(dash)
		var no_contact := Label.new()
		no_contact.text = WolfAttackTokens.fmt_display("No contact")
		WolfAttackTokens.apply(no_contact, "T_DMG_SUFFIX")
		no_contact.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		row.add_child(no_contact)
		return row

	var marker := Label.new()
	marker.text = "▼"
	WolfAttackTokens.apply(marker, "T_DMG_SUFFIX")
	marker.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
	row.add_child(marker)

	var number := Label.new()
	number.text = str(incoming_damage)
	WolfAttackTokens.apply(number, "T_INCOMING_NUM")
	number.add_theme_color_override("font_color", WolfAttackTokens.ALERT)
	row.add_child(number)

	var suffix := Label.new()
	suffix.text = "DMG"
	WolfAttackTokens.apply(suffix, "T_DMG_SUFFIX")
	suffix.add_theme_color_override("font_color", Color(WolfAttackTokens.ALERT, 0.8))
	row.add_child(suffix)

	if incoming_bp > 0:
		var dot := Label.new()
		dot.text = "·"
		WolfAttackTokens.apply(dot, "T_DMG_SUFFIX")
		dot.add_theme_color_override("font_color", WolfAttackTokens.INK_GHOST)
		row.add_child(dot)
		row.add_child(_make_chip("%d BP" % incoming_bp, WolfAttackTokens.ALERT_DEEP, WolfAttackTokens.INK, true))

	return row

## Fixed-height card, dark translucent backing, 4px signature-color bar,
## SEC moved inside the card's top-right corner (§7 - v2 had it above
## the card; the space above is now the spine's entry point), no
## attacker-chip row (deleted per §7 - the stack above the card is that
## list now). N BP stays (boarding is its own resolution step).
func _build_fleet_card(fleet_ship: Dictionary, color: Color, targeted: bool, incoming: int, boarders: int, lane_width: float, card_height: float) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(18)
	style.set_border_width_all(2 if targeted else 1)
	style.border_color = WolfAttackTokens.ALERT if targeted else WolfAttackTokens.RULE
	style.bg_color = WolfAttackTokens.CARD_BG_TARGETED if targeted else WolfAttackTokens.CARD_BG
	if targeted:
		style.shadow_color = Color(WolfAttackTokens.ALERT, 0.25)
		style.shadow_size = 14
	box.add_theme_stylebox_override("panel", style)
	if fleet_ship["critical"]:
		box.modulate = Color(1.0, 0.6, 0.6)

	var column := VBoxContainer.new()
	box.add_child(column)

	var top_bar := ColorRect.new()
	top_bar.color = color
	top_bar.custom_minimum_size = Vector2(0, 4)
	column.add_child(top_bar)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var index_label := Label.new()
	var index: Variant = WolfShipDefinitions.TARGETING_TABLE.find_key(fleet_ship["id"])
	index_label.text = str(index) if index != null else "?"
	index_label.size_flags_horizontal = SIZE_EXPAND_FILL
	WolfAttackTokens.apply(index_label, "T_CARD_INDEX")
	index_label.add_theme_color_override("font_color", color if targeted else Color(color, 0.55))
	header_row.add_child(index_label)

	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_BEGIN
	var sec_label := Label.new()
	sec_label.text = "SEC %d" % fleet_ship["security_teams"]
	sec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	WolfAttackTokens.apply(sec_label, "T_SEC")
	sec_label.add_theme_color_override("font_color", color)
	side.add_child(sec_label)
	var icon := ShipIcon.new()
	icon.icon_id = fleet_ship["id"]
	icon.icon_color = color
	icon.modulate.a = 0.9 if targeted else 0.45
	icon.custom_minimum_size = Vector2(90, 34)
	side.add_child(icon)
	header_row.add_child(side)
	column.add_child(header_row)

	var name_label := Label.new()
	name_label.text = WolfAttackTokens.fmt_display(ShipRegistry.display_name(fleet_ship["id"]))
	WolfAttackTokens.apply(name_label, "T_CARD_NAME")
	name_label.add_theme_color_override("font_color", WolfAttackTokens.INK if targeted else WolfAttackTokens.INK_DIM)
	column.add_child(name_label)

	var damage_row := HBoxContainer.new()
	damage_row.add_theme_constant_override("separation", 4)
	var damage_this_attack: int = fleet_ship["damage_this_attack"]
	var dmg_marker := Label.new()
	dmg_marker.text = "DAMAGE"
	WolfAttackTokens.apply(dmg_marker, "T_DMG_SUFFIX")
	dmg_marker.add_theme_color_override("font_color", Color(WolfAttackTokens.INK_DIM, 0.6))
	damage_row.add_child(dmg_marker)
	var dmg_label := Label.new()
	dmg_label.text = str(damage_this_attack)
	WolfAttackTokens.apply(dmg_label, "T_DMG_NUM")
	dmg_label.add_theme_color_override("font_color", WolfAttackTokens.ALERT if damage_this_attack > 0 else WolfAttackTokens.INK_GHOST)
	damage_row.add_child(dmg_label)
	var sec_suffix := Label.new()
	sec_suffix.text = "/ SEC"
	WolfAttackTokens.apply(sec_suffix, "T_DMG_SUFFIX")
	sec_suffix.add_theme_color_override("font_color", Color(WolfAttackTokens.INK_DIM, 0.5))
	damage_row.add_child(sec_suffix)
	column.add_child(damage_row)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(WolfAttackTokens.INK_DIM, 0.16)
	bar_bg.custom_minimum_size = Vector2(0, 6)
	var security: int = maxi(fleet_ship["security_teams"], 1)
	var fill_ratio: float = clampf(float(damage_this_attack) / float(security), 0.0, 1.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = WolfAttackTokens.ALERT if fill_ratio > 0.6 else Color(color, 0.8)
	bar_fill.anchor_right = fill_ratio
	bar_fill.anchor_bottom = 1.0
	bar_bg.add_child(bar_fill)
	column.add_child(bar_bg)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(spacer)

	if boarders > 0:
		var bp_row := HBoxContainer.new()
		bp_row.add_child(_make_chip("%d BP INBOUND" % boarders, WolfAttackTokens.ALERT_DEEP, WolfAttackTokens.INK, true))
		column.add_child(bp_row)

	return box

## A small bordered tag chip. filled draws a solid ALERT_DEEP background
## (the "N BP" marker); otherwise just an outline.
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

## §6.1's staging pool - see this file's header comment on why it will
## not actually render anything in real play with this project's current
## WolfAttack targeting mechanics, and why the render path is still built
## correctly regardless.
func _refresh_staging_pool(untargeted: Array, tier: Dictionary, phase: String) -> void:
	var show := phase == "targeting" and not untargeted.is_empty()
	_staging_pool.visible = show
	for child in _staging_pool_flow.get_children():
		child.free()
	if not show:
		return
	_staging_pool_label.text = WolfAttackTokens.fmt_display("Staging Pool — Assigning Targets")
	WolfAttackTokens.apply(_staging_pool_label, "T_FOOTER_LABEL")
	_staging_pool_label.add_theme_color_override("font_color", WolfAttackTokens.CYAN)
	for wolf: Dictionary in WolfLaneLayout.order_lane(untargeted):
		var token := _build_wolf_token(wolf, "compact", 0, false, 34.0)
		token.custom_minimum_size = Vector2(214, 34)
		_staging_pool_flow.add_child(token)

## The fleet's own combat craft the Wolves can't target - short names,
## cyan triangles, optional numeric value.
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
