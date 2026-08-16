extends TestCase

func test_builds_exactly_six_ships() -> void:
	var state := FleetSetup.build_starting_fleet()
	assert_eq(state.ships.size(), 6, "the starting fleet should have exactly 6 ships")

func test_aegis_starting_resources_match_the_source() -> void:
	var aegis := FleetSetup.build_ship("aegis")
	assert_eq(aegis.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL), 4, "AEGIS should start with 4 strytium fuel")
	assert_eq(aegis.resources.get_amount(ResourceStock.Kind.FOOD), 8, "AEGIS should start with 8 food")
	assert_eq(aegis.resources.get_amount(ResourceStock.Kind.SECURITY_TEAMS), 9, "AEGIS should start with 9 security teams")

func test_only_refinery_124_starts_with_strytium_ore() -> void:
	var state := FleetSetup.build_starting_fleet()
	for ship_id: String in state.ships:
		var ore := state.get_ship(ship_id).resources.get_amount(ResourceStock.Kind.STRYTIUM_ORE)
		if ship_id == "refinery_124":
			assert_eq(ore, 12, "Refinery 124 should start with 12 strytium ore")
		else:
			assert_eq(ore, 0, "%s should start with 0 strytium ore" % ship_id)

func test_starting_population_sets_both_current_and_max() -> void:
	var dione := FleetSetup.build_ship("dione")
	assert_eq(dione.survivor_population, 100000, "Dione should start at 100,000 survivors")
	assert_eq(dione.max_survivor_population, 100000, "starting population is also the evacuation ceiling")

func test_fleet_total_population_matches_source() -> void:
	var state := FleetSetup.build_starting_fleet()
	var total := 0
	for ship_id: String in state.ships:
		total += state.get_ship(ship_id).survivor_population
	assert_eq(total, 222500, "fleet total starting population should be 222,500")

func test_aegis_has_its_full_console_roster() -> void:
	var aegis := FleetSetup.build_ship("aegis")
	assert_eq(aegis.consoles.size(), 13, "AEGIS should have 13 consoles")
	assert_true(aegis.get_console("shuttle_bay_omega") != null, "AEGIS should have a Shuttle Bay Omega console")

func test_consoles_start_undamaged_and_uncharged() -> void:
	var aegis := FleetSetup.build_ship("aegis")
	for console_id: String in aegis.consoles:
		var console: Console = aegis.consoles[console_id]
		assert_eq(console.state, Console.State.OK, "%s should start undamaged" % console_id)
		assert_true(not console.charged, "%s should start uncharged" % console_id)

func test_unrest_starts_at_zero() -> void:
	var ship := FleetSetup.build_ship("shepherd")
	assert_eq(ship.unrest, 0, "unrest should start at 0")

func test_scout_capable_ships_still_flagged() -> void:
	var quellon := FleetSetup.build_ship("quellon")
	assert_true(quellon.can_scout, "Quellon should be scout-capable (docks the Hummingbird)")
	var icebreaker := FleetSetup.build_ship("icebreaker")
	assert_true(not icebreaker.can_scout, "Icebreaker has no scout craft docked")
