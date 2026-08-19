extends TestCase

## The leak tests (docs/star_map_tv_display.md §9's "THE important
## file") - constraint 1/C1/C2's whole point rides on these passing.

func test_only_visited_nodes_carry_letter_name_class() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1)
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
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
		# ui/design_handoff_star_map §9's four additive fields - same
		# iff-visited rule as letter/name/class, extended per that doc's
		# own instruction.
		assert_true(not node.has("short_name"), "%s hasn't been visited and must carry no short_name key" % node["id"])
		assert_true(not node.has("consequence_summary"), "%s hasn't been visited and must carry no consequence_summary key" % node["id"])
		assert_true(not node.has("visited_turns"), "%s hasn't been visited and must carry no visited_turns key" % node["id"])
		assert_true(not node.has("left_turn"), "%s hasn't been visited and must carry no left_turn key" % node["id"])

func test_serialized_projection_never_contains_an_unvisited_systems_name() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1)
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var serialized := JSON.stringify(projection)

	# 4454 is chart A's "M" (Active Wolf Fortress) and has never been visited.
	assert_true(not serialized.contains("Active Wolf Fortress"), "an unvisited system's name must never appear anywhere in the serialized projection")
	assert_true(not serialized.contains("Ion Nebula"), "another unvisited system's name must never appear either")
	assert_true(not serialized.contains("WOLF FORTRESS"), "an unvisited system's short_name must never appear either")
	assert_true(not serialized.contains("ATTACK ON ARRIVAL"), "an unvisited system's consequence_summary must never appear either")

func test_a_claim_round_trips_without_leaking_the_true_letter() -> void:
	var positions := FleetPositions.new()
	# 4454 is chart A's true "M" and is never visited.
	var reveal := RevealState.new()
	reveal.publish_claim("4454", "G - Level 5 Planet", "STARLIGHT", 3)
	var projection := StarMapProjection.build("A", 3, positions, reveal, {}, {})
	var nodes: Array = projection["nodes"]
	var node: Dictionary = nodes.filter(func(n: Dictionary) -> bool: return n["id"] == "4454")[0]

	assert_eq(node["state"], "reported", "an unvisited node with a claim should read as reported")
	assert_eq(((node["claims"] as Array)[0] as Dictionary)["text"], "G - Level 5 Planet", "the claim text should round-trip unchanged")
	assert_true(not node.has("class"), "a claim must never cause the true class/letter to appear")
	assert_true(not node.has("letter"), "a claim must never cause the true letter to appear")
	assert_true(not node.has("short_name"), "a claim must never cause the true short_name to appear")
	assert_true(not node.has("consequence_summary"), "a claim must never cause the true consequence_summary to appear")

func test_forced_state_cannot_be_used_to_leak_a_letter() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	reveal.set_forced_state("4454", "visited") # host forces a display state, node never actually visited
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "4454")[0]

	assert_eq(node["state"], "visited", "the forced display state should still show")
	assert_true(not node.has("letter"), "forcing a display state must never attach real letter data the fleet hasn't actually earned")

func test_visited_node_carries_correct_letter_name_class() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1)
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "1413")[0]
	assert_eq(node["letter"], "A", "chart A's 1413 is system A")
	assert_eq(node["class"], "poor", "system A is a poor-rated system")
	assert_eq(node["state"], "occupied", "aegis is currently there")

func test_visited_node_carries_short_name_and_consequence_summary() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "4454", 1) # chart A's 4454 is "M", Active Wolf Fortress
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "4454")[0]
	assert_eq(node["short_name"], "WOLF FORTRESS", "M's short_name should be WOLF FORTRESS")
	assert_eq(node["consequence_summary"], "ATTACK ON ARRIVAL", "M has a real on-arrival consequence")

func test_visited_node_with_no_consequence_has_no_consequence_summary() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1) # chart A's 1413 is "A", no standing rule
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "1413")[0]
	assert_eq(node["short_name"], "LICHEN FIELD", "A's short_name should be LICHEN FIELD")
	assert_true(not node.has("consequence_summary"), "A has no standing rule and should carry no consequence_summary")

func test_occupied_node_has_visited_turns_but_no_left_turn() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 3)
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 3, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "1413")[0]
	assert_eq((node["visited_turns"] as Array), [3], "visited_turns should record the arrival turn")
	assert_true(not node.has("left_turn"), "left_turn should be omitted while the node is occupied - the rail shows who's here instead")

func test_departed_node_shows_left_turn() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 2)
	positions.move_unit("aegis", "5143", 5) # aegis moves on; 1413 is now visited but empty
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 5, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "1413")[0]
	assert_eq(node["state"], "visited", "1413 should be visited but no longer occupied")
	assert_eq((node["visited_turns"] as Array), [2], "visited_turns should still record when the fleet was there")
	assert_eq(node["left_turn"], 2, "left_turn should be visited_turns.back() once nobody is there")

func test_start_node_visited_turns_seeded_at_turn_zero() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "0000")[0]
	assert_eq((node["visited_turns"] as Array), [0], "0000 should be seeded as visited at turn 0")

func test_band_tint_true_for_a_lone_group() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_true(bool(group["band_tint"]), "a lone group should always win its own tier's band tint")

func test_band_tint_prefers_aegis_group_when_two_groups_share_a_tier() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "5143", 1) # aegis's group at tier 1
	positions.move_unit("icebreaker", "1413", 1) # icebreaker's own group, also tier 1
	# The other 5 units are still at 0000 (tier 0) as their own group -
	# uncontested there, so it also wins band_tint; that's correct and
	# not what this test is checking. Only icebreaker's group actually
	# shares a tier (1) with AEGIS's group.
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var groups: Array = projection["groups"]
	var aegis_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return bool((g["representative"] as Dictionary)["is_aegis"]))[0]
	var icebreaker_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return "Icebreaker" in (g["members"] as Array))[0]
	assert_true(bool(aegis_group["band_tint"]), "AEGIS's group should win the shared tier's tint")
	assert_true(not bool(icebreaker_group["band_tint"]), "icebreaker's group shares AEGIS's tier and should not also get the tint")

