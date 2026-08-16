extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_two_operations_per_turn_unfuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("mining_operations")
	var params := {"choice": "materials"}

	assert_true(ability.execute(state, "highwall", params).ok, "1st operation should succeed")
	assert_true(ability.execute(state, "highwall", params).ok, "2nd operation should succeed")
	assert_true(not ability.can_execute(state, "highwall", params).ok, "3rd operation should be unavailable unfuelled")

func test_three_operations_per_turn_fuelled() -> void:
	var state := _build_game_state()
	state.get_craft("highwall").set_fuelled(true)
	var ability := AbilityRegistry.get_ability("mining_operations")
	var params := {"choice": "ore"}

	assert_true(ability.execute(state, "highwall", params).ok, "1st operation should succeed")
	assert_true(ability.execute(state, "highwall", params).ok, "2nd operation should succeed")
	assert_true(ability.execute(state, "highwall", params).ok, "3rd operation should succeed when fuelled")
	assert_true(not ability.can_execute(state, "highwall", params).ok, "4th operation should be unavailable even fuelled")

func test_materials_choice_rolls_one_die_into_materials() -> void:
	var state := _build_game_state()
	state.rng.seed = 12345
	var icebreaker := state.get_ship("icebreaker")
	var starting := icebreaker.resources.get_amount(ResourceStock.Kind.MATERIALS)
	var ability := AbilityRegistry.get_ability("mining_operations")

	var result := ability.execute(state, "highwall", {"choice": "materials"})

	var gained: int = result.data["gained"]
	assert_true(gained >= 1 and gained <= 6, "materials choice should roll 1d6")
	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.MATERIALS), starting + gained, "gained materials should be added to the docked ship")

func test_ore_choice_rolls_three_dice_into_ore() -> void:
	var state := _build_game_state()
	state.rng.seed = 12345
	var icebreaker := state.get_ship("icebreaker")
	var starting := icebreaker.resources.get_amount(ResourceStock.Kind.STRYTIUM_ORE)
	var ability := AbilityRegistry.get_ability("mining_operations")

	var result := ability.execute(state, "highwall", {"choice": "ore"})

	var gained: int = result.data["gained"]
	assert_true(gained >= 3 and gained <= 18, "ore choice should roll 3d6")
	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.STRYTIUM_ORE), starting + gained, "gained ore should be added to the docked ship")
