class_name Console
extends RefCounted

## One damageable/repairable/upgradeable subsystem on a ship
## (e.g. "engines", "shields", "comms").

enum State { OK, DAMAGED, DESTROYED }

signal state_changed(new_state: State)
signal upgrade_changed(new_level: int)

var id: String
var state: State = State.OK
var upgrade_level: int = 0

func _init(console_id: String) -> void:
	id = console_id

func set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)

func damage() -> void:
	set_state(State.DAMAGED)

func destroy() -> void:
	set_state(State.DESTROYED)

func repair() -> void:
	set_state(State.OK)

func upgrade() -> void:
	upgrade_level += 1
	upgrade_changed.emit(upgrade_level)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"state": State.keys()[state],
		"upgrade_level": upgrade_level,
	}
