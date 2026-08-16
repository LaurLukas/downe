extends TestCase

func _build_game_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_populates_all_seventeen_craft() -> void:
	var state := _build_game_state()
	assert_eq(state.craft.size(), 17, "should seed all 17 craft")

func test_craft_start_docked_at_home_ship() -> void:
	var state := _build_game_state()
	assert_eq(state.get_craft("highwall").docked_ship_id, "icebreaker", "Highwall should start docked at the Icebreaker")

func test_craft_start_unfuelled_and_empty() -> void:
	var state := _build_game_state()
	var philia := state.get_craft("philia")
	assert_true(not philia.fuelled, "craft should start unfuelled (resources.md: not specified, assume empty/unfuelled)")
	assert_eq(philia.cargo.get_amount(ResourceStock.Kind.FOOD), 0, "craft should start with empty cargo")

func test_fighter_wings_start_at_four_fighters() -> void:
	var state := _build_game_state()
	assert_eq(state.get_craft("fighter_wing_alpha").fighter_count, 4, "fighter wings should start full (unconfirmed default, see TODO.md)")

func test_non_fighter_craft_have_zero_fighter_count() -> void:
	var state := _build_game_state()
	assert_eq(state.get_craft("highwall").fighter_count, 0, "non-fighter-wing craft should not have a fighter count")