func test_scouts_list_the_craft_docked_on_a_group_member() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var craft: Dictionary = {
		"starlight": CraftState.new("starlight", "aegis"),
		"hummingbird": CraftState.new("hummingbird", "quellon"),
		"endeavour": CraftState.new("endeavour", "shepherd"),
	}
	var projection := StarMapProjection.build("A", 1, positions, reveal, craft, {})
	var group: Dictionary = (projection["groups"] as Array)[0] # everyone starts together
	var scouts: Array = group["scouts"]
	assert_eq(scouts.size(), 3, "all three scouts should be docked on ships in the one starting group")
	var labels: Array = scouts.map(func(s: Dictionary) -> String: return String(s["label"]))
	assert_true("STARLIGHT" in labels and "HUMMINGBIRD" in labels and "ENDEAVOUR" in labels, "every scout's label should be present")
	var endeavour: Dictionary = scouts.filter(func(s: Dictionary) -> bool: return s["label"] == "ENDEAVOUR")[0]
	assert_true(bool(endeavour.get("unlimited", false)), "Endeavour should be flagged unlimited, not given a jump count")
	var starlight: Dictionary = scouts.filter(func(s: Dictionary) -> bool: return s["label"] == "STARLIGHT")[0]
	assert_eq(int(starlight["jumps"]), 2, "Starlight's range should be 2 jumps")

func test_scouts_follow_a_redeployed_craft_to_its_new_group() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("icebreaker", "1413", 1) # icebreaker splits into its own group
	var reveal := RevealState.new()
	var craft: Dictionary = {
		"starlight": CraftState.new("starlight", "aegis"),
	}
	(craft["starlight"] as CraftState).set_docked_ship("icebreaker") # redeployed
	var projection := StarMapProjection.build("A", 1, positions, reveal, craft, {})
	var groups: Array = projection["groups"]
	var icebreaker_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return "Icebreaker" in (g["members"] as Array))[0]
	var aegis_group: Dictionary = groups.filter(func(g: Dictionary) -> bool: return bool((g["representative"] as Dictionary)["is_aegis"]))[0]
	assert_eq((icebreaker_group["scouts"] as Array).size(), 1, "Starlight should follow its craft's live docked ship, not its original home ship")
	assert_true((aegis_group["scouts"] as Array).is_empty(), "AEGIS's group should no longer list a scout that redeployed away")

func test_start_node_uses_the_literal_start_letter() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var node: Dictionary = (projection["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["id"] == "0000")[0]
	assert_eq(node["letter"], "START", "0000's letter is the literal string START")
	assert_eq(node["state"], "occupied", "the whole fleet starts there")

func test_group_representative_has_colour_and_abbreviation() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var groups: Array = projection["groups"]
	assert_eq(groups.size(), 1, "should start as one group")
	var representative: Dictionary = groups[0]["representative"]
	assert_eq(representative["abbr"], "AEG", "AEGIS's abbreviation should be AEG")
	assert_eq(representative["id"], "aegis", "representative should carry the raw unit id, not just display fields, for admin controls to act on")
	assert_true(String(representative["colour"]).begins_with("#"), "colour should be a hex string")
	assert_true(bool(representative["is_aegis"]), "the initial group's representative is AEGIS")

func test_group_has_no_damaged_members_by_default() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var ships: Dictionary = {"aegis": Ship.new("aegis")}
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, ships)
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_true((group["damaged_member_ids"] as Array).is_empty(), "a group with no damaged ships should report an empty list")

func test_group_reports_a_damaged_member() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var aegis := Ship.new("aegis")
	aegis.add_console("engines")
	aegis.get_console("engines").damage()
	var ships: Dictionary = {"aegis": aegis}
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, ships)
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_eq((group["damaged_member_ids"] as Array), ["aegis"], "a group with one damaged ship should report just that unit id")

func test_voyage_33_0_never_counts_as_damaged_since_it_has_no_ship_object() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	# No "voyage_33_0" entry in ships at all - matches reality, since
	# Small Ships aren't modeled as Ship objects anywhere in core/ yet.
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_true("voyage_33_0" in (group["member_ids"] as Array), "voyage_33_0 should still be a member")
	assert_true(not ("voyage_33_0" in (group["damaged_member_ids"] as Array)), "voyage_33_0 should never be flagged damaged - there's no Ship object to check")

func test_ground_truth_reveals_every_node_regardless_of_visited_state() -> void:
	var positions := FleetPositions.new() # fleet never moves - only 0000 is visited
	var reveal := RevealState.new()
	var projection := StarMapProjection.build_ground_truth("A", 1, positions, reveal, {}, {})
	var nodes: Array = projection["nodes"]
	var with_letter: Array = nodes.filter(func(n: Dictionary) -> bool: return n.has("letter"))
	assert_eq(with_letter.size(), 22, "ground truth should reveal every node's letter, visited or not")

func test_ground_truth_group_includes_raw_member_ids() -> void:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	var projection := StarMapProjection.build_ground_truth("A", 1, positions, reveal, {}, {})
	var group: Dictionary = (projection["groups"] as Array)[0]
	assert_true("aegis" in (group["member_ids"] as Array), "member_ids should carry raw unit ids for admin controls to act on")

func test_projection_includes_a_path_tree() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1)
	var reveal := RevealState.new()
	var projection := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	assert_eq(projection["path_tree"]["root"], StarChart.START, "the path tree's root should be 0000")
