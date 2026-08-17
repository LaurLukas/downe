extends TestCase

func test_add_star_system_keys_by_letter() -> void:
	var state := GameState.new()
	state.add_star_system(StarSystem.new("A"))
	assert_true(state.get_star_system("A") != null, "get_star_system should find it by letter")

func test_adding_a_star_system_emits_mutated() -> void:
	var state := GameState.new()
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	state.add_star_system(StarSystem.new("A"))
	assert_true(count[0] > 0, "adding a star system should emit mutated")

func test_mutating_an_added_star_system_emits_mutated() -> void:
	var state := GameState.new()
	var system := StarSystem.new("A")
	state.add_star_system(system)
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	system.complete_opportunity(0)
	assert_true(count[0] > 0, "completing an opportunity on an already-added star system should emit mutated")

func test_star_system_setup_populates_all_sixteen() -> void:
	var state := GameState.new()
	StarSystemSetup.populate_star_systems(state)
	assert_eq(state.star_systems.size(), 16, "setup should add all 16 systems")
	assert_true(state.get_star_system("K") != null, "K should be present")

func test_to_dict_includes_star_systems() -> void:
	var state := GameState.new()
	state.add_star_system(StarSystem.new("A"))
	assert_true(state.to_dict().has("star_systems"), "to_dict() should include star_systems for the host-local save")
	assert_true(state.to_dict()["star_systems"].has("A"), "to_dict() should include the added system")

func test_to_public_dict_excludes_star_systems() -> void:
	var state := GameState.new()
	var k := StarSystem.new("K")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	k.roll_hidden_difficulty(rng)
	state.add_star_system(k)
	assert_true(not state.to_public_dict().has("star_systems"), "to_public_dict() must not expose star_systems - system K's hidden_difficulty must never reach a client")

func test_round_trips_star_systems_through_persistence() -> void:
	var state := GameState.new()
	var system := StarSystem.new("L")
	system.set_wolf_base_destroyed(true)
	state.add_star_system(system)

	var loaded := GameState.from_dict(state.to_dict())

	var loaded_l := loaded.get_star_system("L")
	assert_true(loaded_l != null, "the star system should round-trip")
	assert_true(loaded_l.wolf_base_destroyed, "wolf_base_destroyed should round-trip")

func test_rehydrated_star_system_mutations_still_bubble_to_mutated() -> void:
	var state := GameState.new()
	state.add_star_system(StarSystem.new("A"))
	var loaded := GameState.from_dict(state.to_dict())
	var count: Array[int] = [0]
	loaded.mutated.connect(func() -> void: count[0] += 1)

	loaded.get_star_system("A").complete_opportunity(0)

	assert_true(count[0] > 0, "mutating a rehydrated star system should still reach GameState.mutated")
