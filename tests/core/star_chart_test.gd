extends TestCase

## The source doc explicitly asks for this: "Add a test that asserts
## the adjacency list is symmetric" - a missed line in the transcribed
## edge list would silently break scout range checks
## (open_questions_answered.md §1.1). This test can catch a
## transcription error that breaks symmetry; it cannot catch one that
## doesn't (a wrong-but-symmetric edge) - re-check against the printed
## chart before relying on this for a real game.

func test_edges_are_symmetric() -> void:
	for coordinate: String in StarChart.EDGES:
		for neighbor: String in StarChart.EDGES[coordinate]:
			var back_edges: Array = StarChart.EDGES.get(neighbor, [])
			assert_true(coordinate in back_edges, "%s lists %s as a neighbor, but %s doesn't list %s back" % [coordinate, neighbor, neighbor, coordinate])

func test_edge_count_matches_source_doc() -> void:
	var directed_count := 0
	for coordinate: String in StarChart.EDGES:
		directed_count += StarChart.EDGES[coordinate].size()
	assert_eq(directed_count / 2, 41, "the source doc states 41 edges; each undirected edge appears twice in the directed listing")

func test_node_count_matches_source_doc() -> void:
	assert_eq(StarChart.all_coordinates().size(), 22, "the source doc states 22 nodes: 0000 plus 21 lettered systems")

func test_every_edge_target_is_a_known_node() -> void:
	var known := StarChart.all_coordinates()
	for coordinate: String in StarChart.EDGES:
		assert_true(coordinate in known, "%s appears as an edge source but isn't in all_coordinates()" % coordinate)
		for neighbor: String in StarChart.EDGES[coordinate]:
			assert_true(neighbor in known, "%s lists unknown neighbor %s" % [coordinate, neighbor])

func test_graph_is_fully_connected() -> void:
	# Not stated explicitly in the source, but a disconnected node would
	# mean an unreachable star system, which would itself be a
	# transcription red flag worth catching.
	for coordinate: String in StarChart.all_coordinates():
		if coordinate == StarChart.START:
			continue
		assert_true(StarChart.graph_distance(StarChart.START, coordinate) != -1, "%s should be reachable from 0000" % coordinate)

func test_each_chart_assigns_every_non_start_node() -> void:
	for chart: String in ["A", "B", "C"]:
		for coordinate: String in StarChart.PURSUIT_BAND:
			var letter := StarChart.system_letter_at(chart, coordinate)
			assert_true(not letter.is_empty(), "chart %s should assign a letter to every non-start node, missing %s" % [chart, coordinate])

func test_chart_a_omits_b() -> void:
	assert_eq(StarChart.coordinate_of_system("A", "B"), "", "chart A should have no system B")

func test_chart_b_omits_a_c_d() -> void:
	assert_eq(StarChart.coordinate_of_system("B", "A"), "", "chart B should have no system A")
	assert_eq(StarChart.coordinate_of_system("B", "C"), "", "chart B should have no system C")
	assert_eq(StarChart.coordinate_of_system("B", "D"), "", "chart B should have no system D")

func test_chart_c_omits_a_b() -> void:
	assert_eq(StarChart.coordinate_of_system("C", "A"), "", "chart C should have no system A")
	assert_eq(StarChart.coordinate_of_system("C", "B"), "", "chart C should have no system B")

func test_new_eden_candidates_appear_on_every_chart() -> void:
	for chart: String in ["A", "B", "C"]:
		for letter in ["N", "O", "P"]:
			assert_true(StarChart.coordinate_of_system(chart, letter) != "", "N/O/P should appear on every chart - chart %s is missing %s" % [chart, letter])

func test_new_eden_candidates_are_in_the_far_bands() -> void:
	for chart: String in ["A", "B", "C"]:
		for letter in ["N", "O", "P"]:
			var coordinate := StarChart.coordinate_of_system(chart, letter)
			var band := StarChart.pursuit_reduction_at(coordinate)
			assert_true(band <= -6, "N/O/P should always be in the -6/-7 bands per the source doc - chart %s's %s is at band %d" % [chart, letter, band])

func test_graph_distance_zero_for_same_node() -> void:
	assert_eq(StarChart.graph_distance("0000", "0000"), 0, "distance to self should be 0")

func test_graph_distance_direct_neighbor() -> void:
	assert_eq(StarChart.graph_distance("0000", "5143"), 1, "a direct neighbor should be distance 1")

func test_graph_distance_multi_hop() -> void:
	# 0000 -> 5143 -> 9997 -> 6931 is a real 3-hop path; confirm the
	# search finds a route at least that short (it may find a shorter
	# one if a better path exists, which is fine - this just guards
	# against a distance regression, not a fixed route).
	var distance := StarChart.graph_distance("0000", "6931")
	assert_true(distance > 0 and distance <= 3, "0000 to 6931 should be reachable within 3 hops, got %d" % distance)

func test_graph_distance_unreachable_returns_negative_one() -> void:
	assert_eq(StarChart.graph_distance("0000", "no-such-node"), -1, "an unknown node should be unreachable")

func test_pursuit_reduction_for_start_is_zero() -> void:
	assert_eq(StarChart.pursuit_reduction_at(StarChart.START), 0, "0000 is never a jump target and has no pursuit reduction")

func test_pursuit_reduction_matches_band() -> void:
	assert_eq(StarChart.pursuit_reduction_at("5143"), -1, "5143 is in the -1 band")
	assert_eq(StarChart.pursuit_reduction_at("4888"), -7, "4888 is in the -7 band")
