extends TestCase

func test_identical_trails_produce_one_branch() -> void:
	var trail: Array = ["0000", "1413", "6837", "6931"]
	var trails := {}
	var unit_group := {}
	for unit_id in ["aegis", "dione", "icebreaker", "shepherd", "quellon", "refinery_124", "voyage_33_0"]:
		trails[unit_id] = trail.duplicate()
		unit_group[unit_id] = "g1"
	var tree := PathTree.build(trails, unit_group, "g1")
	var branches: Array = tree["branches"]
	assert_eq(branches.size(), 1, "seven identical trails should collapse to one branch")
	assert_eq((branches[0]["nodes"] as Array), trail, "the branch should cover the whole shared path")
	assert_eq(branches[0]["state"], "live", "the branch should be live - it's on the current position's path")
	assert_true(bool(branches[0]["primary"]), "the branch carrying AEGIS's group should be marked primary")

func test_a_divergent_trail_forks_sharing_the_prefix_exactly_once() -> void:
	var trails := {
		"aegis": ["0000", "1413", "6837", "6931"],
		"dione": ["0000", "1413", "6837", "4454"],
	}
	var unit_group := {"aegis": "g1", "dione": "g2"}
	var tree := PathTree.build(trails, unit_group, "g1")
	var branches: Array = tree["branches"]
	assert_eq(branches.size(), 3, "shared trunk plus two divergent tips")

	var trunk: Array = branches.filter(func(b: Dictionary) -> bool: return (b["nodes"] as Array) == ["0000", "1413", "6837"])
	assert_eq(trunk.size(), 1, "the shared prefix should be drawn exactly once as its own branch")

	var to_6931: Array = branches.filter(func(b: Dictionary) -> bool: return (b["nodes"] as Array) == ["6837", "6931"])
	var to_4454: Array = branches.filter(func(b: Dictionary) -> bool: return (b["nodes"] as Array) == ["6837", "4454"])
	assert_eq(to_6931.size(), 1, "aegis's own continuation should be its own branch")
	assert_eq(to_4454.size(), 1, "dione's continuation should be its own branch")
	assert_true(bool(to_6931[0]["primary"]), "the AEGIS-carrying fork should be primary")
	assert_true(not bool(to_4454[0]["primary"]), "the non-AEGIS fork should not be primary")

func test_merge_produces_convergence_and_one_dead_abandoned_branch() -> void:
	var trails := {
		"aegis": ["0000", "1413", "6837", "6931"],
		"dione": ["0000", "1413", "6837", "4454", "6837", "6931"],
	}
	var unit_group := {"aegis": "g1", "dione": "g1"} # merged back into the same group
	var tree := PathTree.build(trails, unit_group, "g1")
	var branches: Array = tree["branches"]
	assert_eq(branches.size(), 3, "shared trunk, shared final leg, and one dead detour")

	var dead: Array = branches.filter(func(b: Dictionary) -> bool: return b["state"] == "dead")
	assert_eq(dead.size(), 1, "the abandoned detour should appear exactly once")
	assert_eq((dead[0]["nodes"] as Array), ["6837", "4454"], "the dead branch should be the detour to 4454")

	var live: Array = branches.filter(func(b: Dictionary) -> bool: return b["state"] == "live")
	assert_eq(live.size(), 2, "the shared trunk and the shared final leg should both be live")
	for branch: Dictionary in live:
		assert_true(bool(branch["primary"]), "both live segments carry AEGIS, so both are primary")

func test_root_is_included_in_the_output() -> void:
	var trails := {"aegis": ["0000"]}
	var tree := PathTree.build(trails, {"aegis": "g1"}, "g1")
	assert_eq(tree["root"], StarChart.START, "the root should always be 0000")
	assert_eq((tree["branches"] as Array).size(), 0, "a unit that has never moved has no branches to draw")
