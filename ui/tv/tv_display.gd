class_name TVDisplay
extends Control

## Spectacle screen for the TV/projector. Read-only view onto core/'s
## GameState - it never mutates state, only displays it. Wolf Attacks
## keep their physical battle-map gathering (CLAUDE.md constraint 3);
## this screen supports the room, it doesn't replace it.

@onready var _turn_label: Label = %TurnLabel
@onready var _pursuit_label: Label = %PursuitLabel

var game_state: GameState:
	set(value):
		if game_state != null:
			game_state.turn_manager.phase_changed.disconnect(_refresh)
			game_state.pursuit_track.changed.disconnect(_refresh)
		game_state = value
		if game_state != null:
			game_state.turn_manager.phase_changed.connect(_refresh)
			game_state.pursuit_track.changed.connect(_refresh)
			_refresh()

func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	if game_state == null:
		return
	_turn_label.text = DisplayFormat.turn_label(game_state.turn_manager)
	_pursuit_label.text = DisplayFormat.pursuit_bar(game_state.pursuit_track)
