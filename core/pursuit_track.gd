class_name PursuitTrack
extends RefCounted

## 0-10. Rises over time, falls on jumps away from Wolf space. Reaching
## MAX_VALUE ends the game in failure and drives Wolf attack strength.

const MIN_VALUE := 0
const MAX_VALUE := 10

signal changed(new_value: int)
signal reached_max()

var value: int = MIN_VALUE

func rise(amount: int = 1) -> void:
	set_value(value + amount)

func fall(amount: int = 1) -> void:
	set_value(value - amount)

## Also the host's direct override path - set the track to any ruling
## the host makes. See CLAUDE.md constraint 5.
func set_value(new_value: int) -> void:
	value = clampi(new_value, MIN_VALUE, MAX_VALUE)
	changed.emit(value)
	if value >= MAX_VALUE:
		reached_max.emit()

func to_dict() -> Dictionary:
	return {"value": value}
