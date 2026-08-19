extends TestCase

func test_initial_state_is_one_group_at_start() -> void:
	var positions := FleetPositions.new()
	var groups := positions.groups()
	assert_eq(groups.size(), 1, "should start as one group")
	assert_eq(groups[0]["label"], "MAIN FLEET", "initial group should be MAIN FLEET")
	assert_eq(groups[0]["representative"], "aegis", "initial representative should be AEGIS")
	assert_eq(groups[0]["at"], StarChart.START, "should start at 0000")
	assert_eq((groups[0]["members"] as Array).size(), 7, "should have all 7 units")
	assert_eq((positions.visited_turns[StarChart.START] as Array), [0], "0000 should be seeded as visited at turn 0")

func test_move_unit_records_the_arrival_turn() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 4)
	assert_eq((positions.visited_turns["1413"] as Array), [4], "moving to a node should record the turn it happened")

func test_move_unit_does_not_duplicate_the_same_turn() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 4)
	positions.move_unit("dione", "1413", 4) # a second unit, same turn
	assert_eq((positions.visited_turns["1413"] as Array), [4], "two arrivals in the same turn should not duplicate the entry")

func test_visited_turns_accumulates_across_separate_visits() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 2)
	positions.move_unit("aegis", "5143", 3)
	positions.move_unit("aegis", "1413", 5) # returns later
	assert_eq((positions.visited_turns["1413"] as Array), [2, 5], "returning to a node on a later turn should append, not replace")

func test_sync_global_pursuit_updates_the_unsplit_group() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(4)
	assert_eq(positions.groups()[0]["pursuit"], 4, "the unsplit group should track the global pursuit value")

func test_non_aegis_unit_splitting_off_forms_a_new_group() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(4)
	positions.move_unit("icebreaker", "1413", 1)
	var groups := positions.groups()
	assert_eq(groups.size(), 2, "should now be two groups")

	var main_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return "aegis" in (g["members"] as Array))[0]
	var split_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return not ("aegis" in (g["members"] as Array)))[0]

	assert_eq(main_group["label"], "MAIN FLEET", "AEGIS's group keeps its identity")
	assert_eq(main_group["id"], "g1", "AEGIS's group keeps its original id")
	assert_eq(split_group["label"], "GROUP 2", "the split-off group gets a fresh label")
	assert_eq(split_group["representative"], "icebreaker", "a lone split-off unit represents itself")
	assert_eq(split_group["pursuit"], 4, "the split-off group's pursuit is seeded from the value at the moment of the split")
	assert_eq((split_group["members"] as Array), ["icebreaker"], "the split-off group has just the one unit")

func test_aegis_splitting_off_alone_keeps_the_main_fleet_identity() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(6)
	positions.move_unit("aegis", "5143", 1)
	var groups := positions.groups()
	assert_eq(groups.size(), 2, "should now be two groups")

	var aegis_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return g["representative"] == "aegis")[0]
	var remainder_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return g["representative"] != "aegis")[0]

	assert_eq(aegis_group["id"], "g1", "AEGIS keeps the original group id")
	assert_eq(aegis_group["label"], "MAIN FLEET", "AEGIS keeps the MAIN FLEET label")
	assert_eq(aegis_group["pursuit"], 6, "AEGIS's group keeps the pursuit value from the moment of the split")
	assert_eq(remainder_group["label"], "GROUP 2", "the units left behind get a fresh identity")
	assert_eq(remainder_group["representative"], "dione", "remainder's representative follows the selection order")
	assert_true("shepherd" in (remainder_group["members"] as Array), "the remainder should include the other capital ships")

func test_split_groups_stop_tracking_global_pursuit() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(3)
	positions.move_unit("icebreaker", "1413", 1)
	positions.sync_global_pursuit(9) # simulate a later maintenance +2 etc on the legacy track
	for group: Dictionary in positions.groups():
		assert_eq(group["pursuit"], 3, "once split, a group should no longer move with the legacy global pursuit track")

func test_merge_survivor_is_the_group_containing_aegis() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(2)
	positions.move_unit("icebreaker", "1413", 1)
	var split_group_id: String = positions.groups().filter(func(g: Dictionary) -> bool: return g["representative"] == "icebreaker")[0]["id"]
	positions.set_group_pursuit(split_group_id, 5)
	positions.move_unit("icebreaker", StarChart.START, 1)

	var groups := positions.groups()
	assert_eq(groups.size(), 1, "should be back to one group after the merge")
	var merged: Dictionary = groups[0]
	assert_eq(merged["id"], "g1", "AEGIS's group should be the merge survivor")
	assert_eq(merged["label"], "MAIN FLEET", "the survivor keeps its label")
	assert_eq((merged["pending_merge_pursuits"] as Array), [5], "the absorbed group's pursuit should be stashed for host reconciliation, not auto-resolved")

