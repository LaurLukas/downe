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

var game_state: GameState
var _all_refreshers: Array[Callable] = []

const RESOURCE_KINDS: Array[ResourceStock.Kind] = [
	ResourceStock.Kind.STRYTIUM_ORE, ResourceStock.Kind.STRYTIUM_FUEL,
	ResourceStock.Kind.FOOD, ResourceStock.Kind.WATER,
	ResourceStock.Kind.MATERIALS, ResourceStock.Kind.SECURITY_TEAMS,
]
const CONSOLE_STATE_NAMES: Array[String] = ["OK", "DAMAGED", "DESTROYED"]

func set_game_state(state: GameState) -> void:
	game_state = state
	game_state.turn_manager.phase_changed.connect(_refresh)
	game_state.pursuit_track.changed.connect(_refresh)

	_pursuit_override.min_value = PursuitTrack.MIN_VALUE
	_pursuit_override.max_value = PursuitTrack.MAX_VALUE
	_advance_button.pressed.connect(_on_advance_pressed)
	_force_pursuit_button.pressed.connect(_on_force_pursuit_pressed)
	_refresh_button.pressed.connect(_on_refresh_all_pressed)

	_refresh()
	_build_ship_panels()
	_build_craft_panels()

func _on_advance_pressed() -> void:
	game_state.turn_manager.advance()

func _on_force_pursuit_pressed() -> void:
	game_state.pursuit_track.set_value(int(_pursuit_override.value))

func _on_refresh_all_pressed() -> void:
	for refresh in _all_refreshers:
		refresh.call()

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

## A collapsible header/body pair. body starts hidden; expanding it
## refreshes every field in the panel from live state. Returns the
## body container so callers can add rows to it.
func _make_collapsible_panel(parent: VBoxContainer, title: String, refreshers: Array[Callable]) -> VBoxContainer:
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
