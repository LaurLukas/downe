extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_repair_costs_four_materials_per_console() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	icebreaker.get_console("storage").damage()
	icebreaker.resources.set_amount(ResourceStock.Kind.MATERIALS, 10)
	var ability := AbilityRegistry.get_ability("repair")

	var result := ability.execute(state, "blacksmith", {
		"mode": "repair",
		"repairs": [{"ship_id": "icebreaker", "console_id": "storage"}],
	})

	assert_true(result.ok, "repair should succeed")
	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.MATERIALS), 6, "should have spent 4 materials")
	assert_eq(icebreaker.get_console("storage").state, Console.State.OK, "console should be repaired")

func test_repair_caps_at_two_consoles_on_one_ship() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	icebreaker.resources.set_amount(ResourceStock.Kind.MATERIALS, 100)
	var ability := AbilityRegistry.get_ability("repair")

	var check := ability.can_execute(state, "blacksmith", {
		"mode": "repair",
		"repairs": [
			{"ship_id": "icebreaker", "console_id": "storage"},
			{"ship_id": "icebreaker", "console_id": "reactor"},
			{"ship_id": "icebreaker", "console_id": "shuttle_bay"},
		],
	})

	assert_true(not check.ok, "should not be able to repair 3 consoles on 1 ship")

func test_repair_requires_fuel_for_a_second_ship() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	var shepherd := state.get_ship("shepherd")
	icebreaker.resources.set_amount(ResourceStock.Kind.MATERIALS, 100)
	shepherd.resources.set_amount(ResourceStock.Kind.MATERIALS, 100)
	var ability := AbilityRegistry.get_ability("repair")
	var params := {
		"mode": "repair",
		"repairs": [
			{"ship_id": "icebreaker", "console_id": "storage"},
			{"ship_id": "shepherd", "console_id": "storage"},
		],
	}

	var unfuelled_check := ability.can_execute(state, "blacksmith", params)
	assert_true(not unfuelled_check.ok, "unfuelled repair should not be able to span 2 ships")

	state.get_craft("blacksmith").set_fuelled(true)
	var fuelled_check := ability.can_execute(state, "blacksmith", params)
	assert_true(fuelled_check.ok, "fuelled repair should be able to span 2 ships, 2 consoles each")

func test_damage_for_materials_requires_consent() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("repair")

	var without_consent := ability.can_execute(state, "blacksmith", {
		"mode": "damage_for_materials", "ship_id": "icebreaker", "console_id": "storage", "consent": false,
	})
	assert_true(not without_consent.ok, "damage_for_materials should not execute without consent")

	var with_consent := ability.can_execute(state, "blacksmith", {
		"mode": "damage_for_materials", "ship_id": "icebreaker", "console_id": "storage", "consent": true,
	})
	assert_true(with_consent.ok, "damage_for_materials should execute once consent is given")

func test_damage_for_materials_grants_three_materials() -> void:
	var state := _build_game_state()
	var icebreaker := state.get_ship("icebreaker")
	icebreaker.resources.set_amount(ResourceStock.Kind.MATERIALS, 0)
	var ability := AbilityRegistry.get_ability("repair")

	var result := ability.execute(state, "blacksmith", {
		"mode": "damage_for_materials", "ship_id": "icebreaker", "console_id": "storage", "consent": true,
	})

	assert_true(result.ok, "should succeed with consent")
	assert_eq(icebreaker.resources.get_amount(ResourceStock.Kind.MATERIALS), 3, "should gain 3 materials")
	assert_eq(icebreaker.get_console("storage").state, Console.State.DAMAGED, "console should now be damaged")
