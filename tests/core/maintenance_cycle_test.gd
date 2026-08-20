extends TestCase

func _build_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_aegis_has_seven_steps_others_have_six() -> void:
	assert_eq(MaintenanceCycle.steps_for("aegis").size(), 7, "AEGIS is the only ship with a 7th step")
	assert_eq(MaintenanceCycle.steps_for("dione").size(), 6, "every other ship has 6 steps")

func test_shuttle_bay_console_id_differs_for_aegis() -> void:
	assert_eq(MaintenanceCycle.shuttle_bay_console_id("aegis"), "shuttle_bay_zeta", "AEGIS's step-6 bay is Zeta")
	assert_eq(MaintenanceCycle.shuttle_bay_console_id("dione"), "shuttle_bay", "every other ship just has one shuttle_bay console")

func test_apply_storage_step_only_acts_if_damaged() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	var starting_food := ship.resources.get_amount(ResourceStock.Kind.FOOD)
	MaintenanceCycle.apply_storage_step(state, "aegis")
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.FOOD), starting_food, "an undamaged Storage console should not halve anything")

	ship.get_console("storage").damage()
	MaintenanceCycle.apply_storage_step(state, "aegis")
	assert_true(ship.resources.get_amount(ResourceStock.Kind.FOOD) < starting_food, "a damaged Storage console should halve resources")

func test_spend_rations_deducts_cost_and_returns_bonus() -> void:
	var state := _build_state()
	var ship := state.get_ship("refinery_124")
	ship.resources.set_amount(ResourceStock.Kind.FOOD, 20)
	ship.resources.set_amount(ResourceStock.Kind.WATER, 20)

	# refinery_124: food [0,3,7,11], water [0,2,5,8] - level 2 (short) each
	var bonus := MaintenanceCycle.spend_rations(state, "refinery_124", 2, 2)

	assert_eq(ship.resources.get_amount(ResourceStock.Kind.FOOD), 20 - 7, "food should be spent at the level-2 cost")
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.WATER), 20 - 5, "water should be spent at the level-2 cost")
	assert_eq(bonus, 6 + 6, "level 2 (short) grants the +6 bonus for both food and water")

func test_spend_rations_none_costs_nothing_and_grants_no_bonus() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	var starting_food := ship.resources.get_amount(ResourceStock.Kind.FOOD)

	var bonus := MaintenanceCycle.spend_rations(state, "aegis", 0, 0)

	assert_eq(ship.resources.get_amount(ResourceStock.Kind.FOOD), starting_food, "level 0 (none) should cost nothing")
	assert_eq(bonus, 0, "level 0 should grant no bonus")

func test_roll_unrest_gain_applies_gain_to_ship() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	var starting_unrest := ship.unrest

	# A ration bonus of 100 guarantees the roll totals 20+, so gain
	# should always be 0 regardless of the dice - deterministic without
	# needing to control the rng.
	var result := MaintenanceCycle.roll_unrest_gain(state, "aegis", 100)

	assert_eq(result["unrest_gain"], 0, "a total of 20+ should never gain unrest")
	assert_eq(ship.unrest, starting_unrest, "no gain should mean no change")

func test_roll_unrest_gain_thresholds() -> void:
	# 2d6 spans a wider range (10) than the [12,20) middle bucket (8),
	# so no fixed bonus forces a bucket on its own - a bonus chosen to
	# survive the highest dice roll could still fall through the floor
	# on the lowest. Instead: learn the exact next roll from a
	# same-seeded probe Dice, then pick bonuses relative to that known
	# roll to land exactly on each threshold, resetting
	# state.dice_engine to the same fresh snapshot before each call so
	# the real roll matches the probe every time.
	var state := _build_state()
	var ship := state.get_ship("aegis")

	var probe := Dice.new(99)
	var fresh_snapshot := probe.serialise()
	var probe_faces := probe.roll(2)
	var dice: int = probe_faces[0] + probe_faces[1]

	state.dice_engine.restore(fresh_snapshot)
	ship.set_unrest(0)
	var low := MaintenanceCycle.roll_unrest_gain(state, "aegis", -dice - 1)
	assert_eq(low["unrest_gain"], 2, "a total forced under 12 should gain +2")

	state.dice_engine.restore(fresh_snapshot)
	ship.set_unrest(0)
	var mid := MaintenanceCycle.roll_unrest_gain(state, "aegis", 12 - dice)
	assert_eq(mid["unrest_gain"], 1, "a total of exactly 12 should gain +1")

	state.dice_engine.restore(fresh_snapshot)
	ship.set_unrest(0)
	var high := MaintenanceCycle.roll_unrest_gain(state, "aegis", 20 - dice)
	assert_eq(high["unrest_gain"], 0, "a total of exactly 20 should gain nothing")

