extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_hummingbird_cannot_move_materials() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("cargo_transfer")
	var check := ability.can_execute(state, "hummingbird", {
		"kind": ResourceStock.Kind.MATERIALS, "amount": 1, "direction": "to_craft",
	})
	assert_true(not check.ok, "Hummingbird should not be able to move materials")

func test_pallas_cannot_move_food() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("cargo_transfer")
	var check := ability.can_execute(state, "pallas", {
		"kind": ResourceStock.Kind.FOOD, "amount": 1, "direction": "to_craft",
	})
	assert_true(not check.ok, "Pallas should not be able to move food")

func test_transfer_to_craft_moves_resources() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("cargo_transfer")
	var philia := state.get_craft("philia")
	var dione := state.get_ship("dione")
	var starting_food := dione.resources.get_amount(ResourceStock.Kind.FOOD)

	var result := ability.execute(state, "philia", {
		"kind": ResourceStock.Kind.FOOD, "amount": 5, "direction": "to_craft",
	})

	assert_true(result.ok, "transfer should succeed")
	assert_eq(philia.cargo.get_amount(ResourceStock.Kind.FOOD), 5, "craft cargo should gain the transferred food")
	assert_eq(dione.resources.get_amount(ResourceStock.Kind.FOOD), starting_food - 5, "ship should lose the transferred food")

func test_transfer_rejects_more_than_available() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("cargo_transfer")
	var check := ability.can_execute(state, "philia", {
		"kind": ResourceStock.Kind.FOOD, "amount": 999999, "direction": "to_craft",
	})
	assert_true(not check.ok, "should not be able to move more resources than the ship has")
