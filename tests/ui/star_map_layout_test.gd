extends TestCase

## ui/design_handoff_star_map/star_map_tv_visual_implementation.md §11:
## "the layout failures in this pass were all collisions, and all of
## them were invisible in code review and obvious in a measured DOM.
## Add tests/test_star_map_layout.gd" - named star_map_layout_test.gd
## here instead, to actually match this project's test-discovery
## convention (run_tests.gd only picks up *_test.gd; the spec's own
## literal filename would silently never run at all).
##
## Checks 1/2/4/6 below are pure geometry - StarMapTokens/StarChart
## constants and StarMapCanvas's own pure position functions
## (_screen_pos(), chip_rect_for(), node_radius_for_state()), checked
## directly with no Control ever instantiated. Check 5 checks the
## single font-size registry every draw call on this screen is required
## to use.
##
## Check 3 (rail column bottom < y1010) is the one item genuinely about
## live Container auto-layout (VBoxContainer/PanelContainer/RichTextLabel
## sizing), which this project's TestCase framework can't measure
## precisely: TestCase.run() calls test methods fully synchronously, with
## no `await` support, and a real instantiated rail's
## get_combined_minimum_size() measured immediately after building it
## (no frame elapsed) was empirically found to be wildly wrong - 1353px
## for content that actually lays out to 276px, because RichTextLabel's
## fit_content needs a real layout pass to know its assigned width
## before it can wrap correctly. Rather than add async test support to
## the shared runner (real risk to the other 44 files) for one check,
## or silently accept a measurement that was proven unreliable, check 3
## is a font-metric estimate that mirrors star_map_screen.gd's own
## rail-building conditionals line-for-line (see _estimate_rail_height())
## - it catches the failure mode the spec actually cites ("the first
## build lost a whole rail section this way", a wholesale overflow) even
## though it can't catch a sub-pixel wrapping miscalculation. A live
## window is still the authority for exact pixels, same as every other
## visual check in this project's history.

const RAIL_TOP := 78.0
const RAIL_BUDGET := 1010.0 - RAIL_TOP

# --- check 1: no two node-centre labels overlap by more than 6px -----------

func test_no_two_node_center_labels_overlap() -> void:
	var view := _dense_rail_fixture()
	var letter_font := WolfAttackTokens.font("T_WOLF_CODE")
	var coord_font := WolfAttackTokens.font("T_STAT")
	var boxes: Array[Dictionary] = []
	for node: Dictionary in (view["nodes"] as Array):
		var coordinate: String = String(node["id"])
		var state: String = String(node["state"])
		var pos := StarMapCanvas._screen_pos(coordinate)
		var is_large := state == "visited" or state == "occupied"
		var text: String = String(node.get("letter", "")) if is_large else coordinate
		if text.is_empty():
			continue
		var font: Font = letter_font if is_large else coord_font
		var font_size: int = StarMapTokens.FONT_SIZE_LETTER if is_large else StarMapTokens.FONT_SIZE_COORD
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		boxes.append({"coordinate": coordinate, "rect": Rect2(pos - text_size / 2.0, text_size)})

	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Rect2 = boxes[i]["rect"]
			var b: Rect2 = boxes[j]["rect"]
			var overlap_x: float = minf(a.position.x + a.size.x, b.position.x + b.size.x) - maxf(a.position.x, b.position.x)
			var overlap_y: float = minf(a.position.y + a.size.y, b.position.y + b.size.y) - maxf(a.position.y, b.position.y)
			assert_true(not (overlap_x > 6.0 and overlap_y > 6.0), "%s and %s node-centre labels overlap by more than 6px on both axes" % [boxes[i]["coordinate"], boxes[j]["coordinate"]])

# --- check 2: nothing renders past x1920/y1080 ------------------------------

func test_nothing_renders_past_canvas_bounds() -> void:
	var view := _dense_rail_fixture()
	var canvas_rect := Rect2(Vector2.ZERO, StarMapTokens.CANVAS_SIZE)

	for node: Dictionary in (view["nodes"] as Array):
		var coordinate: String = String(node["id"])
		var state: String = String(node["state"])
		var pos := StarMapCanvas._screen_pos(coordinate)
		var radius := StarMapCanvas.node_radius_for_state(state)
		var node_rect := Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		assert_true(canvas_rect.encloses(node_rect), "%s's node circle extends past the canvas bounds" % coordinate)

		if state == "visited" or state == "occupied" or state == "reported":
			var chip_rect := StarMapCanvas.chip_rect_for(coordinate, state)
			assert_true(canvas_rect.encloses(chip_rect), "%s's info chip extends past the canvas bounds" % coordinate)

	for group: Dictionary in (view["groups"] as Array):
		var pos := StarMapCanvas._screen_pos(String(group["at"])) + Vector2(StarMapCanvas.TOKEN_RADIUS + 14.0, -(StarMapCanvas.TOKEN_RADIUS + 14.0))
		var half := Vector2(StarMapCanvas.TOKEN_RADIUS, StarMapCanvas.TOKEN_RADIUS)
		var token_rect := Rect2(pos - half, half * 2.0)
		assert_true(canvas_rect.encloses(token_rect), "%s's group token extends past the canvas bounds" % group["id"])

	assert_true(StarMapTokens.Y_LEGEND_BOTTOM <= StarMapTokens.CANVAS_SIZE.y, "the legend bar must fit above the canvas bottom edge")
	assert_true(StarMapTokens.X_RAIL_RIGHT <= StarMapTokens.CANVAS_SIZE.x, "the info rail must fit within the canvas width")

