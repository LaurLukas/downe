class_name MessageRouter
extends RefCounted

## Dispatches decoded {"type": ...} messages to GameState mutations.
## This is the seam where net/'s transport meets core/'s rules - the
## only place in net/ that calls into core/. Layers still talk downward
## only: core/ never references this back.

signal unhandled_message(message: Dictionary)

var game_state: GameState
var _handlers: Dictionary[String, Callable] = {}

func _init(state: GameState) -> void:
	game_state = state
	_handlers["set_jump_coordinates"] = _handle_set_jump_coordinates
	_handlers["set_drive_charged"] = _handle_set_drive_charged

func route(message: Dictionary) -> void:
	var type: String = message.get("type", "")
	if _handlers.has(type):
		_handlers[type].call(message)
	else:
		unhandled_message.emit(message)

## Trusts whatever coordinates were sent, verbatim - never validated
## against real star system data. See CLAUDE.md constraint 1.
func _handle_set_jump_coordinates(message: Dictionary) -> void:
	var ship := game_state.get_ship(message.get("ship_id", ""))
	if ship != null:
		ship.set_jump_coordinates(message.get("coordinates", ""))

func _handle_set_drive_charged(message: Dictionary) -> void:
	var ship := game_state.get_ship(message.get("ship_id", ""))
	if ship != null:
		ship.set_drive_charged(message.get("charged", false))
