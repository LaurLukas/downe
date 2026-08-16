extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_does_nothing_if_storage_is_not_damaged() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	var starting := icebreaker.resources.get_amount(ResourceStock.Kind.FOOD)
	StorageDamage.apply_if_damaged(state, "icebreaker")
	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.FOOD), starting, "an undamaged Storage console should not trigger a loss")

func test_five_food_becomes_three_food() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	icebreaker.resources.set_amount(ResourceStock.Kind.FOOD, 5)
	icebreaker.get_console("storage").damage()

	StorageDamage.apply_if_damaged(state, "icebreaker")

	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.FOOD), 3, "5 food should become 3 food per the brief's exact example")

func test_halves_resources_on_docked_shuttles_too() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	var blacksmith := state.get_craft("blacksmith")
	blacksmith.cargo.set_amount(ResourceStock.Kind.FOOD, 5)
	icebreaker.get_console("storage").damage()

	StorageDamage.apply_if_damaged(state, "icebreaker")

	assert_eq(blacksmith.cargo.get_amount(ResourceStock.Kind.FOOD), 3, "resources on a docked shuttle should halve the same way")

func test_does_not_affect_craft_docked_elsewhere() -> void:
	var state := _build_game_state()
	var shepherd := state.get_ship("shepherd")
	var black_sheep := state.get_craft("black_sheep")
	black_sheep.cargo.set_amount(ResourceStock.Kind.FOOD, 10)
	state.get_ship("icebreaker").get_console("storage").damage()

	StorageDamage.apply_if_damaged(state, "icebreaker")

	assert_eq(black_sheep.cargo.get_amount(ResourceStock.Kind.FOOD), 10, "a shuttle docked at a different ship should be unaffected")
