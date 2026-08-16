extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_starting_team_phase_does_not_clear_anything() -> void:
	# TurnManager starts at turn 1, TEAM phase, without ever emitting
	# phase_changed - a fresh GameState should not wipe the state
	# FleetSetup/CraftSetup just built.
	var state := _build_game_state()
	state.get_ship("aegis").get_console("reactor").set_charged(true)
	assert_true(state.get_ship("aegis").get_console("reactor").charged, "startup should not have cleared anything")

func test_advancing_into_a_new_team_phase_clears_console_charge() -> void:
	var state := _build_game_state()
	var console := state.get_ship("aegis").get_console("reactor")
	console.set_charged(true)

	state.turn_manager.advance()  # TEAM -> COORDINATION
	state.turn_manager.advance()  # COORDINATION -> TEAM (turn 2)

	assert_true(not console.charged, "unused console charge should be lost entering a new Team Phase")

func test_advancing_into_a_new_team_phase_clears_craft_fuel() -> void:
	var state := _build_game_state()
	var craft_state := state.get_craft("philia")
	craft_state.set_fuelled(true)

	state.turn_manager.advance()
	state.turn_manager.advance()

	assert_true(not craft_state.fuelled, "unused craft fuel should be lost entering a new Team Phase")

func test_advancing_within_the_same_turn_does_not_clear_state() -> void:
	var state := _build_game_state()
	var craft_state := state.get_craft("philia")
	craft_state.set_fuelled(true)

	state.turn_manager.advance()  # TEAM -> COORDINATION, same turn

	assert_true(craft_state.fuelled, "entering Coordination Phase should not clear fuel - only a new Team Phase does")
