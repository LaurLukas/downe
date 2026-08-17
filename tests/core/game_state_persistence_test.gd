extends TestCase

## GameState.from_dict() is crash recovery: Persistence.load_dict()
## already existed, but nothing turned that dict back into a live
## GameState - see TODO.md. These tests cover both round-tripping the
## data and, just as importantly, that a rehydrated GameState is a
## fully live one: mutating a loaded ship/craft/console still bubbles
## up to GameState.mutated (see Ship.from_dict()'s comment on why a
## naive rebuild could silently lose that wiring).

func _build_interesting_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	state.get_ship("aegis").set_jump_coordinates("3,7,2")
	state.get_ship("aegis").set_drive_charged(true)
	state.get_ship("aegis").set_unrest(4)
	state.get_ship("aegis").resources.add(ResourceStock.Kind.FOOD, 3)
	state.get_ship("aegis").get_console("reactor").set_charged(true)
	state.get_ship("aegis").get_console("reactor").damage()
	state.get_craft("philia").set_fuelled(true)
	state.get_craft("philia").cargo.add(ResourceStock.Kind.MATERIALS, 2)
	state.pursuit_track.set_value(6)
	state.rng.seed = 12345
	return state

## GDScript lambdas capture local variables by value, not by reference,
## so a plain "var count := 0" mutated inside the callback would never
## be visible to the caller. Array/Dictionary contents are mutable
## through the capture, so count with a 1-element array instead.
func _count_mutations(state: GameState) -> Array[int]:
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	return count

func test_round_trips_ship_fields() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var ship := loaded.get_ship("aegis")
	assert_eq(ship.jump_coordinates, "3,7,2", "jump coordinates should round-trip")
	assert_true(ship.drive_charged, "drive charge should round-trip")
	assert_eq(ship.unrest, 4, "unrest should round-trip")
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.FOOD), 11, "resource amounts should round-trip (starting 8 + 3 added)")

func test_round_trips_console_state() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var console := loaded.get_ship("aegis").get_console("reactor")
	assert_true(console.charged, "console charge should round-trip")
	assert_eq(console.state, Console.State.DAMAGED, "console damage state should round-trip")

func test_round_trips_craft_state() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var craft_state := loaded.get_craft("philia")
	assert_true(craft_state.fuelled, "craft fuel should round-trip")
	assert_eq(craft_state.cargo.get_amount(ResourceStock.Kind.MATERIALS), 2, "craft cargo should round-trip")

func test_round_trips_announcement_log_without_duplicating_entries() -> void:
	# _build_interesting_state() calls set_jump_coordinates() once, which
	# logs one announcement. Rehydration must not replay it - Ship.
	# from_dict() assigns jump_coordinates directly rather than calling
	# the setter, specifically so reloading a save doesn't re-announce
	# everything that was ever typed.
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	assert_eq(loaded.announcement_log.entries.size(), 1, "the announcement log should round-trip without gaining duplicate entries on reload")
	assert_eq(loaded.announcement_log.entries[0]["text"], "3,7,2", "the round-tripped announcement should match what was originally typed")

func test_round_trips_pursuit_track_and_rng_seed() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	assert_eq(loaded.pursuit_track.value, 6, "pursuit track value should round-trip")
	assert_eq(loaded.rng.seed, 12345, "rng seed should round-trip")

func test_loading_a_team_phase_save_does_not_wipe_the_state_it_just_loaded() -> void:
	# Regression test: TurnManager.force_set() emits phase_changed the
	# same as advance() does, which clears console charge / craft fuel
	# on entering a Team Phase. from_dict() must restore turn/phase
	# before adding ships/craft, or loading a save taken during a Team
	# Phase would immediately erase the charge/fuel it just loaded.
	var state := _build_interesting_state()
	state.turn_manager.force_set(2, TurnManager.Phase.TEAM)
	state.get_ship("aegis").get_console("reactor").set_charged(true)
	state.get_craft("philia").set_fuelled(true)

	var loaded := GameState.from_dict(state.to_dict())

	assert_true(loaded.get_ship("aegis").get_console("reactor").charged, "loading a Team Phase save should not clear the console charge it just loaded")
	assert_true(loaded.get_craft("philia").fuelled, "loading a Team Phase save should not clear the craft fuel it just loaded")

func test_round_trips_turn_and_phase() -> void:
	var state := _build_interesting_state()
	state.turn_manager.advance()  # TEAM -> COORDINATION

	var loaded := GameState.from_dict(state.to_dict())

	assert_eq(loaded.turn_manager.turn_number, 1, "turn number should round-trip")
	assert_eq(loaded.turn_manager.phase, TurnManager.Phase.COORDINATION, "phase should round-trip")

func test_rehydrated_ship_mutations_still_bubble_to_mutated() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var count := _count_mutations(loaded)

	loaded.get_ship("aegis").set_drive_charged(false)

	assert_true(count[0] > 0, "mutating a rehydrated ship should still reach GameState.mutated")

func test_rehydrated_console_mutations_still_bubble_to_mutated() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var count := _count_mutations(loaded)

	loaded.get_ship("aegis").get_console("reactor").repair()

	assert_true(count[0] > 0, "mutating a rehydrated console should still reach GameState.mutated")

func test_rehydrated_ship_resource_mutations_still_bubble_to_mutated() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var count := _count_mutations(loaded)

	loaded.get_ship("aegis").resources.add(ResourceStock.Kind.WATER, 1)

	assert_true(count[0] > 0, "mutating a rehydrated ship's resources should still reach GameState.mutated")

func test_rehydrated_craft_mutations_still_bubble_to_mutated() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var count := _count_mutations(loaded)

	loaded.get_craft("philia").set_fuelled(false)

	assert_true(count[0] > 0, "mutating a rehydrated craft should still reach GameState.mutated")

func test_rehydrated_pursuit_track_mutation_still_bubbles_to_mutated() -> void:
	var loaded := GameState.from_dict(_build_interesting_state().to_dict())
	var count := _count_mutations(loaded)

	loaded.pursuit_track.rise(1)

	assert_true(count[0] > 0, "mutating a rehydrated pursuit track should still reach GameState.mutated")

func test_from_dict_on_empty_dict_does_not_crash() -> void:
	var loaded := GameState.from_dict({})
	assert_eq(loaded.ships.size(), 0, "loading {} should produce an empty, but valid, GameState")
