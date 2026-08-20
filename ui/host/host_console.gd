class_name HostConsole
extends Control

## Host admin console. Every rule the engine enforces needs a bypass
## path here - real games go off-script and the host adjudicates.
## See CLAUDE.md constraint 5. Unlike TVDisplay, this scene is allowed
## to mutate core/ state directly, via the same host-override entry
## points core/ already exposes (PursuitTrack.set_value,
## TurnManager.force_set, Ship/Console/CraftState setters) rather than
## through net/'s MessageRouter.
##
## Ship/craft panels are built once, not torn down and rebuilt on every
## GameState.mutated - with ~180+ editable fields across 6 ships and 17
## craft, and GameState.mutated now firing on every real mutation
## (jump coordinates, resources, console state, ...), a full rebuild-
## on-mutate would blow away whatever the host is mid-typing every time
## any player anywhere sends a message. Instead, each field's control
## is created once and refreshed from live state only when its panel is
## expanded (or via the top "Refresh" button) - a deliberate host
## action, not a background event.

## Minimal reachable trigger for the Star Map TV screen (docs/
## star_map_tv_display.md §8's "Show / hide map" - the rest of §8's
## admin console, move unit/claims/representative/etc., is still
## unbuilt; see TODO.md). ui/main.gd owns the actual show/hide policy
## (never during a Wolf Attack) - this just asks for it.
signal star_map_toggle_pressed()

@onready var _turn_label: Label = %TurnLabel
@onready var _advance_button: Button = %AdvanceButton
@onready var _toggle_star_map_button: Button = %ToggleStarMapButton
@onready var _pursuit_label: Label = %PursuitLabel
@onready var _pursuit_override: SpinBox = %PursuitOverride
@onready var _force_pursuit_button: Button = %ForcePursuitButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _ship_list: VBoxContainer = %ShipList
@onready var _craft_list: VBoxContainer = %CraftList
@onready var _players_list: VBoxContainer = %PlayersList
@onready var _new_player_name: LineEdit = %NewPlayerName
@onready var _add_player_button: Button = %AddPlayerButton
@onready var _wolf_attack_section: VBoxContainer = %WolfAttackSection
@onready var _star_map_section: VBoxContainer = %StarMapSection
@onready var _dice_log_section: VBoxContainer = %DiceLogSection

var game_state: GameState
var _all_refreshers: Array[Callable] = []

const RESOURCE_KINDS: Array[ResourceStock.Kind] = [
	ResourceStock.Kind.STRYTIUM_ORE, ResourceStock.Kind.STRYTIUM_FUEL,
	ResourceStock.Kind.FOOD, ResourceStock.Kind.WATER,
	ResourceStock.Kind.MATERIALS, ResourceStock.Kind.SECURITY_TEAMS,
]
const CONSOLE_STATE_NAMES: Array[String] = ["OK", "DAMAGED", "DESTROYED"]

## Mirrors ui/main.gd's HTTP_LISTEN_PORT - keep these two in sync. Used
## only to build a copy-pasteable URL for each player's phone page; the
## host still has to point ESP32s/browsers at whatever address this
## laptop actually gets on the venue's router (see TODO.md's Deployment
## item - IP discovery is still an open decision).
const HTTP_LISTEN_PORT_FOR_URLS := 8080

func set_game_state(state: GameState) -> void:
	game_state = state
	game_state.turn_manager.phase_changed.connect(_refresh)
	game_state.pursuit_track.changed.connect(_refresh)

	_pursuit_override.min_value = PursuitTrack.MIN_VALUE
	_pursuit_override.max_value = PursuitTrack.MAX_VALUE
	_advance_button.pressed.connect(_on_advance_pressed)
	_toggle_star_map_button.pressed.connect(func() -> void: star_map_toggle_pressed.emit())
	_force_pursuit_button.pressed.connect(_on_force_pursuit_pressed)
	_refresh_button.pressed.connect(_on_refresh_all_pressed)

	_add_player_button.pressed.connect(_on_add_player_pressed)
	# CONNECT_DEFERRED: _rebuild_wolf_attack_section() frees nodes,
	# including whichever button's own pressed handler is what
	# triggered this mutation - freeing a node while it's still inside
	# its own signal emission crashes ("Object is locked and can't be
	# freed"). Deferring runs the rebuild after that call stack has
	# fully unwound instead.
	game_state.mutated.connect(_rebuild_wolf_attack_section, CONNECT_DEFERRED)
	# Same CONNECT_DEFERRED reasoning as the Wolf Attack section above -
	# the section rebuilds unconditionally on every mutation (it's all
	# taps/dropdowns/short entries, same tradeoff Wolf Attack's section
	# already makes; unlike the ship/craft panels there's no 180-field
	# surface here where a background mutation mid-edit would be costly),
	# and some of its own buttons (Retract, per-group Set) live inside
	# the very subtree being freed.
	game_state.mutated.connect(_rebuild_star_map_section, CONNECT_DEFERRED)
	# Same CONNECT_DEFERRED/full-rebuild tradeoff as Wolf Attack/Star Map
	# above - rolls arrive as an event stream (every maintenance/combat
	# roll, from any source), not something the host is mid-typing into,
	# so there's nothing here a background rebuild could interrupt.
	game_state.mutated.connect(_rebuild_dice_log_section, CONNECT_DEFERRED)

	_refresh()
	_build_ship_panels()
	_build_craft_panels()
	_build_player_panels()
	_rebuild_wolf_attack_section()
	_rebuild_star_map_section()
	_rebuild_dice_log_section()

func _on_advance_pressed() -> void:
	game_state.turn_manager.advance()

func _on_force_pursuit_pressed() -> void:
	game_state.pursuit_track.set_value(int(_pursuit_override.value))

func _on_refresh_all_pressed() -> void:
	for refresh in _all_refreshers:
		refresh.call()

func _on_add_player_pressed() -> void:
	var player_name := _new_player_name.text.strip_edges()
	if player_name.is_empty():
		return
	var player := Player.new(game_state.generate_player_id(), player_name)
	game_state.add_player(player)
	_new_player_name.text = ""
	_build_player_panel(player, true)

func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	_turn_label.text = DisplayFormat.turn_label(game_state.turn_manager)
	_pursuit_label.text = DisplayFormat.pursuit_bar(game_state.pursuit_track)

## --- generic row builders -------------------------------------------
## Each takes the panel's shared `refreshers` array and appends a
## closure that re-reads get_value() into the control it built, so the
## panel can re-sync its displayed values on expand without rebuilding
## any nodes.

