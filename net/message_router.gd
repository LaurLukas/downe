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
	_handlers["roll_request"] = _handle_roll_request

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

## {"type": "roll_request", "ship": "icebreaker", "reason": "..."} -
## docs/dice_engine_spec.md §7. The client never supplies dice count,
## modifier, or thresholds - those come entirely from ship state and
## the reason key's own rules here, never from the message, so a client
## can't hand itself a favorable roll.
##
## Only reason keys that are fully self-sufficient from just {ship,
## reason} are wired here. "maintenance_unrest" needs a ration bonus
## that isn't tracked anywhere as ship state yet (today it's chosen
## live, per turn, by whoever runs the host console's ration-level
## picker) and "weapon_fire" has an open question in TODO.md's Dice
## Engine backlog about who's even authorized to trigger a Wolf Attack
## weapon roll - both are left unwired rather than guessed at, per this
## project's own "flag it, don't guess" practice. Unrecognized or
## not-yet-wired reason keys are silently ignored, same trust posture as
## any other unhandled message this router sees.
const _ROLL_REQUEST_REASONS := ["maintenance_riot"]

func _handle_roll_request(message: Dictionary) -> void:
	var reason: String = message.get("reason", "")
	if not (reason in _ROLL_REQUEST_REASONS):
		return
	var ship_id: String = message.get("ship", "")
	var ship := game_state.get_ship(ship_id)
	if ship == null:
		return
	match reason:
		"maintenance_riot":
			MaintenanceCycle.roll_riot_damage(game_state, ship_id)
			ship.mark_maintenance_step_complete(MaintenanceCycle.Step.RIOT_ROLL)