# --- check 3: rail column bottom < y1010 (dense and empty states) ----------

func test_rail_height_estimate_stays_under_budget_at_the_densest_realistic_state() -> void:
	var view := _dense_rail_fixture()
	var estimated := _estimate_rail_height(view)
	assert_true(estimated < RAIL_BUDGET, "estimated rail height %.0fpx exceeds the %.0fpx budget (two groups, three claims, three wolf systems)" % [estimated, RAIL_BUDGET])

func test_rail_height_estimate_stays_under_budget_at_the_empty_state() -> void:
	var view := _empty_rail_fixture()
	var estimated := _estimate_rail_height(view)
	assert_true(estimated < RAIL_BUDGET, "estimated rail height %.0fpx exceeds budget even in the empty state - something is unconditionally too tall" % estimated)

static func _line_height(font_size: int) -> float:
	return WolfAttackTokens.font("T_STAT").get_height(font_size) + 6.0

## Mirrors star_map_screen.gd's _build_group_card()/_rebuild_wolf_presence()/
## _rebuild_scout_reports() conditionals line-for-line - see this file's
## header comment on why this is an estimate, not a live measurement.
static func _estimate_rail_height(view: Dictionary) -> float:
	var total := 0.0
	var groups: Array = view["groups"]
	for group: Dictionary in groups:
		total += 14.0 # PanelContainer content margin (top 10 + bottom 4)
		total += _line_height(26) # header
		total += _line_height(22) # members
		var node_at := _node_by_id(view, String(group["at"]))
		if node_at.has("consequence_summary"):
			total += _line_height(22)
		var scouts: Array = group["scouts"]
		var has_ranged := false
		var unlimited_count := 0
		for scout: Variant in scouts:
			var scout_dict: Dictionary = scout
			if bool(scout_dict.get("unlimited", false)):
				unlimited_count += 1
			else:
				has_ranged = true
		if has_ranged:
			total += _line_height(22)
		total += unlimited_count * _line_height(22)
		total += _line_height(22) # pursuit row
		if not (group["pending_merge_pursuits"] as Array).is_empty():
			total += _line_height(22)
		total += 20.0 # spacer

	var wolf_nodes: Array = (view["nodes"] as Array).filter(func(n: Dictionary) -> bool:
		return String(n.get("class", "")) == "wolf" and (n["state"] == "visited" or n["state"] == "occupied")
	)
	if not wolf_nodes.is_empty():
		total += 20.0 # PanelContainer content margins (10 top + 10 bottom)
		total += _line_height(27) # header
		total += wolf_nodes.size() * _line_height(22)
		total += 16.0 # spacer

	var claim_count := 0
	for node: Dictionary in (view["nodes"] as Array):
		if node.has("claims"):
			claim_count += (node["claims"] as Array).size()
	if claim_count > 0:
		total += _line_height(27) # header
		total += claim_count * (_line_height(22) * 2.0) # meta line + quoted text line
		total += 20.0 # spacer

	return total

static func _node_by_id(view: Dictionary, coordinate: String) -> Dictionary:
	for node: Dictionary in (view["nodes"] as Array):
		if node["id"] == coordinate:
			return node
	return {}

## Two groups (AEGIS splits off through a chain of wolf systems),
## three wolf systems (two visited-and-left, one occupied), three
## claims (two contradicting on one node, one elsewhere) - "the densest
## realistic state" per §11.
static func _dense_rail_fixture() -> Dictionary:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "4454", 1) # M - Active Wolf Fortress
	positions.move_unit("aegis", "6931", 2) # L - Active Wolf Outpost; 4454 now visited, not occupied
	positions.move_unit("aegis", "0488", 3) # L - Active Wolf Outpost; 6931 now visited, not occupied; 0488 occupied
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "a claim", "STARLIGHT", 1)
	reveal.publish_claim("3068", "a contradicting claim", "HUMMINGBIRD", 1)
	reveal.publish_claim("6798", "another claim", "ENDEAVOUR", 1)
	var craft: Dictionary = {
		"starlight": CraftState.new("starlight", "aegis"),
		"hummingbird": CraftState.new("hummingbird", "quellon"),
		"endeavour": CraftState.new("endeavour", "shepherd"),
	}
	return StarMapProjection.build("A", 3, positions, reveal, craft, {})

