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

func test_mutating_game_state_triggers_autosave() -> void:
	var state := GameState.new()
	var persistence := Persistence.new(state)

	state.add_ship(Ship.new("shepherd"))
	var loaded := Persistence.load_dict()

	assert_true(loaded.get("ships", {}).has("shepherd"), "a mutation should trigger an autosave via the mutated signal")

	DirAccess.remove_absolute(Persistence.SAVE_PATH)
