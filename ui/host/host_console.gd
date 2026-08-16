class_name HostConsole
extends Control

## Host admin console. Every rule the engine enforces needs a bypass
## path here - real games go off-script and the host adjudicates.
## See CLAUDE.md constraint 5. Unlike TVDisplay, this scene is allowed
## to mutate core/ state directly, via the same host-override entry
## points core/ already exposes (PursuitTrack.set_value,
## TurnManager.force_set) rather than through net/'s MessageRouter.

@onready var _turn_label: Label = %TurnLabel
@onready var _advance_button: Button = %AdvanceButton
@onready var _pursuit_label: Label = %PursuitLabel
@onready var _pursuit_override: SpinBox = %PursuitOverride
@onready var _force_pursuit_button: Button = %ForcePursuitButton
@onready var _ship_list: VBoxContainer = %ShipList

var game_state: GameState

func set_game_state(state: GameState) -> void:
	game_state = state
	game_state.turn_manager.phase_changed.connect(_refresh)
	game_state.pursuit_track.changed.connect(_refresh)
	game_state.mutated.connect(_rebuild_ship_list)

	_pursuit_override.min_value = PursuitTrack.MIN_VALUE
	_pursuit_override.max_value = PursuitTrack.MAX_VALUE
	_advance_button.pressed.connect(_on_advance_pressed)
	_force_pursuit_button.pressed.connect(_on_force_pursuit_pressed)

	_refresh()
	_rebuild_ship_list()

func _on_advance_pressed() -> void:
	game_state.turn_manager.advance()

func _on_force_pursuit_pressed() -> void:
	game_state.pursuit_track.set_value(int(_pursuit_override.value))

func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	_turn_label.text = DisplayFormat.turn_label(game_state.turn_manager)
	_pursuit_label.text = DisplayFormat.pursuit_bar(game_state.pursuit_track)

func _rebuild_ship_list() -> void:
	for child in _ship_list.get_children():
		child.queue_free()
	for ship_id: String in game_state.ships:
		var ship := game_state.ships[ship_id]
		var row := Label.new()
		row.text = "%s - drive %s - jump coords: %s" % [
			ShipRegistry.display_name(ship_id),
			"charged" if ship.drive_charged else "uncharged",
			ship.jump_coordinates if not ship.jump_coordinates.is_empty() else "(none)",
		]
		_ship_list.add_child(row)
