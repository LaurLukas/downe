extends TestCase

func test_start_wolf_attack_sets_turn_number_from_turn_manager() -> void:
	var state := GameState.new()
	state.turn_manager.force_set(4, TurnManager.Phase.COORDINATION)
	var attack := state.start_wolf_attack()
	assert_eq(attack.turn_number, 4, "a started attack should record the current turn number")

func test_end_wolf_attack_clears_it() -> void:
	var state := GameState.new()
	state.start_wolf_attack()
	state.end_wolf_attack()
	assert_eq(state.wolf_attack, null, "ending the attack should clear it")

func test_starting_a_wolf_attack_emits_mutated() -> void:
	var state := GameState.new()
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	state.start_wolf_attack()
	assert_true(count[0] > 0, "starting a wolf attack should emit mutated")

func test_mutating_an_active_wolf_attack_emits_mutated() -> void:
	var state := GameState.new()
	var attack := state.start_wolf_attack()
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	attack.advance_phase()
	assert_true(count[0] > 0, "advancing an active wolf attack's phase should emit mutated")

func test_wolf_ship_changes_on_an_active_attack_emit_mutated() -> void:
	var state := GameState.new()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	ship.add_damage(1)
	assert_true(count[0] > 0, "damaging a wolf ship should emit mutated")

func test_round_trips_wolf_attack_through_persistence() -> void:
	var state := GameState.new()
	var attack := state.start_wolf_attack(2)
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)
	attack.advance_phase()  # TARGETING
	attack.advance_phase()  # RANGE_LONG
	attack.add_damage(ship.id, 1)

	var loaded := GameState.from_dict(state.to_dict())

	assert_true(loaded.wolf_attack != null, "an in-progress wolf attack should survive a reload - crash recovery matters here too")
	assert_eq(loaded.wolf_attack.phase, WolfAttack.Phase.RANGE_LONG, "phase should round-trip")
	assert_eq(loaded.wolf_attack.get_wolf_ship(ship.id).damage_taken, 1, "wolf ship state should round-trip")

func test_no_wolf_attack_round_trips_as_null() -> void:
	var state := GameState.new()
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.wolf_attack, null, "with no active attack, reloading should not fabricate one")

func test_rehydrated_wolf_attack_mutations_still_bubble_to_mutated() -> void:
	var state := GameState.new()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)
	var loaded := GameState.from_dict(state.to_dict())
	var count: Array[int] = [0]
	loaded.mutated.connect(func() -> void: count[0] += 1)

	loaded.wolf_attack.get_wolf_ship(ship.id).add_damage(1)

	assert_true(count[0] > 0, "mutating a rehydrated wolf attack should still reach GameState.mutated")
