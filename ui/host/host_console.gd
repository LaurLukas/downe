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

@onready var _turn_label: Label = %TurnLabel
@onready var _advance_button: Button = %AdvanceButton
@onready var _pursuit_label: Label = %PursuitLabel
@onready var _pursuit_override: SpinBox = %PursuitOverride
@onready var _force_pursuit_button: Button = %ForcePursuitButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _ship_list: VBoxContainer = %ShipList
@onready var _craft_list: VBoxContainer = %CraftList
@onready var _players_list: VBoxContainer = %PlayersList
@onready var _new_player_name: LineEdit = %NewPlayerName
@onready var _add_player_button: Button = %AddPlayerButton

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
	_force_pursuit_button.pressed.connect(_on_force_pursuit_pressed)
	_refresh_button.pressed.connect(_on_refresh_all_pressed)

	_add_player_button.pressed.connect(_on_add_player_pressed)

	_refresh()
	_build_ship_panels()
	_build_craft_panels()
	_build_player_panels()

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

	_all_refreshers.append_array(refreshers)

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
