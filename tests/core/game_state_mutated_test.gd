extends TestCase

## GameState.mutated is what Persistence autosaves on and what
## broadcast wiring pushes to connected clients from - see
## net/persistence.gd and ui/main.gd. It needs to fire for every real
## mutation, not just ship/craft/star_system additions, or both of
## those go stale silently.

func _count_mutations(state: GameState) -> Array[int]:
	var count: Array[int] = [0]
	state.mutated.connect(func() -> void: count[0] += 1)
	return count

func test_adding_a_ship_emits_mutated() -> void:
	var state := GameState.new()
	var count := _count_mutations(state)
	state.add_ship(Ship.new("dione"))
	assert_true(count[0] > 0, "adding a ship should emit mutated")

func test_jump_coordinates_on_an_added_ship_emits_mutated() -> void:
	var state := GameState.new()
	var ship := Ship.new("quellon", true)
	state.add_ship(ship)
	var count := _count_mutations(state)

	ship.set_jump_coordinates("3,7,2")

	assert_true(count[0] > 0, "setting jump coordinates on a ship already in the GameState should emit mutated")

func test_drive_charged_on_an_added_ship_emits_mutated() -> void:
	var state := GameState.new()
	var ship := Ship.new("refinery_124")
	state.add_ship(ship)
	var count := _count_mutations(state)

	ship.set_drive_charged(true)

	assert_true(count[0] > 0, "toggling drive charge should emit mutated")

func test_ship_resource_change_emits_mutated() -> void:
	var state := GameState.new()
	var ship := Ship.new("icebreaker")
	state.add_ship(ship)
	var count := _count_mutations(state)

	ship.resources.add(ResourceStock.Kind.STRYTIUM_ORE, 5)

	assert_true(count[0] > 0, "changing a ship's resources should emit mutated")

func test_console_state_change_emits_mutated() -> void:
	var state := GameState.new()
	var ship := Ship.new("aegis")
	var console := ship.add_console("reactor")
	state.add_ship(ship)
	var count := _count_mutations(state)

	console.damage()

	assert_true(count[0] > 0, "damaging a console should emit mutated")

func test_console_added_after_add_ship_still_bubbles() -> void:
	var state := GameState.new()
	var ship := Ship.new("aegis")
	state.add_ship(ship)
	var console := ship.add_console("reactor")
	var count := _count_mutations(state)

	console.set_charged(true)

	assert_true(count[0] > 0, "a console added after add_ship() should still bubble changes up")

func test_craft_change_emits_mutated() -> void:
	var state := GameState.new()
	var craft_state := CraftState.new("philia", "shepherd")
	state.add_craft(craft_state)
	var count := _count_mutations(state)

	craft_state.set_fuelled(true)

	assert_true(count[0] > 0, "fuelling a craft should emit mutated")

func test_craft_cargo_change_emits_mutated() -> void:
	var state := GameState.new()
	var craft_state := CraftState.new("philia", "shepherd")
	state.add_craft(craft_state)
	var count := _count_mutations(state)

	craft_state.cargo.add(ResourceStock.Kind.FOOD, 2)

	assert_true(count[0] > 0, "changing a craft's cargo should emit mutated")

func test_pursuit_track_change_emits_mutated() -> void:
	var state := GameState.new()
	var count := _count_mutations(state)

	state.pursuit_track.rise(1)

	assert_true(count[0] > 0, "changing the pursuit track should emit mutated")

func test_turn_advance_emits_mutated() -> void:
	var state := GameState.new()
	var count := _count_mutations(state)

	state.turn_manager.advance()

	assert_true(count[0] > 0, "advancing the turn/phase should emit mutated")
