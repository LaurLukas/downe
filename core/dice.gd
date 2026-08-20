class_name Dice
extends RefCounted

## The one place in DoWNE that rolls a die - docs/dice_engine_spec.md.
## Every die in the tabletop original is a d6; every roll in the game
## reduces to one of the three shapes below (spec §3). This class knows
## nothing about ships, unrest, damage, or turns - core/roll_service.gd
## owns the game-meaningful wrapping (reason keys, stamping, logging).
## Pure RefCounted, no Node/get_tree()/Engine - runs under
## `godot --headless` (CLAUDE.md's core/ layer rule).
##
## Randomness is a RandomNumberGenerator instance, never global
## randi()/randf() - its seed and state are both readable/writable,
## which is what makes serialise()/restore() possible (spec §6: a host
## restart must resume the stream, not silently reroll).

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

## Roll n six-sided dice. Returns face values in roll order.
func roll(n: int) -> PackedInt32Array:
	var faces := PackedInt32Array()
	faces.resize(n)
	for i in n:
		faces[i] = _rng.randi_range(1, 6)
	return faces

## Roll n dice, add modifier, classify the total against ascending
## thresholds. band is the index of the first threshold the total falls
## under, or thresholds.size() if it meets or exceeds them all.
func sum_band(n: int, modifier: int, thresholds: PackedInt32Array) -> Dictionary:
	return classify_sum_band(roll(n), modifier, thresholds)

## Roll n dice, count how many faces are >= target.
func count_successes(n: int, target: int) -> Dictionary:
	return classify_count_successes(roll(n), target)

## Pure classification, no rolling - shared by sum_band() above and by
## RollService.override_roll(), which recomputes from host-supplied
## faces (spec §7) rather than rolling. Static because it needs no rng
## state at all.
static func classify_sum_band(faces: PackedInt32Array, modifier: int, thresholds: PackedInt32Array) -> Dictionary:
	var total := modifier
	for face in faces:
		total += face
	var band := thresholds.size()
	for i in thresholds.size():
		if total < thresholds[i]:
			band = i
			break
	return {"faces": faces, "modifier": modifier, "total": total, "band": band}

## Pure classification, no rolling - see classify_sum_band()'s comment.
static func classify_count_successes(faces: PackedInt32Array, target: int) -> Dictionary:
	var successes := 0
	for face in faces:
		if face >= target:
			successes += 1
	return {"faces": faces, "target": target, "successes": successes}

## seed + state together let restore() resume the exact stream position -
## seed alone (what GameState.rng persists today for the *other* stream)
## would replay from the start instead of from where play actually was.
##
## Both are encoded as strings, not raw JSON numbers - a real bug found
## by testing the actual Persistence.save()/load_dict() path (JSON.
## stringify -> JSON.parse_string), not just passing to_dict()'s output
## straight to from_dict() in memory: seed/state are full 64-bit ints,
## and Godot's JSON parser returns numbers without a decimal point as
## int ONLY when they fit a double's 53-bit mantissa - a real
## RandomNumberGenerator.state value like 5288669666918256702 silently
## came back as the float 5288669666918256640.0, restoring a stream
## that merely started NEAR the right point, not at it. That's exactly
## the "host restart silently rerolls" failure spec §6 calls "the
## single worst thing this module could do" - a wrong-by-62 restore is
## just as bad as no restore at all. String round-trips losslessly.
func serialise() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}

func restore(data: Dictionary) -> void:
	_rng.seed = int(data.get("seed", _rng.seed))
	_rng.state = int(data.get("state", _rng.state))
