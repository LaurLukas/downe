extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_redeploy_fails_with_correct_reason_when_unfuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("redeploy")
	var check := ability.can_execute(state, "pallas", {"target_ship_id": "dione"})
	assert_true(not check.ok, "redeploy should require fuel")
	assert_eq(check.reason, "not fuelled", "the reason should say exactly why")

func test_redeploy_moves_craft_when_fuelled() -> void:
	var state := _build_game_state()
	state.get_craft("pallas").set_fuelled(true)
	var ability := AbilityRegistry.get_ability("redeploy")
	var result := ability.execute(state, "pallas", {"target_ship_id": "dione"})
	assert_true(result.ok, "redeploy should succeed when fuelled")
	assert_eq(state.get_craft("pallas").docked_ship_id, "dione", "craft should now be docked at the target ship")

func test_recharge_fails_with_correct_reason_when_unfuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("recharge")
	var check := ability.can_execute(state, "condor", {"ship_id": "quellon", "console_id": "reactor"})
	assert_true(not check.ok, "recharge should require fuel")
	assert_eq(check.reason, "not fuelled", "the reason should say exactly why")

func test_recharge_sets_console_charged_when_fuelled() -> void:
	var state := _build_game_state()
	state.get_craft("condor").set_fuelled(true)
	var ability := AbilityRegistry.get_ability("recharge")
	var result := ability.execute(state, "condor", {"ship_id": "quellon", "console_id": "reactor"})
	assert_true(result.ok, "recharge should succeed when fuelled")
	assert_true(state.get_ship("quellon").get_console("reactor").charged, "console should now be charged")

func test_recharge_rejects_a_damaged_console() -> void:
	var state := _build_game_state()
	state.get_craft("condor").set_fuelled(true)
	state.get_ship("quellon").get_console("reactor").damage()
	var ability := AbilityRegistry.get_ability("recharge")
	assert_true(not ability.can_execute(state, "condor", {"ship_id": "quellon", "console_id": "reactor"}).ok, "should not be able to charge a damaged console")

func test_scout_system_records_report_verbatim() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("scout_system")
	ability.execute(state, "starlight", {"report": "definitely not a trap, 9997"})
	assert_eq(state.get_craft("starlight").scout_report, "definitely not a trap, 9997", "scout report should be stored exactly as given, never validated")

func test_scout_system_enforces_one_use_per_turn_unfuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("scout_system")
	assert_true(ability.execute(state, "hummingbird", {"report": "A"}).ok, "1st scout should succeed")
	assert_true(not ability.can_execute(state, "hummingbird", {"report": "B"}).ok, "2nd scout should be unavailable - Hummingbird gets no fuel extension")

func test_starlight_gets_a_second_scout_use_when_fuelled() -> void:
	var state := _build_game_state()
	state.get_craft("starlight").set_fuelled(true)
	var ability := AbilityRegistry.get_ability("scout_system")
	assert_true(ability.execute(state, "starlight", {"report": "A"}).ok, "1st scout should succeed")
	assert_true(ability.execute(state, "starlight", {"report": "B"}).ok, "2nd scout should succeed when fuelled")
	assert_true(not ability.can_execute(state, "starlight", {"report": "C"}).ok, "3rd scout should be unavailable even fuelled")

func test_console_upgrade_endeavour_caps_at_two_unfuelled_four_fuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("console_upgrade")
	var over_cap := ability.can_execute(state, "endeavour", {
		"ship_id": "shepherd", "console_ids": ["storage", "reactor", "shuttle_bay"],
	})
	assert_true(not over_cap.ok, "should not be able to upgrade 3 consoles unfuelled")

	state.get_craft("endeavour").set_fuelled(true)
	var within_fuelled_cap := ability.can_execute(state, "endeavour", {
		"ship_id": "shepherd", "console_ids": ["storage", "reactor", "shuttle_bay"],
	})
	assert_true(within_fuelled_cap.ok, "should be able to upgrade 3 consoles when fuelled (cap is 4)")

func test_console_upgrade_increments_upgrade_level() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("console_upgrade")
	ability.execute(state, "endeavour", {"ship_id": "shepherd", "console_ids": ["reactor"]})
	assert_eq(state.get_ship("shepherd").get_console("reactor").upgrade_level, 1, "upgrade_level should increment")

func test_resource_harvesting_fails_with_correct_reason_when_unfuelled() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("resource_harvesting")
	var check := ability.can_execute(state, "hummingbird", {})
	assert_true(not check.ok, "resource harvesting should require fuel")
	assert_eq(check.reason, "not fuelled", "the reason should say exactly why")

func test_resource_harvesting_splits_two_dice_between_food_and_water() -> void:
	var state := _build_game_state()
	state.get_craft("hummingbird").set_fuelled(true)
	state.rng.seed = 42
	var quellon := state.get_ship("quellon")
	var starting_food := quellon.resources.get_amount(ResourceStock.Kind.FOOD)
	var starting_water := quellon.resources.get_amount(ResourceStock.Kind.WATER)
	var ability := AbilityRegistry.get_ability("resource_harvesting")

	var result := ability.execute(state, "hummingbird", {})

	assert_true(result.ok, "should succeed when fuelled")
	var food_gained: int = result.data["food"]
	var water_gained: int = result.data["water"]
	assert_true(food_gained >= 1 and food_gained <= 6, "food die should be 1-6")
	assert_true(water_gained >= 1 and water_gained <= 6, "water die should be 1-6")
	assert_eq(quellon.resources.get_amount(ResourceStock.Kind.FOOD), starting_food + food_gained, "food should be added to the docked ship")
	assert_eq(quellon.resources.get_amount(ResourceStock.Kind.WATER), starting_water + water_gained, "water should be added to the docked ship")

func test_boarding_support_applies_the_boarding_defence_table() -> void:
	var state := _build_game_state()
	var refinery := state.get_ship("refinery_124")
	refinery.resources.set_amount(ResourceStock.Kind.SECURITY_TEAMS, 6)
	var ability := AbilityRegistry.get_ability("boarding_support")

	var result := ability.execute(state, "chacau", {"team_count": 6})

	assert_true(result.ok, "should succeed with enough security teams")
	var teams_lost: int = result.data["teams_lost"]
	assert_eq(refinery.resources.get_amount(ResourceStock.Kind.SECURITY_TEAMS), 6 - teams_lost, "security teams lost should be deducted from the ship")

func test_boarding_support_rejects_more_teams_than_available() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("boarding_support")
	var check := ability.can_execute(state, "chacau", {"team_count": 999})
	assert_true(not check.ok, "should not be able to commit more security teams than the ship has")

func test_away_mission_reports_the_craft_bonus() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("away_mission")
	var result := ability.execute(state, "highwall", {"skill": AwayMissionOpportunity.Skill.MINING})
	assert_true(result.ok, "should succeed")
	assert_eq(result.data["bonus"], 3, "Highwall's mining bonus should be +3")

func test_away_mission_reports_zero_for_an_unrelated_skill() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("away_mission")
	var result := ability.execute(state, "highwall", {"skill": AwayMissionOpportunity.Skill.SCIENCE})
	assert_eq(result.data["bonus"], 0, "Highwall has no science bonus")

func test_maliades_has_no_away_mission_ability() -> void:
	var definition := CraftDefinitions.get_definition("maliades")
	assert_true(not definition.ability_ids.has("away_mission"), "Maliades is a pure combat escort with no away-mission role")