func test_roll_unrest_gain_logs_individual_faces_via_roll_service() -> void:
	var state := _build_state()
	MaintenanceCycle.roll_unrest_gain(state, "aegis", 5)
	assert_eq(state.roll_log.entries.size(), 1, "the unrest roll should be captured in the shared audit log")
	var entry: Dictionary = state.roll_log.entries[0]
	assert_eq(entry["reason"], "maintenance_unrest", "the logged reason should match the dice catalogue's key")
	assert_eq(entry["ship"], "aegis", "the logged entry should be stamped with the rolling ship")
	assert_eq((entry["faces"] as PackedInt32Array).size(), 2, "2d6 should log two individual faces, not just a total")

func test_roll_riot_damage_logs_via_roll_service() -> void:
	var state := _build_state()
	MaintenanceCycle.roll_riot_damage(state, "dione")
	assert_eq(state.roll_log.entries.size(), 1, "the riot roll should be captured in the shared audit log")
	assert_eq(state.roll_log.entries[0]["reason"], "maintenance_riot", "the logged reason should match the dice catalogue's key")

func test_roll_riot_damage_reflects_current_unrest() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	ship.set_unrest(0)

	var result := MaintenanceCycle.roll_riot_damage(state, "aegis")

	assert_true(not result["damaged"], "a roll can never be lower than 0 unrest, so no damage should occur")
	assert_eq(result["unrest"], 0, "the result should report the unrest it was checked against")

func test_reactor_charge_cap_matches_ship_baseline() -> void:
	var state := _build_state()
	assert_eq(MaintenanceCycle.reactor_charge_cap(state.get_ship("aegis")), 5, "AEGIS charges 5")
	assert_eq(MaintenanceCycle.reactor_charge_cap(state.get_ship("shepherd")), 3, "Shepherd charges 3")

func test_reactor_charge_cap_rises_with_upgrade() -> void:
	var state := _build_state()
	var ship := state.get_ship("shepherd")
	ship.get_console("reactor").upgrade_level = 1
	assert_eq(MaintenanceCycle.reactor_charge_cap(ship), 4, "an upgraded Reactor should charge one more")

func test_reactor_charge_cap_drops_with_damage() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	ship.get_console("reactor").damage()
	assert_eq(MaintenanceCycle.reactor_charge_cap(ship), 5 - 3, "a damaged AEGIS Reactor loses 3")

func test_reactor_charge_cap_zero_when_destroyed() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	ship.get_console("reactor").destroy()
	assert_eq(MaintenanceCycle.reactor_charge_cap(ship), 0, "a destroyed Reactor can't charge anything")

func test_charged_console_count() -> void:
	var state := _build_state()
	var ship := state.get_ship("aegis")
	assert_eq(MaintenanceCycle.charged_console_count(ship), 0, "should start with nothing charged")
	ship.get_console("reactor").set_charged(true)
	assert_eq(MaintenanceCycle.charged_console_count(ship), 1, "one charged console should count as 1")

func test_can_refuel_shuttle_requires_ok_bay_and_fuel() -> void:
	var state := _build_state()
	var ship := state.get_ship("dione")
	assert_true(MaintenanceCycle.can_refuel_shuttle(ship, "shuttle_bay"), "a healthy bay with fuel should allow refueling")

	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 0)
	assert_true(not MaintenanceCycle.can_refuel_shuttle(ship, "shuttle_bay"), "no fuel should block refueling")

	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	ship.get_console("shuttle_bay").damage()
	assert_true(not MaintenanceCycle.can_refuel_shuttle(ship, "shuttle_bay"), "a damaged bay cannot refuel")

func test_refuel_shuttle_spends_fuel_and_fuels_the_craft() -> void:
	var state := _build_state()
	var ship := state.get_ship("dione")
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	var craft_state := state.get_craft("philia")  # docked at Dione

	var refueled := MaintenanceCycle.refuel_shuttle(state, "dione", "philia", "shuttle_bay")

	assert_true(refueled, "refueling should succeed")
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL), 4, "should spend exactly 1 fuel")
	assert_true(craft_state.fuelled, "the craft should now be fuelled")

func test_refuel_shuttle_fails_for_undocked_craft() -> void:
	var state := _build_state()
	var ship := state.get_ship("dione")
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	# philia is docked at dione, not aegis
	var refueled := MaintenanceCycle.refuel_shuttle(state, "aegis", "philia", "shuttle_bay_zeta")
	assert_true(not refueled, "refueling a craft that isn't docked at the given ship should fail")