## One group, no claims, no wolves - the other fixture §11 explicitly
## asks for, since an unconditionally-too-tall element would only show
## up here, not in the dense state.
static func _empty_rail_fixture() -> Dictionary:
	var positions := FleetPositions.new()
	var reveal := RevealState.new()
	return StarMapProjection.build("A", 1, positions, reveal, {}, {})

# --- check 4: every info chip is closer to its own node than any other -----

func test_every_chip_position_is_closer_to_its_own_node_than_any_other() -> void:
	var all_coordinates := StarChart.all_coordinates()
	for coordinate: String in all_coordinates:
		# chip_rect_for()'s placement doesn't depend on which displayable
		# state produced it (only the "0000's chip goes above" exception
		# does, which is keyed on the coordinate, not the state) - check
		# both real states directly rather than needing a game-state
		# fixture that happens to produce every combination.
		for state in ["visited", "reported"]:
			var chip_rect: Rect2 = StarMapCanvas.chip_rect_for(coordinate, state)
			var chip_center := chip_rect.position + chip_rect.size / 2.0
			var own_distance := chip_center.distance_to(StarMapCanvas._screen_pos(coordinate))
			for other: String in all_coordinates:
				if other == coordinate:
					continue
				var other_distance := chip_center.distance_to(StarMapCanvas._screen_pos(other))
				assert_true(own_distance < other_distance, "%s's %s-state info chip is not closer to its own node than to %s" % [coordinate, state, other])

# --- collision avoidance (§4.1/§4.3) - resolve functions built alongside
# these checks, not part of the original §11 list, but exercised here
# since they're the same class of pure geometry.

func test_chip_resolution_matches_the_default_when_nothing_collides() -> void:
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1413", 1)
	var reveal := RevealState.new()
	var view := StarMapProjection.build("A", 1, positions, reveal, {}, {})
	var resolved := StarMapCanvas._resolve_chip_rects(view)
	for coordinate: String in resolved:
		var node: Dictionary = _node_by_id(view, coordinate)
		var default_rect := StarMapCanvas.chip_rect_for(coordinate, String(node["state"]))
		assert_eq(resolved[coordinate], default_rect, "%s's chip should sit at its default slot when nothing collides" % coordinate)

func test_group_token_avoids_a_colliding_neighbour_chip() -> void:
	# The spec's own cited collision (§4.3): "fleet token above 1096 -
	# the -45 slot collides with 3068's claim chip." Confirmed by hand
	# against the exact NODE_PIXEL_POSITION table before writing this
	# test - 1096's default upper-right token rect and 3068's default
	# below-node chip rect do overlap at these real coordinates.
	var positions := FleetPositions.new()
	positions.move_unit("aegis", "1096", 1)
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "a claim", "STARLIGHT", 1) # unvisited + a claim -> "reported", chip shown
	var view := StarMapProjection.build("A", 1, positions, reveal, {}, {})

	var chip_rects := StarMapCanvas._resolve_chip_rects(view)
	var token_positions := StarMapCanvas._resolve_token_positions(view, chip_rects)

	var default_token_pos := StarMapCanvas._screen_pos("1096") + Vector2(StarMapCanvas.TOKEN_RADIUS + 14.0, -(StarMapCanvas.TOKEN_RADIUS + 14.0))
	var group_id: String = (view["groups"] as Array)[0]["id"]
	var resolved_pos: Vector2 = token_positions[group_id]
	assert_true(resolved_pos != default_token_pos, "the token should move off its default upper-right slot when it collides with a neighbour's chip")

	var half := Vector2(StarMapCanvas.TOKEN_RADIUS, StarMapCanvas.TOKEN_RADIUS)
	var resolved_rect := Rect2(resolved_pos - half, half * 2.0)
	var chip_3068: Rect2 = chip_rects["3068"]
	assert_true(not resolved_rect.intersects(chip_3068), "the resolved token position should no longer overlap 3068's chip")

# --- check 5: no text element renders below 18px ----------------------------

func test_no_font_size_below_minimum() -> void:
	for size: int in StarMapTokens.ALL_FONT_SIZES:
		assert_true(size >= StarMapTokens.MIN_FONT_SIZE, "font size %dpx is below the %dpx minimum" % [size, StarMapTokens.MIN_FONT_SIZE])

# --- check 6: minimum node-centre separation >= 160px for all 22 nodes -----

func test_minimum_node_centre_separation() -> void:
	var coordinates := StarChart.all_coordinates()
	for i in coordinates.size():
		for j in range(i + 1, coordinates.size()):
			var a := StarMapCanvas._screen_pos(coordinates[i])
			var b := StarMapCanvas._screen_pos(coordinates[j])
			var distance := a.distance_to(b)
			assert_true(distance >= 160.0, "%s and %s are only %.1fpx apart (minimum 160px)" % [coordinates[i], coordinates[j], distance])
