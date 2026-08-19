extends TestCase

## The leak tests (docs/star_map_tv_display.md §9's "THE important
## file") - constraint 1/C1/C2's whole point rides on these passing.

func test_only_visited_nodes_carry_letter_name_class() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413")
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var nodes: Array = projection["nodes"]

	var with_letter: Array = nodes.filter(func(n: Dictionary) -> bool: return n.has("letter"))
	assert_eq(with_letter.size(), 2, "only 0000 and 1413 have been visited")

	for node: Dictionary in nodes:
		if node["id"] == "0000" or node["id"] == "1413":
			continue
		assert_true(not node.has("letter"), "%s hasn't been visited and must carry no letter key" % node["id"])
		assert_true(not node.has("name"), "%s hasn't been visited and must carry no name key" % node["id"])
		assert_true(not node.has("class"), "%s hasn't been visited and must carry no class key" % node["id"])
		assert_true(not node.has("consequence"), "%s hasn't been visited and must carry no consequence key" % node["id"])

func test_serialized_projection_never_contains_an_unvisited_systems_name() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413")
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var serialized := JSON.stringify(projection)

	# 4454 is chart A's "M" (Active Wolf Fortress) and has never been visited.
	assert_true(not serialized.contains("Active Wolf Fortress"), "an unvisited system's name must never appear anywhere in the serialized projection")
	assert_true(not serialized.contains("Ion Nebula"), "another unvisited system's name must never appear either")

func test_a_claim_round_trips_without_leaking_the_true_letter() -> void:
	var positions := FleetPositions.new()
	# 4454 is chart A's true "M" and is never visited.
	var reveal := RevealState.new()
	reveal.publish_claim("4454", "G - Level 5 Planet", "STARLIGHT", 3)
	var projection := StarMapProjection.build("A", 3, positions, reveal)
	var nodes: Array = projection["nodes"]
	var node: Dictionary = nodes.filter(func(n: Dictionary) -> bool: return n["id"] == "4454")[0]

	assert_eq(node["state"], "reported", "an unvisited node with a claim should read as reported")
	assert_eq(((node["claims"] as Array)[0] as Dictionary)["text"], "G - Level 5 Planet", "the claim text should round-trip unchanged")
	assert_true(not node.has("class"), "a claim must never cause the true class/letter to appear")
	assert_true(not node.has("letter"), "a claim must never cause the true letter to appear")

func test_forced_state_cannot_be_used_to_leak_a_letter() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	reveal.set_forced_state("4454", "visited") # host forces a display state, node never actually visited
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "4454")[0]

	assert_eq(node["state"], "visited", "the forced display state should still show")
	assert_true(not node.has("letter"), "forcing a display state must never attach real letter data the fleet hasn't actually earned")

func test_visited_node_carries_correct_letter_name_class() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413")
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "1413")[0]
	assert_eq(node["letter"], "A", "chart A's 1413 is system A")
	assert_eq(node["class"], "poor", "system A is a poor-rated system")
	assert_eq(node["state"], "occupied", "aegis is currently there")

func test_start_node_uses_the_literal_start_letter() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "0000")[0]
	assert_eq(node["letter"], "START", "0000's letter is the literal string START")
	assert_eq(node["state"], "occupied", "the whole fleet starts there")

func test_group_representative_has_colour_and_abbreviation() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	var groups: Array = projection["groups"]
	assert_eq(groups.size(), 1, "should start as one group")
	var representative: Dictionary = groups[0]["representative"]
	assert_eq(representative["abbr"], "AEG", "AEGIS's abbreviation should be AEG")
	assert_eq(representative["id"], "aegis", "representative should carry the raw unit id, not just display fields, for admin controls to act on")
	assert_true(String(representative["colour"]).begins_with("#"), "colour should be a hex string")
	assert_true(bool(representative["is_aegis"]), "the initial group's representative is AEGIS")

func test_ground_truth_reveals_every_node_regardless_of_visited_state() -> void:
	var positions := FleetPositions.new() # fleet never moves - only 0000 is visited
	var reveal := RevealState.new()
	var projection := StarMapProjection.build_ground_truth("A", 1, positions, reveal)
	var nodes: Array = projection["nodes"]
	var with_letter: Array = nodes.filter(func(n: Dictionary) -> bool: return n.has("letter"))
	assert_eq(with_letter.size(), 22, "ground truth should reveal every node's letter, visited or not")

func test_ground_truth_group_includes_raw_member_ids() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build_ground_truth("A", 1, positions, reveal)
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_true("aegis" in (group["member_ids"] as Array), "member_ids should carry raw unit ids for admin controls to act on")

func test_projection_includes_a_path_tree() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413")
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal)
	assert_eq(projection["path_tree"]["root"], StarChart.START, "the path tree's root should be 0000")
