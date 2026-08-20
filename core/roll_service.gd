class_name RollService
extends RefCounted

## Rules-layer wrapper around Dice - docs/dice_engine_spec.md §5. Dice
## just returns numbers and knows nothing about the game; this owns the
## game-meaningful part of a roll: which reason key it belongs to,
## stamping the result with a sequence id/turn/ship, appending it to
## the audit log, and emitting a signal net/ picks up to broadcast
## roll_result (see spec §7). It still doesn't decide what a band or a
## success count *means* in game terms - callers (MaintenanceCycle,
## CombatTableAbility, ...) own that, same as before this existed.

signal rolled(result: Dictionary)

var dice: Dice
var log: RollLog
var _sequence: int = 0

func _init(dice_engine: Dice, roll_log: RollLog, starting_sequence: int = 0) -> void:
	dice = dice_engine
	log = roll_log
	_sequence = starting_sequence

func sequence() -> int:
	return _sequence

## Shape 3.1, spec §3.1 - the primitive. Used where the rule is a simple
## comparison the caller already owns (e.g. maintenance_riot: face <
## current unrest).
func roll_raw(reason: String, ship: String, turn: int, n: int) -> Dictionary:
	return _stamp("roll", reason, ship, turn, {"faces": dice.roll(n)}, {"n": n})

## Shape 3.2 - roll n dice, add modifier, classify against thresholds.
func roll_sum_band(reason: String, ship: String, turn: int, n: int, modifier: int, thresholds: PackedInt32Array) -> Dictionary:
	return _stamp("sum_band", reason, ship, turn, dice.sum_band(n, modifier, thresholds), {"n": n, "thresholds": thresholds})

## Shape 3.3 - roll n dice, count faces >= target.
func roll_count_successes(reason: String, ship: String, turn: int, n: int, target: int) -> Dictionary:
	return _stamp("count_successes", reason, ship, turn, dice.count_successes(n, target), {"n": n})

## Host override (spec §7): recomputes the outcome from host-supplied
## faces using the original roll's own shape/recipe - never re-rolls.
## The original log entry is untouched; this appends a new entry
## carrying the SAME roll id (so a client's existing "roll #N" row is
## what updates) but marked over=true. find_by_id() returns the oldest
## match, i.e. the true original, regardless of how many times a roll
## has already been overridden - that's what the recipe/target/modifier
## below are read from.
func override_roll(id: int, faces: PackedInt32Array) -> Dictionary:
	var original := log.find_by_id(id)
	if original.is_empty():
		return {}
	var shape: String = original.get("shape", "")
	var recomputed := _reclassify(shape, faces, original)
	recomputed["id"] = id
	recomputed["reason"] = original.get("reason", "")
	recomputed["ship"] = original.get("ship", "")
	recomputed["turn"] = original.get("turn", 0)
	recomputed["over"] = true
	recomputed["shape"] = shape
	recomputed["_recipe"] = original.get("_recipe", {})
	log.add(recomputed.duplicate(true))
	rolled.emit(recomputed)
	return recomputed

func _reclassify(shape: String, faces: PackedInt32Array, original: Dictionary) -> Dictionary:
	var recipe: Dictionary = original.get("_recipe", {})
	match shape:
		"sum_band":
			return Dice.classify_sum_band(faces, int(original.get("modifier", 0)), recipe.get("thresholds", PackedInt32Array()))
		"count_successes":
			return Dice.classify_count_successes(faces, int(original.get("target", 0)))
		_:
			return {"faces": faces}

func _stamp(shape: String, reason: String, ship: String, turn: int, result: Dictionary, recipe: Dictionary) -> Dictionary:
	_sequence += 1
	var stamped := result.duplicate()
	stamped["id"] = _sequence
	stamped["reason"] = reason
	stamped["ship"] = ship
	stamped["turn"] = turn
	stamped["over"] = false
	stamped["shape"] = shape
	stamped["_recipe"] = recipe
	log.add(stamped.duplicate(true))
	rolled.emit(stamped)
	return stamped