func test_merge_of_two_non_aegis_groups_survivor_is_the_mover() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("icebreaker", "1413", 1)
	positions.move_unit("shepherd", "1413", 1)
	var groups := positions.groups()
	assert_eq(groups.size(), 2, "aegis's group plus the merged pair")
	var merged: Dictionary = groups.filter(func(g: Dictionary) -> bool: return g["representative"] != "aegis")[0]
	assert_eq((merged["members"] as Array).size(), 2, "icebreaker and shepherd should now be in one group")
	assert_true("icebreaker" in (merged["members"] as Array) and "shepherd" in (merged["members"] as Array), "both units should be members")

func test_reconcile_group_pursuit_resolves_and_clears_pending() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("icebreaker", "1413", 1)
	var split_group_id: String = positions.groups().filter(func(g: Dictionary) -> bool: return g["representative"] == "icebreaker")[0]["id"]
	positions.set_group_pursuit(split_group_id, 5)
	positions.move_unit("icebreaker", StarChart.START, 1)

	var merged_id: String = positions.groups()[0]["id"]
	positions.reconcile_group_pursuit(merged_id, 7)
	var merged := positions.groups()[0]
	assert_eq(merged["pursuit"], 7, "reconciling should set the resolved value")
	assert_true((merged["pending_merge_pursuits"] as Array).is_empty(), "reconciling should clear the pending list")

func test_representative_cannot_be_reassigned_away_from_aegis() -> void:
	var positions := FleetPositions.new()
	var group_id: String = positions.groups()[0]["id"]
	positions.set_group_representative(group_id, "dione")
	assert_eq(positions.groups()[0]["representative"], "aegis", "AEGIS's group must always be represented by AEGIS")

func test_representative_can_be_reassigned_within_a_non_aegis_group() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "5143", 1) # aegis leaves; remainder is a non-AEGIS group
	var remainder_id: String = positions.groups().filter(func(g: Dictionary) -> bool: return g["representative"] != "aegis")[0]["id"]
	positions.set_group_representative(remainder_id, "shepherd")
	var remainder: Dictionary = positions.groups().filter(func(g: Dictionary) -> bool: return g["id"] == remainder_id)[0]
	assert_eq(remainder["representative"], "shepherd", "the host should be able to reassign a non-AEGIS group's representative")

func test_undo_last_move_restores_previous_position() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "5143", 1)
	positions.undo_last_move("aegis", 1)
	assert_eq(positions.positions["aegis"], StarChart.START, "undo should restore the previous position")
	assert_eq((positions.trails["aegis"] as Array).size(), 1, "undo should pop the trail entry, not just reset the position")

func test_undo_last_move_is_a_no_op_with_no_history() -> void:
	var positions := FleetPositions.new()
	positions.undo_last_move("aegis", 1)
	assert_eq(positions.positions["aegis"], StarChart.START, "undo with no history should do nothing")

func test_fleet_relocating_one_unit_at_a_time_ends_as_one_group_tracking_global_again() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(1)
	for unit_id in FleetPositions.unit_ids():
		positions.move_unit(unit_id, "1413", 1)
	positions.sync_global_pursuit(3)
	var groups := positions.groups()
	assert_eq(groups.size(), 1, "moving every unit to the same node should end as one group, even if each move was reported separately")
	assert_eq(groups[0]["pursuit"], 3, "once every unit is back in one group, it should resume tracking the live global pursuit value")
	assert_eq(groups[0]["at"], "1413", "the group's node should follow the moves")

func test_to_dict_and_from_dict_round_trip() -> void:
	var positions := FleetPositions.new()
	positions.sync_global_pursuit(4)
	positions.move_unit("icebreaker", "1413", 1)
	positions.set_group_label(positions.groups()[0]["id"], "MAIN FLEET (custom)")

	var restored := FleetPositions.from_dict(positions.to_dict())
	assert_eq(restored.positions["icebreaker"], "1413", "positions should round-trip")
	assert_eq((restored.trails["icebreaker"] as Array), [StarChart.START, "1413"], "trails should round-trip")
	assert_eq(restored.groups().size(), 2, "group count should round-trip")
	assert_eq((restored.visited_turns["1413"] as Array), [1], "visited_turns should round-trip")
