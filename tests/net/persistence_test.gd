extends TestCase

func test_load_dict_with_no_save_file_returns_empty() -> void:
	if FileAccess.file_exists(Persistence.SAVE_PATH):
		DirAccess.remove_absolute(Persistence.SAVE_PATH)
	assert_eq(Persistence.load_dict(), {}, "load_dict() should return {} when nothing has been saved yet")

func test_save_writes_state_that_load_dict_can_read_back() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("dione"))
	state.pursuit_track.set_value(3)
	var persistence := Persistence.new(state)

	persistence.save()
	var loaded := Persistence.load_dict()

	# JSON has no int/float distinction, so parse_string() hands back 3.0,
	# not 3 - compare the scalar (where 3 == 3.0) rather than the dict.
	assert_eq(loaded.get("pursuit_track", {}).get("value"), 3, "loaded pursuit_track value should match what was saved")
	assert_true(loaded.get("ships", {}).has("dione"), "loaded ships should include the added ship")

	DirAccess.remove_absolute(Persistence.SAVE_PATH)

func test_dice_seed_and_state_survive_a_real_json_round_trip() -> void:
	# Regression test for a real bug: GameState.from_dict(state.to_dict())
	# in memory (no JSON involved) always looked fine, but the actual
	# save/load path goes through JSON.stringify()/JSON.parse_string(),
	# and a RandomNumberGenerator.state is a full 64-bit int - past a
	# double's 53-bit mantissa, JSON silently returns the nearest
	# representable float instead of the exact value. That corrupted the
	# restored stream's position without erroring anywhere. Dice.
	# serialise()/GameState.to_dict()'s rng_seed now encode seed/state as
	# strings specifically to avoid this - this test exercises the real
	# FileAccess + JSON path, not just an in-memory dict hand-off, so it
	# would have caught the original bug.
	var state := GameState.new()
	state.roll_service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var persistence := Persistence.new(state)
	persistence.save()

	var loaded := GameState.from_dict(Persistence.load_dict())

	assert_eq(loaded.dice_engine.roll(4), state.dice_engine.roll(4), "the dice stream must resume from the exact saved position after a real save/load round trip, not a float-rounded approximation of it")
	assert_eq(loaded.rng.seed, state.rng.seed, "the other rng stream's seed must also survive a real save/load round trip intact")

	DirAccess.remove_absolute(Persistence.SAVE_PATH)

func test_roll_log_faces_survive_a_real_json_round_trip_as_comparable_arrays() -> void:
	# JSON has no packed-array type, so faces comes back as a plain
	# Array after a real save/load - GDScript's == operator throws a
	# script error comparing Array to PackedInt32Array rather than just
	# returning false, so RollLog.load_from_dict() normalizes back to
	# PackedInt32Array. This exercises that through the real file path,
	# not an in-memory dict hand-off.
	var state := GameState.new()
	var original := state.roll_service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var persistence := Persistence.new(state)
	persistence.save()

	var loaded := GameState.from_dict(Persistence.load_dict())

	var restored_faces: PackedInt32Array = loaded.roll_log.entries[0]["faces"]
	assert_eq(restored_faces, original["faces"], "faces should compare equal as PackedInt32Array after a real save/load round trip, not throw or silently mismatch")

	DirAccess.remove_absolute(Persistence.SAVE_PATH)

func test_mutating_game_state_triggers_autosave() -> void:
	var state := GameState.new()
	var persistence := Persistence.new(state)

	state.add_ship(Ship.new("shepherd"))
	var loaded := Persistence.load_dict()

	assert_true(loaded.get("ships", {}).has("shepherd"), "a mutation should trigger an autosave via the mutated signal")

	DirAccess.remove_absolute(Persistence.SAVE_PATH)
