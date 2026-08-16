extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_maliades_destroyed_at_exactly_three_damage() -> void:
	var state := _build_game_state()
	var maliades := state.get_craft("maliades")
	maliades.set_combat_damage(3)
	var ability := AbilityRegistry.get_ability("combat_table")

	var check := ability.can_execute(state, "maliades", {"range": 0})
	assert_true(not check.ok, "Maliades should be unavailable at exactly 3 damage")
	assert_eq(check.reason, "craft destroyed", "reason should say the craft is destroyed")

func test_maliades_not_destroyed_at_two_damage() -> void:
	var state := _build_game_state()
	state.get_craft("maliades").set_combat_damage(2)
	var ability := AbilityRegistry.get_ability("combat_table")
	assert_true(ability.can_execute(state, "maliades", {"range": 0}).ok, "Maliades at 2 damage should still be able to fight")

func test_fighter_wing_cannot_launch_with_uncharged_bay() -> void:
	var state := _build_game_state()
	# fresh fleet setup starts every console uncharged, so the bay is
	# already uncharged - no extra setup needed.
	var ability := AbilityRegistry.get_ability("combat_table")
	var check := ability.can_execute(state, "fighter_wing_alpha", {"range": 0})
	assert_true(not check.ok, "fighter wing should not launch with an uncharged bay")

func test_fighter_wing_cannot_launch_with_damaged_bay() -> void:
	var state := _build_game_state()
	var aegis := state.get_ship("aegis")
	aegis.get_console("fighter_bay_alpha").set_charged(true)
	aegis.get_console("fighter_bay_alpha").damage()
	var ability := AbilityRegistry.get_ability("combat_table")
	var check := ability.can_execute(state, "fighter_wing_alpha", {"range": 0})
	assert_true(not check.ok, "fighter wing should not launch from a damaged bay even if charged")

func test_fighter_wing_can_launch_with_a_charged_undamaged_bay() -> void:
	var state := _build_game_state()
	state.get_ship("aegis").get_console("fighter_bay_bravo").set_charged(true)
	var ability := AbilityRegistry.get_ability("combat_table")
	var check := ability.can_execute(state, "fighter_wing_alpha", {"range": 0})
	assert_true(check.ok, "Alpha should be able to launch from either Alpha or Bravo's bay")

func test_fighter_wing_can_still_join_away_mission_without_a_charged_bay() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("away_mission")
	var check := ability.can_execute(state, "fighter_wing_alpha", {})
	assert_true(check.ok, "fighter wings do not need a charged bay to fly away missions")

func test_highwall_requires_fuel_to_attend_combat_table() -> void:
	var state := _build_game_state()
	var ability := AbilityRegistry.get_ability("combat_table")
	assert_true(not ability.can_execute(state, "highwall", {"range": 0}).ok, "Highwall requires fuel to attend the combat table")
	state.get_craft("highwall").set_fuelled(true)
	assert_true(ability.can_execute(state, "highwall", {"range": 0}).ok, "Highwall should be able to fight once fuelled")

func test_highwall_deals_three_damage_on_a_hit() -> void:
	var state := _build_game_state()
	state.get_craft("highwall").set_fuelled(true)
	state.rng.seed = 1
	var ability := AbilityRegistry.get_ability("combat_table")
	var result := ability.execute(state, "highwall", {"range": 0})
	assert_true(result.ok, "should execute")
	var damage: int = result.data["damage_dealt"]
	assert_true(damage == 0 or damage == 3, "Highwall should deal either 0 or exactly 3 damage per die")
