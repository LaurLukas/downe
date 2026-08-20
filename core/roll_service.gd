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
## current unrest). `augment`, if given, runs on the stamped result
## BEFORE it's logged/broadcast - see its doc comment on `_stamp()` for
## why this exists instead of the caller adding fields after the call
## returns.
func roll_raw(reason: String, ship: String, turn: int, n: int, augment: Callable = Callable()) -> Dictionary:
	return _stamp("roll", reason, ship, turn, {"faces": dice.roll(n)}, {"n": n}, augment)

## Shape 3.2 - roll n dice, add modifier, classify against thresholds.
func roll_sum_band(reason: String, ship: String, turn: int, n: int, modifier: int, thresholds: PackedInt32Array, augment: Callable = Callable()) -> Dictionary:
	return _stamp("sum_band", reason, ship, turn, dice.sum_band(n, modifier, thresholds), {"n": n, "thresholds": thresholds}, augment)

## Shape 3.3 - roll n dice, count faces >= target.
func roll_count_successes(reason: String, ship: String, turn: int, n: int, target: int, augment: Callable = Callable()) -> Dictionary:
	return _stamp("count_successes", reason, ship, turn, dice.count_successes(n, target), {"n": n}, augment)

## Host override (spec §7): recomputes the outcome from host-supplied
## faces using the original roll's own shape/recipe - never re-rolls.
## The original log entry is untouched; this appends a new entry
## carrying the SAME roll id (so a client's existing "roll #N" row is
## what updates) but marked over=true. find_by_id() returns the oldest
## match, i.e. the true original, regardless of how many times a roll
## has already been overridden - that's what the recipe/target/modifier
## below are read from.
func override_roll(id: int, faces: PackedInt32Array, augment: Callable = Callable()) -> Dictionary:
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
	if augment.is_valid():
		augment.call(recomputed)
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

## `augment`, when valid, is called with the stamped dict BEFORE it's
## logged/broadcast - this is what lets a caller like MaintenanceCycle
## attach reason-specific meaning (e.g. maintenance_riot's "damaged",
## which needs the ship's current unrest - context RollService itself
## deliberately doesn't have, see GameState.dice_engine's comment) and
## apply the roll's game consequence (ship.set_unrest(), craft_state.
## set_combat_damage(), ...) as part of the SAME log entry and
## broadcast, not a second one after the fact. Calling it any later
## (i.e. after this method already logged/emitted) would mean whatever
## reaches the audit log and net/'s roll_result message is the bare
## dice result, missing exactly the interpretation a suspicious player
## would be asking about.
func _stamp(shape: String, reason: String, ship: String, turn: int, result: Dictionary, recipe: Dictionary, augment: Callable = Callable()) -> Dictionary:
	_sequence += 1
	var stamped := result.duplicate()
	stamped["id"] = _sequence
	stamped["reason"] = reason
	stamped["ship"] = ship
	stamped["turn"] = turn
	stamped["over"] = false
	stamped["shape"] = shape
	stamped["_recipe"] = recipe
	if augment.is_valid():
		augment.call(stamped)
	log.add(stamped.duplicate(true))
	rolled.emit(stamped)
	return stamped
