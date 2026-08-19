extends TestCase

func test_starlight_jump_range() -> void:
	assert_eq(ScoutRanges.jumps_for("starlight"), 2, "Starlight's range should be 2 jumps")
	assert_true(not ScoutRanges.is_unlimited("starlight"), "Starlight should not be unlimited")

func test_hummingbird_jump_range() -> void:
	assert_eq(ScoutRanges.jumps_for("hummingbird"), 3, "Hummingbird's range should be 3 jumps")

func test_endeavour_is_unlimited() -> void:
	assert_true(ScoutRanges.is_unlimited("endeavour"), "Endeavour should be flagged unlimited")

func test_all_scout_craft_ids_lists_exactly_the_three_scouts() -> void:
	var ids := ScoutRanges.all_scout_craft_ids()
	assert_eq(ids.size(), 3, "there should be exactly 3 scout craft")
	for expected in ["starlight", "hummingbird", "endeavour"]:
		assert_true(expected in ids, "%s should be listed as a scout" % expected)

func test_label_for_unknown_craft_falls_back_to_uppercased_id() -> void:
	assert_eq(ScoutRanges.label_for("not_a_scout"), "NOT_A_SCOUT", "an unrecognized craft id should fall back to its uppercased id")
