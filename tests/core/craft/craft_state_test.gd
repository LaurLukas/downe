extends TestCase

func test_clear_turn_state_clears_fuel_regardless_of_use() -> void:
	var state := CraftState.new("test_craft", "aegis")
	state.set_fuelled(true)
	state.clear_turn_state()
	assert_true(not state.fuelled, "fuel should clear at end of turn whether or not it was spent")

func test_clear_turn_state_clears_use_counts() -> void:
	var state := CraftState.new("test_craft", "aegis")
	state.record_use("scout_system")
	state.record_use("scout_system")
	state.clear_turn_state()
	assert_eq(state.get_uses("scout_system"), 0, "per-turn use counts should clear at end of turn")

func test_record_use_increments() -> void:
	var state := CraftState.new("test_craft", "aegis")
	state.record_use("mining_operations")
	state.record_use("mining_operations")
	assert_eq(state.get_uses("mining_operations"), 2, "record_use should increment the per-ability counter")

func test_starts_docked_at_home_ship() -> void:
	var state := CraftState.new("test_craft", "icebreaker")
	assert_eq(state.docked_ship_id, "icebreaker", "a new CraftState should start docked at its home ship")