func _make_line_edit_row(refreshers: Array[Callable], label_text: String, get_value: Callable, on_apply: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = get_value.call()
	edit.custom_minimum_size = Vector2(220, 0)
	row.add_child(edit)
	var button := Button.new()
	button.text = "Set"
	button.pressed.connect(func() -> void: on_apply.call(edit.text))
	row.add_child(button)
	refreshers.append(func() -> void: edit.text = get_value.call())
	return row

func _make_toggle_row(refreshers: Array[Callable], label_text: String, get_value: Callable, on_toggle: Callable) -> Control:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = get_value.call()
	check.toggled.connect(on_toggle)
	refreshers.append(func() -> void: check.button_pressed = get_value.call())
	return check

func _make_spinbox_row(refreshers: Array[Callable], label_text: String, get_value: Callable, min_value: float, max_value: float, on_apply: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = get_value.call()
	row.add_child(spin)
	var button := Button.new()
	button.text = "Set"
	button.pressed.connect(func() -> void: on_apply.call(int(spin.value)))
	row.add_child(button)
	refreshers.append(func() -> void: spin.value = get_value.call())
	return row

func _make_option_row(refreshers: Array[Callable], label_text: String, options: Array[String], get_index: Callable, on_select: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var option := OptionButton.new()
	for text in options:
		option.add_item(text)
	option.selected = get_index.call()
	option.item_selected.connect(on_select)
	row.add_child(option)
	refreshers.append(func() -> void: option.selected = get_index.call())
	return row

## A collapsible header/body pair. body starts hidden unless
## start_expanded is set (used when the host just created something and
## almost certainly wants to fill it in immediately - see
## _on_add_player_pressed()). Expanding it refreshes every field in the
## panel from live state. Returns the body container so callers can add
## rows to it.
func _make_collapsible_panel(parent: VBoxContainer, title: String, refreshers: Array[Callable], start_expanded: bool = false) -> VBoxContainer:
	var container := VBoxContainer.new()
	var header := Button.new()
	header.toggle_mode = true
	header.text = "▸ %s" % title
	var body := VBoxContainer.new()
	body.visible = false
	header.toggled.connect(func(pressed: bool) -> void:
		body.visible = pressed
		header.text = "%s %s" % ["▾" if pressed else "▸", title]
		if pressed:
			for refresh in refreshers:
				refresh.call()
	)
	container.add_child(header)
	container.add_child(body)
	parent.add_child(container)
	if start_expanded:
		header.button_pressed = true
		header.toggled.emit(true)
	return body

## --- ship panels ------------------------------------------------------

func _build_ship_panels() -> void:
	for ship_id: String in game_state.ships:
		_build_ship_panel(game_state.ships[ship_id])

func _build_ship_panel(ship: Ship) -> void:
	var refreshers: Array[Callable] = []
	var body := _make_collapsible_panel(_ship_list, ShipRegistry.display_name(ship.id), refreshers)

	body.add_child(_make_line_edit_row(refreshers, "Jump coordinates", func() -> String: return ship.jump_coordinates, func(text: String) -> void: ship.set_jump_coordinates(text)))
	body.add_child(_make_toggle_row(refreshers, "Drive charged", func() -> bool: return ship.drive_charged, func(pressed: bool) -> void: ship.set_drive_charged(pressed)))
	body.add_child(_make_spinbox_row(refreshers, "Unrest", func() -> float: return ship.unrest, 0, 99, func(value: int) -> void: ship.set_unrest(value)))
	body.add_child(_make_spinbox_row(refreshers, "Survivor population", func() -> float: return ship.survivor_population, 0, 200000, func(value: int) -> void: ship.survivor_population = value))

	var resources_label := Label.new()
	resources_label.text = "Resources"
	body.add_child(resources_label)
	for kind: ResourceStock.Kind in RESOURCE_KINDS:
		body.add_child(_make_spinbox_row(refreshers, ResourceStock.Kind.keys()[kind], func() -> float: return ship.resources.get_amount(kind), 0, 999, func(value: int) -> void: ship.resources.set_amount(kind, value)))

	var consoles_label := Label.new()
	consoles_label.text = "Consoles"
	body.add_child(consoles_label)
	for console_id: String in ship.consoles:
		var console := ship.consoles[console_id]
		body.add_child(_make_option_row(refreshers, console_id, CONSOLE_STATE_NAMES, func() -> int: return console.state, func(index: int) -> void: console.set_state(index as Console.State)))
		body.add_child(_make_toggle_row(refreshers, "  charged", func() -> bool: return console.charged, func(pressed: bool) -> void: console.set_charged(pressed)))
		body.add_child(_make_spinbox_row(refreshers, "  upgrade level", func() -> float: return console.upgrade_level, 0, 10, func(value: int) -> void: console.upgrade_level = value))

	body.add_child(_build_maintenance_cycle_section(ship, refreshers))

	_all_refreshers.append_array(refreshers)

## --- Maintenance Cycle (Team Phase step sequence) --------------------
## Each ship's table works through these at its own pace - see
## MaintenanceCycle's own file comment. Steps 1/3/4 are dice/arithmetic
## and get "run it" buttons; step 2 is a player choice of ration level
## with a spend button; step 5 (Reactor) and steps 6/7 (Shuttle Bay)
## reuse controls that already exist elsewhere in this panel (the
## per-console "charged" toggle above, and craft docking/fuel in the
## Craft section) rather than duplicating them - this section just adds
## the cap/count reference numbers and the fuel-spending refuel action,
## plus a checklist so a table doesn't lose track of where it is.

const RATION_LEVEL_LABELS: Array[String] = ["None", "Minimal", "Short", "Normal"]

func _build_maintenance_cycle_section(ship: Ship, refreshers: Array[Callable]) -> Control:
	var section := VBoxContainer.new()
	var label := Label.new()
	label.text = "Maintenance Cycle"
	section.add_child(label)

	var checklist_label := Label.new()
	section.add_child(checklist_label)
	var refresh_checklist := func() -> void:
		var parts: Array[String] = []
		for step: MaintenanceCycle.Step in MaintenanceCycle.steps_for(ship.id):
			var mark := "x" if ship.is_maintenance_step_complete(step) else " "
			parts.append("[%s] %s" % [mark, MaintenanceCycle.STEP_LABELS[step]])
		checklist_label.text = "  ".join(parts)
	refreshers.append(refresh_checklist)
	refresh_checklist.call()

	# Step 1: Storage.
	section.add_child(_make_action_row("Run Storage step (halves resources if damaged)", func() -> String:
		MaintenanceCycle.apply_storage_step(game_state, ship.id)
		ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
		refresh_checklist.call()
		return "done"
	))

	# Step 2: Rations. Bonus is held here (this closure's own scope) so
	# step 3's button below can read whatever step 2 last produced.
	var ration_bonus := [0]
	var food_option := OptionButton.new()
	var water_option := OptionButton.new()
	for level_label in RATION_LEVEL_LABELS:
		food_option.add_item(level_label)
		water_option.add_item(level_label)
	var ration_row := HBoxContainer.new()
	var food_label := Label.new()
	food_label.text = "Food"
	var water_label := Label.new()
	water_label.text = "Water"
	ration_row.add_child(food_label)
	ration_row.add_child(food_option)
	ration_row.add_child(water_label)
	ration_row.add_child(water_option)
	section.add_child(ration_row)
	section.add_child(_make_action_row("Spend rations", func() -> String:
		ration_bonus[0] = MaintenanceCycle.spend_rations(game_state, ship.id, food_option.selected, water_option.selected)
		ship.mark_maintenance_step_complete(MaintenanceCycle.Step.RATIONS)
		refresh_checklist.call()
		return "bonus %d" % ration_bonus[0]
	))

	# Step 3: unrest roll, using whatever ration_bonus step 2 last set
	# (0 if step 2 hasn't run yet this turn).
	section.add_child(_make_action_row("Roll unrest (2d6 + ration bonus)", func() -> String:
		var result := MaintenanceCycle.roll_unrest_gain(game_state, ship.id, ration_bonus[0])
		ship.mark_maintenance_step_complete(MaintenanceCycle.Step.UNREST_ROLL)
		refresh_checklist.call()
		var faces: PackedInt32Array = result["faces"]
		return "rolled %d + %d + %d rations = %d -> +%d unrest" % [faces[0], faces[1], result["modifier"], result["total"], result["unrest_gain"]]
	))

	# Step 4: riot roll. Which console takes the damage is drawn from
	# the ship's physical damage deck, not decided here - the host
	# marks it via the console rows above once this reports a hit.
	section.add_child(_make_action_row("Roll riot check (1d6 vs current unrest)", func() -> String:
		var result := MaintenanceCycle.roll_riot_damage(game_state, ship.id)
		ship.mark_maintenance_step_complete(MaintenanceCycle.Step.RIOT_ROLL)
		refresh_checklist.call()
		if result["damaged"]:
			return "rolled %d < %d unrest - HIT: draw a card and mark that console damaged above" % [result["roll"], result["unrest"]]
		return "rolled %d >= %d unrest - no damage" % [result["roll"], result["unrest"]]
	))

	# Step 5: Reactor. Charging specific consoles is done via the
	# per-console "charged" toggles above; this is just the reference
	# numbers plus a checklist mark.
	var reactor_label := Label.new()
	section.add_child(reactor_label)
	refreshers.append(func() -> void:
		reactor_label.text = "Reactor: %d / %d consoles charged" % [MaintenanceCycle.charged_console_count(ship), MaintenanceCycle.reactor_charge_cap(ship)]
	)
	section.add_child(_make_action_row("Mark Reactor step complete", func() -> String:
		ship.mark_maintenance_step_complete(MaintenanceCycle.Step.REACTOR)
		refresh_checklist.call()
		return "done"
	))

	# Steps 6/7: Shuttle Bay refuel(s). AEGIS gets a 7th step (Omega) -
	# see MaintenanceCycle.steps_for().
	for step: MaintenanceCycle.Step in MaintenanceCycle.steps_for(ship.id):
		if step != MaintenanceCycle.Step.SHUTTLE_BAY and step != MaintenanceCycle.Step.SHUTTLE_BAY_OMEGA:
			continue
		var bay_console_id := MaintenanceCycle.SHUTTLE_BAY_OMEGA_CONSOLE_ID if step == MaintenanceCycle.Step.SHUTTLE_BAY_OMEGA else MaintenanceCycle.shuttle_bay_console_id(ship.id)
		var craft_option := OptionButton.new()
		var docked_craft_ids: Array[String] = []
		for craft_id: String in game_state.craft:
			if game_state.craft[craft_id].docked_ship_id == ship.id:
				docked_craft_ids.append(craft_id)
				craft_option.add_item(craft_id)
		section.add_child(craft_option)
		var step_ref := step
		section.add_child(_make_action_row("Refuel via %s (1 strytium fuel)" % bay_console_id, func() -> String:
			if craft_option.selected < 0 or craft_option.selected >= docked_craft_ids.size():
				return "no docked craft selected"
			var craft_id := docked_craft_ids[craft_option.selected]
			var refueled := MaintenanceCycle.refuel_shuttle(game_state, ship.id, craft_id, bay_console_id)
			if refueled:
				ship.mark_maintenance_step_complete(step_ref)
				refresh_checklist.call()
				return "refuelled %s" % craft_id
			return "failed - check fuel and bay damage"
		))

	return section

## A one-shot action button plus a result label - unlike the row
## builders above, there's no persistent value to keep synced before
## the button is pressed, so this isn't part of the refresh-on-expand
## machinery. on_press returns the text to show as the result.
func _make_action_row(button_text: String, on_press: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var button := Button.new()
	button.text = button_text
	var result_label := Label.new()
	row.add_child(button)
	row.add_child(result_label)
	button.pressed.connect(func() -> void: result_label.text = String(on_press.call()))
	return row

## --- craft panels -----------------------------------------------------

func _build_craft_panels() -> void:
	for craft_id: String in game_state.craft:
		_build_craft_panel(game_state.craft[craft_id])

func _build_craft_panel(craft_state: CraftState) -> void:
	var refreshers: Array[Callable] = []
	var definition := CraftDefinitions.get_definition(craft_state.id)
	var title := definition.display_name if definition != null else craft_state.id
	var body := _make_collapsible_panel(_craft_list, title, refreshers)

	var ship_ids := ShipRegistry.all_ship_ids()
	var ship_display_names: Array[String] = []
	for ship_id: String in ship_ids:
		ship_display_names.append(ShipRegistry.display_name(ship_id))
	body.add_child(_make_option_row(refreshers, "Docked at", ship_display_names, func() -> int: return maxi(ship_ids.find(craft_state.docked_ship_id), 0), func(index: int) -> void: craft_state.set_docked_ship(ship_ids[index])))
	body.add_child(_make_toggle_row(refreshers, "Fuelled", func() -> bool: return craft_state.fuelled, func(pressed: bool) -> void: craft_state.set_fuelled(pressed)))
	body.add_child(_make_spinbox_row(refreshers, "Combat damage", func() -> float: return craft_state.combat_damage, 0, 99, func(value: int) -> void: craft_state.set_combat_damage(value)))
	body.add_child(_make_spinbox_row(refreshers, "Fighter count", func() -> float: return craft_state.fighter_count, 0, 99, func(value: int) -> void: craft_state.set_fighter_count(value)))
	body.add_child(_make_line_edit_row(refreshers, "Scout report", func() -> String: return craft_state.scout_report, func(text: String) -> void: craft_state.set_scout_report(text)))

	var cargo_label := Label.new()
	cargo_label.text = "Cargo"
	body.add_child(cargo_label)
	for kind: ResourceStock.Kind in RESOURCE_KINDS:
		body.add_child(_make_spinbox_row(refreshers, ResourceStock.Kind.keys()[kind], func() -> float: return craft_state.cargo.get_amount(kind), 0, 999, func(value: int) -> void: craft_state.cargo.set_amount(kind, value)))

	_all_refreshers.append_array(refreshers)

## --- player panels ------------------------------------------------------
## Loyalty stays on paper (CLAUDE.md constraint 4) - this only tracks
## what open_questions_answered.md §4.5 says a phone page carries:
## suspicion and facilitator-issued clues. The arrest posse-size
## calculator lives here, host-only, because FG is explicit that
## players are told the number required and never the suspicion value
## it's derived from (§4.3) - it must never reach a player's phone.

func _build_player_panels() -> void:
	for player_id: String in game_state.players:
		_build_player_panel(game_state.players[player_id])

func _build_player_panel(player: Player, start_expanded: bool = false) -> void:
	var refreshers: Array[Callable] = []
	var body := _make_collapsible_panel(_players_list, player.name, refreshers, start_expanded)

	body.add_child(_make_spinbox_row(refreshers, "Suspicion", func() -> float: return player.suspicion, 0, 999, func(value: int) -> void: player.set_suspicion(value)))

	var roll_row := HBoxContainer.new()
	var roll_button := Button.new()
	roll_button.text = "Roll 1d6 (clue table check)"
	var roll_result := Label.new()
	roll_result.text = ""
	roll_row.add_child(roll_button)
	roll_row.add_child(roll_result)
	body.add_child(roll_row)

	var posse_row := HBoxContainer.new()
	var posse_label := Label.new()
	posse_label.text = "Standers (players who stand up for them)"
	posse_label.custom_minimum_size = Vector2(260, 0)
	var posse_standers := SpinBox.new()
	posse_standers.min_value = 0
	posse_standers.max_value = 20
	var posse_button := Button.new()
	posse_button.text = "Calculate posse size (host only - never send to a player)"
	var posse_result := Label.new()
	posse_result.text = ""
	posse_row.add_child(posse_label)
	posse_row.add_child(posse_standers)
	posse_row.add_child(posse_button)
	posse_row.add_child(posse_result)
	body.add_child(posse_row)
	posse_button.pressed.connect(func() -> void:
		posse_result.text = "Required: %d" % Player.posse_size_required(player.suspicion, int(posse_standers.value))
	)
	# Rolling changes suspicion, so the calculator's implicit dependency
	# on player.suspicion can go stale the moment a roll lands - clear
	# the last result rather than show a number that no longer matches.
	roll_button.pressed.connect(func() -> void:
		var roll := game_state.rng.randi_range(1, 6)
		player.add_suspicion(roll)
		roll_result.text = "Rolled %d - new suspicion %d" % [roll, player.suspicion]
		posse_result.text = ""
	)

	var clues_label := Label.new()
	clues_label.text = "Clues sent"
	body.add_child(clues_label)
	var clues_list := VBoxContainer.new()
	body.add_child(clues_list)
	var refresh_clues := func() -> void:
		for child in clues_list.get_children():
			child.free()
		for clue: Dictionary in player.clues:
			var clue_label := Label.new()
			clue_label.text = "Turn %d: %s" % [clue.get("turn_number", 0), clue.get("text", "")]
			clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			clues_list.add_child(clue_label)
	refreshers.append(refresh_clues)
	refresh_clues.call()

	var send_clue_row := HBoxContainer.new()
	var clue_edit := LineEdit.new()
	clue_edit.placeholder_text = "Clue text, sent to this player's phone verbatim"
	clue_edit.custom_minimum_size = Vector2(320, 0)
	var send_clue_button := Button.new()
	send_clue_button.text = "Send Clue"
	send_clue_row.add_child(clue_edit)
	send_clue_row.add_child(send_clue_button)
	body.add_child(send_clue_row)
	send_clue_button.pressed.connect(func() -> void:
		if clue_edit.text.strip_edges().is_empty():
			return
		player.add_clue(clue_edit.text, game_state.turn_manager.turn_number)
		clue_edit.text = ""
		refresh_clues.call()
	)

	var url_row := HBoxContainer.new()
	var url_label := Label.new()
	url_label.text = "Phone page"
	url_label.custom_minimum_size = Vector2(180, 0)
	var url_field := LineEdit.new()
	url_field.editable = false
	url_field.text = DisplayFormat.player_phone_url(_best_guess_local_ip(), HTTP_LISTEN_PORT_FOR_URLS, player.id)
	url_field.custom_minimum_size = Vector2(360, 0)
	url_row.add_child(url_label)
	url_row.add_child(url_field)
	body.add_child(url_row)

	_all_refreshers.append_array(refreshers)

## Best-effort LAN address for the URL shown above - not a claim about
## which address ESP32s/browsers should actually use (see TODO.md's
## Deployment item; IP discovery is still an open decision). Falls back
## to a placeholder if nothing better is found, e.g. running with no
## network adapter up.
func _best_guess_local_ip() -> String:
	for address: String in IP.get_local_addresses():
		if address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0" or address.find(":") != -1:
			continue  # loopback, link-local/APIPA (no real network), or IPv6
		return address
	return "<host-ip>"

## --- Wolf Attack --------------------------------------------------------
## Unlike ships/craft/players, this section rebuilds on every
## GameState.mutated rather than refresh-on-expand - it's almost
## entirely taps and spinbox+Set rows the host uses in the moment
## during a live attack, not free text fields that could lose in-
## progress typing, so the "don't disrupt the host mid-edit" concern
## that drove the other panels' design doesn't apply here. See
## TVDisplay for the same reasoning applied to a fully read-only view.
##
## CLAUDE.md constraint 3: this is bookkeeping and arithmetic only. It
## never picks a target, never decides whether a Wolf ship is
## destroyed by anything other than the host tapping damage onto it,
## and never resolves the boarding fight - the host reads dice
## physically and taps the result on. See core/combat/wolf_attack.gd.

const WOLF_CLASS_LABELS: Array[String] = [
	"Battlestation", "Strikecarrier", "Cruiser", "Destroyer", "Fighter Wing", "Assault Transport",
]
## The only craft with a "combat_table" ability (see that ability's own
## file comment) - Maliades, Highwall, and the three fighter wings.
## Triggering their rolls was explicitly deferred when the ability
## itself was first built (see TODO.md's Wolf Attack system section) -
## this is that deferred piece.
const COMBAT_TABLE_CRAFT_IDS: Array[String] = [
	"maliades", "highwall", "fighter_wing_alpha", "fighter_wing_bravo", "pdf_escort_wing",
]
const WOLF_PHASE_LABELS: Dictionary[WolfAttack.Phase, String] = {
	WolfAttack.Phase.INCOMING: "Incoming",
	WolfAttack.Phase.TARGETING: "Targeting",
	WolfAttack.Phase.RANGE_LONG: "Range: Long",
	WolfAttack.Phase.RANGE_MEDIUM: "Range: Medium",
	WolfAttack.Phase.RANGE_SHORT: "Range: Short",
	WolfAttack.Phase.BOARDING: "Boarding",
	WolfAttack.Phase.RESOLUTION: "Resolution",
}

var _new_wolf_class_option: OptionButton

func _rebuild_wolf_attack_section() -> void:
	for child in _wolf_attack_section.get_children():
		child.free()

	if game_state.wolf_attack == null:
		var start_button := Button.new()
		start_button.text = "Start Wolf Attack"
		start_button.pressed.connect(func() -> void: game_state.start_wolf_attack())
		_wolf_attack_section.add_child(start_button)
		return

	var attack := game_state.wolf_attack

	var phase_row := HBoxContainer.new()
	var phase_label := Label.new()
	phase_label.text = "Phase: %s" % WOLF_PHASE_LABELS.get(attack.phase, "?")
	var retreat_button := Button.new()
	retreat_button.text = "◂ Retreat"
	retreat_button.pressed.connect(func() -> void: attack.retreat_phase())
	var advance_button := Button.new()
	advance_button.text = "Advance ▸"
	advance_button.pressed.connect(func() -> void: attack.advance_phase())
	var end_button := Button.new()
	end_button.text = "End Attack"
	end_button.pressed.connect(func() -> void: game_state.end_wolf_attack())
	phase_row.add_child(phase_label)
	phase_row.add_child(retreat_button)
	phase_row.add_child(advance_button)
	phase_row.add_child(end_button)
	_wolf_attack_section.add_child(phase_row)

	var add_row := HBoxContainer.new()
	_new_wolf_class_option = OptionButton.new()
	for label in WOLF_CLASS_LABELS:
		_new_wolf_class_option.add_item(label)
	var add_button := Button.new()
	add_button.text = "Add Wolf Ship"
	add_button.pressed.connect(func() -> void:
		attack.add_wolf_ship(_new_wolf_class_option.selected as WolfShipDefinitions.Class, game_state.rng)
	)
	add_row.add_child(_new_wolf_class_option)
	add_row.add_child(add_button)
	_wolf_attack_section.add_child(add_row)

	var total_capacity := 0
	for id: String in attack.wolf_ships:
		total_capacity += attack.wolf_ships[id].capacity()
	var capacity_label := Label.new()
	capacity_label.text = "Total damage capacity: %d" % total_capacity
	_wolf_attack_section.add_child(capacity_label)

	for id: String in attack.wolf_ships:
		_wolf_attack_section.add_child(_build_wolf_ship_row(attack, attack.wolf_ships[id]))

	# combat_table only knows MEDIUM/SHORT (CombatTableAbility.RangeBand
	# has no LONG option at all - nothing fires at long range per the
	# rules), so this section only makes sense during those two phases.
	if attack.phase in [WolfAttack.Phase.RANGE_MEDIUM, WolfAttack.Phase.RANGE_SHORT]:
		_wolf_attack_section.add_child(_build_combat_table_section(attack))

	if attack.phase == WolfAttack.Phase.BOARDING:
		_wolf_attack_section.add_child(_build_boarding_section(attack))

	if attack.phase == WolfAttack.Phase.RESOLUTION:
		_wolf_attack_section.add_child(_build_resolution_section(attack))

func _build_wolf_ship_row(attack: WolfAttack, ship: WolfShipState) -> Control:
	var row := VBoxContainer.new()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "%s %s - %d/%d dmg%s" % [
		WolfShipDefinitions.code_for(ship.wolf_class), ship.id,
		ship.damage_taken, ship.capacity(),
		" - DESTROYED" if ship.is_destroyed() else "",
	]
	header.add_child(name_label)
	var minus_button := Button.new()
	minus_button.text = "-1 dmg"
	minus_button.pressed.connect(func() -> void: attack.add_damage(ship.id, -1))
	var plus_button := Button.new()
	plus_button.text = "+1 dmg"
	plus_button.pressed.connect(func() -> void: attack.add_damage(ship.id, 1))
	header.add_child(minus_button)
	header.add_child(plus_button)
	row.add_child(header)

	if attack.phase != WolfAttack.Phase.INCOMING:
		var target_row := HBoxContainer.new()
		var target_label := Label.new()
		target_label.text = "Target: %s" % ShipRegistry.display_name(ship.target_ship_id())
		target_row.add_child(target_label)
		var reroll_button := Button.new()
		reroll_button.text = "Re-roll (Wolf Commander)"
		reroll_button.pressed.connect(func() -> void: attack.reroll_target(ship.id, game_state.rng))
		var shift_down_button := Button.new()
		shift_down_button.text = "Shift -1"
		shift_down_button.pressed.connect(func() -> void: attack.shift_target(ship.id, -1))
		var shift_up_button := Button.new()
		shift_up_button.text = "Shift +1"
		shift_up_button.pressed.connect(func() -> void: attack.shift_target(ship.id, 1))
		var force_aegis_button := Button.new()
		force_aegis_button.text = "Force → AEGIS (C&C)"
		force_aegis_button.pressed.connect(func() -> void: attack.force_target(ship.id, "aegis"))
		target_row.add_child(reroll_button)
		target_row.add_child(shift_down_button)
		target_row.add_child(shift_up_button)
		target_row.add_child(force_aegis_button)
		row.add_child(target_row)

	return row

## The deferred piece from the Wolf Attack system's original build -
## Maliades/Highwall/fighter wings already had working dice arithmetic
## via CombatTableAbility, but nothing anywhere called execute() on it.
## Rolls go through the ability exactly as combat_table_test.gd already
## exercises it - can_execute()'s reason surfaces directly if a craft
## can't fight right now (no fuel, no charged bay, already destroyed),
## and execute() now returns the full stamped roll result (Dice Engine
## Phase 3), so this can show individual faces via RollText.describe()
## the same way the Dice Log section does.
func _build_combat_table_section(attack: WolfAttack) -> Control:
	var section := VBoxContainer.new()
	var label := Label.new()
	label.text = "Combat Table - %s range" % ("Medium" if attack.phase == WolfAttack.Phase.RANGE_MEDIUM else "Short")
	section.add_child(label)

	var range_band := CombatTableAbility.RangeBand.MEDIUM if attack.phase == WolfAttack.Phase.RANGE_MEDIUM else CombatTableAbility.RangeBand.SHORT
	var ability := AbilityRegistry.get_ability("combat_table")
	for craft_id: String in COMBAT_TABLE_CRAFT_IDS:
		section.add_child(_build_combat_table_row(ability, craft_id, range_band))

	return section

func _build_combat_table_row(ability: Ability, craft_id: String, range_band: CombatTableAbility.RangeBand) -> Control:
	var row := HBoxContainer.new()
	var definition := CraftDefinitions.get_definition(craft_id)
	var name_label := Label.new()
	name_label.text = definition.display_name if definition != null else craft_id
	name_label.custom_minimum_size = Vector2(220, 0)
	row.add_child(name_label)

	var check := ability.can_execute(game_state, craft_id, {"range": range_band})
	if not check.ok:
		var reason_label := Label.new()
		reason_label.text = "unavailable - %s" % check.reason
		row.add_child(reason_label)
		return row

	var result_label := Label.new()
	var fire_button := Button.new()
	fire_button.text = "Fire"
	fire_button.pressed.connect(func() -> void:
		result_label.text = _describe_combat_table_result(ability.execute(game_state, craft_id, {"range": range_band}))
	)
	row.add_child(fire_button)
	row.add_child(result_label)
	return row

func _describe_combat_table_result(result: AbilityResult) -> String:
	if not result.ok:
		return result.reason
	var data: Dictionary = result.data
	var faces: PackedInt32Array = data.get("faces", PackedInt32Array())
	var face_strings: Array[String] = []
	for face in faces:
		face_strings.append(str(face))
	var text := "[%s] -> %s" % [", ".join(face_strings), RollText.describe(data)]
	if int(data.get("self_damage", 0)) > 0:
		text += " - %d self-damage" % int(data["self_damage"])
	if int(data.get("fighters_lost", 0)) > 0:
		text += " - %d fighter(s) lost" % int(data["fighters_lost"])
	if data.get("destroyed", false):
		text += " - DESTROYED"
	return text

func _build_boarding_section(attack: WolfAttack) -> Control:
	var section := VBoxContainer.new()
	var label := Label.new()
	label.text = "Boarding"
	section.add_child(label)

	for ship_id: String in attack.boarders_by_ship:
		if attack.boarders_by_ship[ship_id] <= 0:
			continue
		var ship := game_state.get_ship(ship_id)
		if ship == null:
			continue
		var row := HBoxContainer.new()
		var info_label := Label.new()
		info_label.text = "%s - %d boarders vs %d security teams" % [
			ShipRegistry.display_name(ship_id), attack.boarders_by_ship[ship_id],
			ship.resources.get_amount(ResourceStock.Kind.SECURITY_TEAMS),
		]
		row.add_child(info_label)
		var minus_boarder := Button.new()
		minus_boarder.text = "-1 boarder"
		minus_boarder.pressed.connect(func() -> void: attack.decrement_boarders(ship_id, 1))
		var minus_team := Button.new()
		minus_team.text = "-1 security team"
		minus_team.pressed.connect(func() -> void: ship.resources.add(ResourceStock.Kind.SECURITY_TEAMS, -1))
		row.add_child(minus_boarder)
		row.add_child(minus_team)
		if not attack.wolf_commander_leading_boarding:
			var lead_button := Button.new()
			lead_button.text = "Wolf Commander leads (+2 boarders)"
			lead_button.pressed.connect(func() -> void: attack.lead_boarding_with_commander(ship_id))
			row.add_child(lead_button)
		section.add_child(row)

	return section

func _build_resolution_section(attack: WolfAttack) -> Control:
	var section := VBoxContainer.new()
	var label := Label.new()
	label.text = "Resolution"
	section.add_child(label)

	var tally := attack.compute_damage_tally()
	var damage_by_ship: Dictionary = tally["damage_by_ship"]
	for ship_id: String in ShipRegistry.all_ship_ids():
		var damage_line := Label.new()
		var damage: int = damage_by_ship.get(ship_id, 0)
		damage_line.text = "%s: %d damage" % [ShipRegistry.display_name(ship_id), damage]
		section.add_child(damage_line)

	var returning_counts: Dictionary = tally["returning_counts"]
	var returning_parts: Array[String] = []
	for cls: WolfShipDefinitions.Class in returning_counts:
		returning_parts.append("%d %s" % [returning_counts[cls], WolfShipDefinitions.class_name_for(cls)])
	var returning_line := Label.new()
	returning_line.text = "Returning next attack: %s" % (", ".join(returning_parts) if not returning_parts.is_empty() else "none")
	section.add_child(returning_line)

	# Deliberately not shown: survivor loss per damage point.
	# wolf_attack_tv_display.md §5.5/§9 explicitly flags this as
	# unconfirmed and says not to ship it until it is - only damage
	# pips are shown above.
	var note := Label.new()
	note.text = "(Survivor loss per damage point is not modeled yet - unconfirmed, see TODO.md)"
	section.add_child(note)

	return section

## --- Star Map -------------------------------------------------------------
## docs/star_map_tv_display.md §8's admin console - "the same map with
## ground truth". Uses StarMapProjection.build_ground_truth(), never
## build() - see that function's own comment on why the two are kept as
## separate entrypoints rather than one with a flag. This scene is never
## routed to the TV window or the network, so ground truth here is safe
## the same way every other host-only field in this console already is.
##
## Not built: "Toggle scout ring" / "Toggle jump range" from §8's control
## table - both need scout-range and jump-range overlay state that
## doesn't exist anywhere in core/ yet (StarMapProjection's own header
## comment flags the same gap for scout_rings/jump_ranges). Nothing here
## can toggle a state that isn't tracked.

const STAR_MAP_STATE_NAMES: Array[String] = ["unknown", "reported", "visited", "occupied", "destination"]

func _rebuild_star_map_section() -> void:
	for child in _star_map_section.get_children():
		child.free()

	var throwaway_refreshers: Array[Callable] = []
	_star_map_section.add_child(_make_option_row(
		throwaway_refreshers, "Chart in play", ["A", "B", "C"],
		func() -> int: return maxi(0, ["A", "B", "C"].find(game_state.chart_in_play)),
		func(index: int) -> void: game_state.set_chart_in_play(["A", "B", "C"][index])
	))

	var view := StarMapProjection.build_ground_truth(
		game_state.chart_in_play, game_state.turn_manager.turn_number,
		game_state.fleet_positions, game_state.reveal_state, game_state.craft, game_state.ships
	)

	var canvas_scroll := ScrollContainer.new()
	canvas_scroll.custom_minimum_size = Vector2(0, 480)
	var canvas := StarMapCanvas.new()
	canvas.custom_minimum_size = Vector2(1440, 1050)
	canvas.view = view
	canvas_scroll.add_child(canvas)
	_star_map_section.add_child(canvas_scroll)

	var coordinate_ids: Array[String] = []
	var coordinate_labels: Array[String] = []
	for node: Dictionary in (view["nodes"] as Array):
		var coordinate: String = node["id"]
		coordinate_ids.append(coordinate)
		if node.has("letter"):
			coordinate_labels.append("%s - %s %s" % [coordinate, node["letter"], node["name"]])
		else:
			coordinate_labels.append(coordinate)

	var unit_ids := FleetPositions.unit_ids()

	var move_label := Label.new()
	move_label.text = "Move unit (adjacency not enforced - jump failures/host corrections can go anywhere)"
	_star_map_section.add_child(move_label)

	var move_row := HBoxContainer.new()
	var move_unit_option := OptionButton.new()
	for unit_id: String in unit_ids:
		move_unit_option.add_item(_star_map_unit_display_name(unit_id))
	move_row.add_child(move_unit_option)
	var move_coord_option := OptionButton.new()
	for label in coordinate_labels:
		move_coord_option.add_item(label)
	move_row.add_child(move_coord_option)
	var move_button := Button.new()
	move_button.text = "Move"
	move_button.pressed.connect(func() -> void:
		game_state.fleet_positions.move_unit(unit_ids[move_unit_option.selected], coordinate_ids[move_coord_option.selected], game_state.turn_manager.turn_number)
	)
	move_row.add_child(move_button)
	var undo_button := Button.new()
	undo_button.text = "Undo last move"
	undo_button.pressed.connect(func() -> void:
		game_state.fleet_positions.undo_last_move(unit_ids[move_unit_option.selected], game_state.turn_manager.turn_number)
	)
	move_row.add_child(undo_button)
	_star_map_section.add_child(move_row)

	var groups_label := Label.new()
	groups_label.text = "Groups"
	_star_map_section.add_child(groups_label)
	for group: Dictionary in (view["groups"] as Array):
		_star_map_section.add_child(_build_star_map_group_row(group))

	var claim_label := Label.new()
	claim_label.text = "Publish scout claim (verbatim - never checked against the chart, per CLAUDE.md constraint 1)"
	_star_map_section.add_child(claim_label)

	var claim_coord_option := OptionButton.new()
	for label in coordinate_labels:
		claim_coord_option.add_item(label)
	var claim_text_edit := LineEdit.new()
	claim_text_edit.placeholder_text = "Claim text, verbatim"
	claim_text_edit.custom_minimum_size = Vector2(260, 0)
	var claim_source_edit := LineEdit.new()
	claim_source_edit.placeholder_text = "Source (e.g. STARLIGHT)"
	claim_source_edit.custom_minimum_size = Vector2(160, 0)
	var claim_row := HBoxContainer.new()
	claim_row.add_child(claim_coord_option)
	claim_row.add_child(claim_text_edit)
	claim_row.add_child(claim_source_edit)
	var publish_button := Button.new()
	publish_button.text = "Publish Claim"
	publish_button.pressed.connect(func() -> void:
		if claim_text_edit.text.strip_edges().is_empty():
			return
		game_state.reveal_state.publish_claim(coordinate_ids[claim_coord_option.selected], claim_text_edit.text, claim_source_edit.text, game_state.turn_manager.turn_number)
	)
	claim_row.add_child(publish_button)
	_star_map_section.add_child(claim_row)

	for coordinate: String in game_state.reveal_state.claims:
		var claims := game_state.reveal_state.claims_at(coordinate)
		for i in claims.size():
			_star_map_section.add_child(_build_star_map_claim_row(coordinate, claims[i], i))

	var force_label := Label.new()
	force_label.text = "Force node state (escape hatch, constraint 5 - never attaches real letter data on its own)"
	_star_map_section.add_child(force_label)

	var force_coord_option := OptionButton.new()
	for label in coordinate_labels:
		force_coord_option.add_item(label)
	var force_state_option := OptionButton.new()
	for state_name in STAR_MAP_STATE_NAMES:
		force_state_option.add_item(state_name)
	var force_row := HBoxContainer.new()
	force_row.add_child(force_coord_option)
	force_row.add_child(force_state_option)
	var force_button := Button.new()
	force_button.text = "Force"
	force_button.pressed.connect(func() -> void:
		game_state.reveal_state.set_forced_state(coordinate_ids[force_coord_option.selected], STAR_MAP_STATE_NAMES[force_state_option.selected])
	)
	force_row.add_child(force_button)
	var clear_force_button := Button.new()
	clear_force_button.text = "Clear override"
	clear_force_button.pressed.connect(func() -> void:
		game_state.reveal_state.clear_forced_state(coordinate_ids[force_coord_option.selected])
	)
	force_row.add_child(clear_force_button)
	_star_map_section.add_child(force_row)

	if not game_state.reveal_state.forced_states.is_empty():
		var overrides_parts: Array[String] = []
		for coordinate: String in game_state.reveal_state.forced_states:
			overrides_parts.append("%s=%s" % [coordinate, game_state.reveal_state.forced_states[coordinate]])
		var overrides_label := Label.new()
		overrides_label.text = "Active overrides: %s" % ", ".join(overrides_parts)
		_star_map_section.add_child(overrides_label)

static func _star_map_unit_display_name(unit_id: String) -> String:
	if unit_id == "voyage_33_0":
		return "G.I.V. Voyage 33-0"
	return ShipRegistry.display_name(unit_id)

func _build_star_map_group_row(group: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var group_id: String = group["id"]
	var representative: Dictionary = group["representative"]

	var header := Label.new()
	header.text = "%d. %s   at %s   pursuit %d   [%s]" % [
		int(group["index"]), String(group["label"]), String(group["at"]),
		int(group["pursuit"]), ", ".join(group["members"] as Array),
	]
	box.add_child(header)

	var label_row := HBoxContainer.new()
	var label_edit := LineEdit.new()
	label_edit.text = String(group["label"])
	label_edit.custom_minimum_size = Vector2(200, 0)
	label_row.add_child(label_edit)
	var label_button := Button.new()
	label_button.text = "Set label"
	label_button.pressed.connect(func() -> void: game_state.fleet_positions.set_group_label(group_id, label_edit.text))
	label_row.add_child(label_button)
	box.add_child(label_row)

	var pursuit_row := HBoxContainer.new()
	var pursuit_spin := SpinBox.new()
	pursuit_spin.min_value = PursuitTrack.MIN_VALUE
	pursuit_spin.max_value = PursuitTrack.MAX_VALUE
	pursuit_spin.value = int(group["pursuit"])
	pursuit_row.add_child(pursuit_spin)
	var pursuit_button := Button.new()
	pursuit_button.text = "Set pursuit"
	pursuit_button.pressed.connect(func() -> void: game_state.fleet_positions.set_group_pursuit(group_id, int(pursuit_spin.value)))
	pursuit_row.add_child(pursuit_button)
	box.add_child(pursuit_row)

	var member_ids: Array = group["member_ids"]
	if member_ids.size() > 1:
		var is_aegis_group: bool = bool(representative["is_aegis"])
		var rep_row := HBoxContainer.new()
		var rep_option := OptionButton.new()
		for i in member_ids.size():
			var unit_id: String = member_ids[i]
			rep_option.add_item(_star_map_unit_display_name(unit_id))
			if unit_id == String(representative["id"]):
				rep_option.selected = i
		rep_option.disabled = is_aegis_group
		rep_row.add_child(rep_option)
		var rep_button := Button.new()
		rep_button.text = "Set representative"
		rep_button.disabled = is_aegis_group
		rep_button.pressed.connect(func() -> void: game_state.fleet_positions.set_group_representative(group_id, member_ids[rep_option.selected]))
		rep_row.add_child(rep_button)
		if is_aegis_group:
			var locked_label := Label.new()
			locked_label.text = "(locked to AEGIS - §4.1, no exception)"
			rep_row.add_child(locked_label)
		box.add_child(rep_row)

	var pending: Array = group["pending_merge_pursuits"]
	if not pending.is_empty():
		var pending_row := HBoxContainer.new()
		var pending_label := Label.new()
		var pending_text := ", ".join(pending.map(func(v: Variant) -> String: return str(v)))
		pending_label.text = "MERGE PENDING - absorbed pursuit value(s) %s - reconcile to:" % pending_text
		pending_row.add_child(pending_label)
		var reconcile_spin := SpinBox.new()
		reconcile_spin.min_value = PursuitTrack.MIN_VALUE
		reconcile_spin.max_value = PursuitTrack.MAX_VALUE
		reconcile_spin.value = int(group["pursuit"])
		pending_row.add_child(reconcile_spin)
		var reconcile_button := Button.new()
		reconcile_button.text = "Reconcile"
		reconcile_button.pressed.connect(func() -> void: game_state.fleet_positions.reconcile_group_pursuit(group_id, int(reconcile_spin.value)))
		pending_row.add_child(reconcile_button)
		box.add_child(pending_row)

	box.add_child(HSeparator.new())
	return box

func _build_star_map_claim_row(coordinate: String, claim: Dictionary, index: int) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s · T%d · %s: \"%s\"" % [coordinate, int(claim["turn"]), String(claim["source"]), String(claim["text"])]
	row.add_child(label)
	var retract_button := Button.new()
	retract_button.text = "Retract"
	retract_button.pressed.connect(func() -> void: game_state.reveal_state.retract_claim(coordinate, index))
	row.add_child(retract_button)
	return row

## --- dice log ----------------------------------------------------------
## docs/dice_engine_spec.md constraint 5 + §7: "the host can override any
## roll, and an overridden roll is visibly marked as overridden." Every
## other host override in this project (jump coordinates, console state,
## pursuit track, ...) mutates game_state directly rather than round-
## tripping through net/ - see this file's own header comment - and a
## roll override is no different: HostConsole runs in the same process as
## GameState, so this calls game_state.roll_service.override_roll()
## directly. There's deliberately no network "roll_override" message type
## (unlike roll_request, spec §7's other direction) - net/ has no concept
## of "this connection is the host" anywhere else, and inventing one just
## for this would duplicate a path that already exists in-process. See
## TODO.md's Dice Engine backlog.

const _DICE_LOG_DISPLAY_COUNT := 20

func _rebuild_dice_log_section() -> void:
	for child in _dice_log_section.get_children():
		child.free()

	var entries := game_state.roll_log.entries
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No rolls yet."
		_dice_log_section.add_child(empty_label)
		return

	var start := maxi(0, entries.size() - _DICE_LOG_DISPLAY_COUNT)
	for i in range(start, entries.size()):
		_dice_log_section.add_child(_build_dice_log_row(entries[i]))

func _build_dice_log_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()

	var faces: PackedInt32Array = entry.get("faces", PackedInt32Array())
	var face_strings: Array[String] = []
	for face in faces:
		face_strings.append(str(face))
	var summary := Label.new()
	summary.text = "#%d %s (%s): [%s] -> %s%s" % [
		int(entry.get("id", 0)), String(entry.get("ship", "")), String(entry.get("reason", "")),
		", ".join(face_strings), RollText.describe(entry),
		" [OVERRIDDEN]" if entry.get("over", false) else "",
	]
	row.add_child(summary)

	# Overriding corrects THIS roll's reported outcome - it does not
	# retroactively undo or redo whatever game consequence the original
	# roll already applied (e.g. a ship's unrest change, a craft's combat
	# damage). If the consequence itself also needs correcting, the host
	# already has a direct path to that via this same console's per-ship/
	# per-craft panels above - building automatic re-application here
	# would mean guessing at undo semantics the spec never asks for.
	var faces_input := LineEdit.new()
	faces_input.placeholder_text = "override faces e.g. \"6 6\""
	faces_input.custom_minimum_size = Vector2(140, 0)
	row.add_child(faces_input)

	var override_button := Button.new()
	override_button.text = "Override"
	var roll_id: int = int(entry.get("id", 0))
	var reason: String = String(entry.get("reason", ""))
	var ship_id: String = String(entry.get("ship", ""))
	override_button.pressed.connect(func() -> void:
		var parsed := PackedInt32Array()
		for token in faces_input.text.split(" ", false):
			if token.is_valid_int():
				parsed.append(int(token))
		if parsed.is_empty():
			return
		if reason == "maintenance_riot":
			# "damaged" is a comparison against the ship's current unrest,
			# not something Dice.classify_*() can derive from faces alone
			# (see RollText's own comment) - re-supply it fresh rather
			# than let the override display as a false "no riot damage".
			var ship := game_state.get_ship(ship_id)
			game_state.roll_service.override_roll(roll_id, parsed, func(result: Dictionary) -> void:
				if ship != null:
					result["damaged"] = int(result["faces"][0]) < ship.unrest
			)
		else:
			game_state.roll_service.override_roll(roll_id, parsed)
	)
	row.add_child(override_button)

	return row
