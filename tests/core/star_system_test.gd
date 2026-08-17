extends TestCase

func test_definition_looks_up_by_letter() -> void:
	var system := StarSystem.new("A")
	assert_eq(system.definition().display_name, "Lichen-Covered Asteroids", "definition() should resolve the static roster entry")

func test_complete_opportunity_marks_it_and_is_idempotent() -> void:
	var system := StarSystem.new("A")
	assert_true(not system.is_opportunity_completed(0), "should start uncompleted")
	system.complete_opportunity(0)
	assert_true(system.is_opportunity_completed(0), "should be marked completed")
	system.complete_opportunity(0)
	assert_eq(system.completed_opportunity_indices.size(), 1, "completing the same opportunity twice should not duplicate it")

func test_set_wolf_base_destroyed() -> void:
	var system := StarSystem.new("L")
	assert_true(not system.wolf_base_destroyed, "should start operational")
	system.set_wolf_base_destroyed(true)
	assert_true(system.wolf_base_destroyed, "should be marked destroyed after set_wolf_base_destroyed(true)")

func test_roll_hidden_difficulty_uses_the_5x_formula() -> void:
	var system := StarSystem.new("K")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var roll := rng.randi_range(1, 6)
	rng.seed = 1  # reset so the system's own roll matches the same first value
	system.roll_hidden_difficulty(rng)
	assert_eq(system.hidden_difficulty, 5 * roll, "difficulty should be 5x the rolled value")
	assert_eq(system.hidden_critical_threshold, 5 * roll + 10, "critical threshold should be 5x+10")

func test_roll_hidden_difficulty_only_rolls_once() -> void:
	var system := StarSystem.new("K")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	system.roll_hidden_difficulty(rng)
	var first_value := system.hidden_difficulty
	system.roll_hidden_difficulty(rng)
	assert_eq(system.hidden_difficulty, first_value, "rolling twice should not change an already-rolled difficulty")

func test_changes_bubble_to_changed_signal() -> void:
	var system := StarSystem.new("A")
	var count: Array[int] = [0]
	system.changed.connect(func() -> void: count[0] += 1)
	system.complete_opportunity(0)
	system.set_wolf_base_destroyed(true)
	assert_eq(count[0], 2, "both completing an opportunity and destroying the wolf base should bubble to changed")

func test_round_trips_through_dict() -> void:
	var system := StarSystem.new("K")
	system.complete_opportunity(0)
	system.set_wolf_base_destroyed(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	system.roll_hidden_difficulty(rng)

	var loaded := StarSystem.from_dict(system.to_dict())

	assert_eq(loaded.letter, "K", "letter should round-trip")
	assert_true(loaded.is_opportunity_completed(0), "completed opportunities should round-trip")
	assert_true(loaded.wolf_base_destroyed, "wolf_base_destroyed should round-trip")
	assert_eq(loaded.hidden_difficulty, system.hidden_difficulty, "hidden_difficulty should round-trip")
	assert_eq(loaded.hidden_critical_threshold, system.hidden_critical_threshold, "hidden_critical_threshold should round-trip")
