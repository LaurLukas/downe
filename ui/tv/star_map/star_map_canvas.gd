class_name StarMapCanvas
extends Control

## Draws the map: background, glow layer, bands, edges, path-tree
## trails, nodes and group tokens - all from one StarMapProjection dict,
## in one _draw() call. Rebuilt against
## ui/design_handoff_star_map/star_map_tv_visual_implementation.md (the
## design handoff that superseded the first structural pass - see
## TODO.md's "Star Map TV visual redesign" entry for the full context
## and priority order this follows).
##
## Matches this project's established pattern for the Wolf Attack
## screen's draw-only helper Controls (PursuitMeter, ImpactArc,
## LaneSpines): correct data/geometry and the spec's exact colour/pixel
## values using plain Godot drawing primitives, not a shader-based
## radial-gradient glow or the animated locator pulse - see this file's
## own header note on _draw_soft_glow() and _draw_locator() for what's
## approximated vs. deferred.
##
## This Control never touches StarChart.CHART_ASSIGNMENTS or any other
## source of ground truth - it only ever draws what `view` (a
## StarMapProjection.build() dict) already contains, which has already
## stripped unvisited letters at the source (C2). A bug in this file
## structurally cannot leak one.
##
## Still not built, and still needs a live window to judge rather than
## just code review: pixel-exact chip/token *feel* (the collision
## avoidance below picks a correct non-overlapping slot per §4.1/§4.3's
## rule, but the spec's own "measure it" instruction really means eyes
## on a real screen) and the pulse's exact cadence/easing curve (a sine
## approximation of "2.4s ease-in-out", not a Tween using Godot's actual
## ease-in-out curve - see _draw_locator()'s own comment). The group
## token's index disc (a map-to-rail-card link badge) is also still
## unbuilt - see TODO.md.

const TOKEN_RADIUS := 26.0
const INK := Color(0.03, 0.04, 0.08)

## §4.2's pulse ring: "2.4s ease-in-out, infinite, ~0.42 Hz." Advanced
## in _process() rather than a Tween - this Control redraws continuously
## anyway whenever a view is set (matching every other always-live TV
## element here), so a plain accumulated-time + sine curve is simpler
## than standing up a Tween for something that never stops and has no
## discrete start/end. Not pixel-verified against the spec's literal
## easing curve (a Tween's TRANS_SINE/EASE_IN_OUT would match it more
## exactly) - see this file's header note.
const PULSE_PERIOD := 2.4
var _pulse_time := 0.0

var view: Dictionary = {}:
	set(value):
		view = value
		queue_redraw()

func _process(delta: float) -> void:
	if view.is_empty():
		return
	_pulse_time = fmod(_pulse_time + delta, PULSE_PERIOD)
	queue_redraw()

func _draw() -> void:
	if view.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, StarMapTokens.CANVAS_SIZE), StarMapTokens.BG)
	var chip_rects := _resolve_chip_rects(view)
	var token_positions := _resolve_token_positions(view, chip_rects)
	_draw_glow_layer()
	_draw_bands()
	_draw_edges()
	_draw_trails()
	_draw_nodes(chip_rects)
	_draw_group_tokens(token_positions)
	_draw_legend()

static func _screen_pos(coordinate: String) -> Vector2:
	return StarMapTokens.node_screen_pos_for(coordinate)

static func _tier_of(coordinate: String) -> int:
	return 0 if coordinate == StarChart.START else -StarChart.pursuit_reduction_at(coordinate)

static func node_radius_for_state(state: String) -> float:
	return StarMapTokens.NODE_RADIUS_LARGE if (state == "visited" or state == "occupied") else StarMapTokens.NODE_RADIUS_SMALL

const CHIP_WIDTH := 260.0
const CHIP_HEIGHT := 26.0

## Pure position math, extracted out of _draw_info_chip() so
## tests/ui/star_map_layout_test.gd can verify chip placement (§4.1's
## collision rule) without a second, potentially-drifting copy of this
## logic - the test calls this same function, not a re-derivation of it.
##
## x is clamped to stay on-canvas rather than always centred on the
## node - 0000 sits at x=80, close enough to the left edge that a
## centred 260px-wide chip would run off it entirely (a real bug this
## file's own layout test caught: "0000's info chip extends past the
## canvas bounds"). §4.1 already carves out a vertical exception for
## 0000 ("the one node whose chip goes above it... left runs off
## canvas" - its own words) but doesn't resolve the horizontal case;
## clamping is the minimal fix that keeps the chip attached to its node
## everywhere else (every other node sits far enough from both edges
## that the clamp never engages).
static func chip_rect_for(coordinate: String, state: String) -> Rect2:
	var pos := _screen_pos(coordinate)
	var radius := node_radius_for_state(state)
	var above := coordinate == StarChart.START
	var chip_y := (pos.y - radius - 8.0 - CHIP_HEIGHT) if above else (pos.y + radius + 8.0)
	var chip_x := clampf(pos.x - CHIP_WIDTH / 2.0, 0.0, StarMapTokens.CANVAS_SIZE.x - CHIP_WIDTH)
	return Rect2(chip_x, chip_y, CHIP_WIDTH, CHIP_HEIGHT)

## §4.1's collision-avoidance pass: chip_rect_for() above gives each
## node's *default* slot (still the function tests/ui/star_map_layout_test.gd
## verifies directly, and still what's used when nothing collides - the
## common case at real node separations). This is the layer that
## actually needs to know about every other node/chip on screen at
## once, kept separate so chip_rect_for() stays simple and pure.
## "A chip must be nearer its own node than any other node... when the
## natural slot is taken, go lower-right diagonal, not sideways" - one
## fallback step, not a general solver, matching what §4.1 itself asks
## for.
static func _resolve_chip_rects(view: Dictionary) -> Dictionary:
	var displayable: Array[Dictionary] = []
	for node: Dictionary in (view.get("nodes", []) as Array):
		var state: String = String(node["state"])
		if state == "visited" or state == "occupied" or state == "reported":
			displayable.append(node)

	var resolved: Dictionary[String, Rect2] = {}
	var placed: Array[Rect2] = []
	for node: Dictionary in displayable:
		var coordinate: String = String(node["id"])
		var state: String = String(node["state"])
		var default_rect := chip_rect_for(coordinate, state)
		var final_rect := default_rect
		if _chip_collides(coordinate, default_rect, placed):
			var alt_rect := _clamp_rect_to_canvas(Rect2(default_rect.position + Vector2(30.0, 30.0), default_rect.size))
			if not _chip_collides(coordinate, alt_rect, placed):
				final_rect = alt_rect
			# else: keep the default anyway rather than search further -
			# a rare residual overlap at real node density beats an
			# unbounded search for a case the spec itself only gives one
			# fallback step for.
		resolved[coordinate] = final_rect
		placed.append(final_rect)
	return resolved

static func _clamp_rect_to_canvas(rect: Rect2) -> Rect2:
	var x := clampf(rect.position.x, 0.0, StarMapTokens.CANVAS_SIZE.x - rect.size.x)
	var y := clampf(rect.position.y, 0.0, StarMapTokens.CANVAS_SIZE.y - rect.size.y)
	return Rect2(x, y, rect.size.x, rect.size.y)

static func _chip_collides(coordinate: String, rect: Rect2, placed: Array[Rect2]) -> bool:
	for other_coordinate in StarChart.all_coordinates():
		if other_coordinate == coordinate:
			continue
		var other_pos := _screen_pos(other_coordinate)
		# Conservative on purpose: always checked against the *larger*
		# node size regardless of that node's real state, so a chip
		# never lands on a neighbour that later becomes visited/occupied
		# without this having to be recomputed for that reason alone.
		var half := Vector2(StarMapTokens.NODE_RADIUS_LARGE, StarMapTokens.NODE_RADIUS_LARGE)
		if rect.intersects(Rect2(other_pos - half, half * 2.0)):
			return true
	for other_rect in placed:
		if rect.intersects(other_rect):
			return true
	return false

## §4.3's token collision rule: "pushed to another quadrant when the
## info chip or a neighbour's chip is there." Tries upper-right (the
## default), then upper-left, lower-right, lower-left in that order,
## keeping the default if all four are somehow taken (four fixed
## quadrants and real node separation make that a theoretical case, not
## an observed one).
const _TOKEN_QUADRANTS: Array[Vector2] = [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]

static func _resolve_token_positions(view: Dictionary, chip_rects: Dictionary) -> Dictionary:
	var chip_rect_list: Array = chip_rects.values()
	var resolved: Dictionary[String, Vector2] = {}
	var placed: Array[Rect2] = []
	for group: Dictionary in (view.get("groups", []) as Array):
		var node_pos := _screen_pos(String(group["at"]))
		var chosen_pos := node_pos + _TOKEN_QUADRANTS[0] * (TOKEN_RADIUS + 14.0)
		var half := Vector2(TOKEN_RADIUS, TOKEN_RADIUS)
		var found := false
		for quadrant in _TOKEN_QUADRANTS:
			var candidate := node_pos + quadrant * (TOKEN_RADIUS + 14.0)
			var candidate_rect := Rect2(candidate - half, half * 2.0)
			if not _token_collides(candidate_rect, chip_rect_list, placed):
				chosen_pos = candidate
				found = true
				break
		placed.append(Rect2(chosen_pos - half, half * 2.0))
		resolved[String(group["id"])] = chosen_pos
	return resolved

static func _token_collides(rect: Rect2, chip_rects: Array, placed: Array[Rect2]) -> bool:
	for chip_rect: Variant in chip_rects:
		if rect.intersects(chip_rect):
			return true
	for other_rect in placed:
		if rect.intersects(other_rect):
			return true
	return false

# --- glow layer (§4) - behind everything else, incl. the bands/edges ------

## Real radial gradients need a shader; this approximates one with a
## handful of concentric, decreasing-alpha circles instead - visibly
## soft at TV viewing distance, no shader resource needed.
func _draw_soft_glow(center: Vector2, radius: float, colour: Color, peak_alpha: float) -> void:
	const RINGS := 6
	for i in range(RINGS, 0, -1):
		var t := float(i) / RINGS
		var alpha := peak_alpha * (1.0 - t) * (1.0 - t)
		draw_circle(center, radius * t, Color(colour.r, colour.g, colour.b, alpha))

func _draw_glow_layer() -> void:
	for node: Dictionary in (view.get("nodes", []) as Array):
		var state: String = node["state"]
		if String(node.get("class", "")) == "wolf" and (state == "visited" or state == "occupied"):
			_draw_soft_glow(_screen_pos(node["id"]), 150.0, StarMapTokens.WOLF, 0.30)
	for group: Dictionary in (view.get("groups", []) as Array):
		if bool((group["representative"] as Dictionary)["is_aegis"]):
			_draw_soft_glow(_screen_pos(String(group["at"])), 210.0, StarMapTokens.FLEET, 0.22)

# --- bands (§2.2) -----------------------------------------------------------

func _draw_bands() -> void:
	var tier_us: Dictionary[int, Array] = {}
	for coordinate in StarChart.all_coordinates():
		var tier := _tier_of(coordinate)
		if not tier_us.has(tier):
			tier_us[tier] = []
		(tier_us[tier] as Array).append(_screen_pos(coordinate).x)

	var tiers: Array = tier_us.keys()
	tiers.sort()

	var bounds: Array[float] = [StarMapTokens.X_MAP_LEFT]
	for i in range(tiers.size() - 1):
		var this_max: float = (tier_us[tiers[i]] as Array).max()
		var next_min: float = (tier_us[tiers[i + 1]] as Array).min()
		bounds.append((this_max + next_min) / 2.0)
	bounds.append(StarMapTokens.X_MAP_RIGHT)

	# Occupied bands are tinted, not just striped (§2.2) - the group's
	# own band_tint flag (StarMapProjection, AEGIS winning ties) says
	# which one wins per tier.
	var tint_by_tier: Dictionary[int, Color] = {}
	for group: Dictionary in (view.get("groups", []) as Array):
		if not bool(group.get("band_tint", false)):
			continue
		var tier := _tier_of(String(group["at"]))
		tint_by_tier[tier] = StarMapTokens.group_colour(bool((group["representative"] as Dictionary)["is_aegis"]))

	var band_top := StarMapTokens.Y_MAP_TOP
	var band_height := StarMapTokens.Y_MAP_BOTTOM - StarMapTokens.Y_MAP_TOP
	var label_font := WolfAttackTokens.font("T_BAND_GUTTER")
	var label_size := StarMapTokens.FONT_SIZE_BAND_LABEL
	for i in tiers.size():
		var x0: float = bounds[i]
		var x1: float = bounds[i + 1]
		var tier: int = tiers[i]
		var rect := Rect2(x0, band_top, x1 - x0, band_height)

		if tint_by_tier.has(tier):
			var accent: Color = tint_by_tier[tier]
			draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.10))
			draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.18), false, 1.0)
		else:
			draw_rect(rect, Color(1, 1, 1, StarMapTokens.BAND_ALPHA.get(tier, 0.022)))

		var label := "START" if tier == 0 else "-%d" % tier
		var center_x := (x0 + x1) / 2.0
		var label_colour: Color = tint_by_tier[tier] if tint_by_tier.has(tier) else Color(StarMapTokens.TEXT_LABEL, 0.4)
		draw_string(label_font, Vector2(center_x - 40.0, StarMapTokens.Y_BAND_SCALE_TOP + 24.0), label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, label_size, label_colour)

# --- edges (§5) --------------------------------------------------------------

func _draw_edges() -> void:
	var drawn: Dictionary[String, bool] = {}
	for coordinate in StarChart.all_coordinates():
		for neighbor in StarChart.neighbors_of(coordinate):
			var key := _edge_key(coordinate, neighbor)
			if drawn.has(key):
				continue
			drawn[key] = true
			draw_line(_screen_pos(coordinate), _screen_pos(neighbor), Color("#5C6E88").lerp(StarMapTokens.BG, 0.6), 2.0)

static func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

# --- trails (§5) --------------------------------------------------------------

## The path tree - each tree edge drawn once. Live branches: FLEET for
## the AEGIS-carrying branch, FLEET_ALT otherwise, solid if the segment
## is a real graph edge, a dashed bowed arc plus a "JUMP FAILURE" label
## if it isn't (a multi-hop jump or host relocation). Dead branches are
## always dotted, adjacent or not - §5's "still history, no longer
## competing" applies regardless of whether the abandoned hop happened
## to be a direct edge.
func _draw_trails() -> void:
	var path_tree: Dictionary = view.get("path_tree", {})
	# Font family/weight borrowed from WolfAttackTokens' T_CHIP token,
	# but NOT its size (17px) - that was tuned for the Wolf Attack
	# screen's own budget and is under this screen's own §1 "no text
	# below 18px" rule. Real bug, found by tests/test_star_map_layout.gd.
	var label_font := WolfAttackTokens.font("T_CHIP")
	var label_size := StarMapTokens.FONT_SIZE_EDGE_LABEL
	for branch: Dictionary in (path_tree.get("branches", []) as Array):
		var nodes: Array = branch["nodes"]
		var is_dead: bool = branch["state"] == "dead"
		var is_primary: bool = bool(branch.get("primary", false))
		var colour: Color = Color(StarMapTokens.TEXT_LABEL.r, StarMapTokens.TEXT_LABEL.g, StarMapTokens.TEXT_LABEL.b, 0.28) if is_dead else StarMapTokens.group_colour(is_primary)
		var width: float = 3.0 if is_dead else (7.0 if is_primary else 4.0)

		for i in range(nodes.size() - 1):
			var from: String = nodes[i]
			var to: String = nodes[i + 1]
			var from_pos := _screen_pos(from)
			var to_pos := _screen_pos(to)
			var is_adjacent: bool = to in StarChart.neighbors_of(from)

			if is_dead:
				if is_adjacent:
					_draw_dashed_line(from_pos, to_pos, colour, width, 3.0, 9.0)
				else:
					_draw_dashed_arc(from_pos, to_pos, colour, width)
			elif is_adjacent:
				draw_line(from_pos, to_pos, colour, width)
			else:
				_draw_dashed_arc(from_pos, to_pos, colour, width)
				var mid := (from_pos + to_pos) / 2.0
				draw_string(label_font, mid + Vector2(-40.0, -14.0), "JUMP FAILURE", HORIZONTAL_ALIGNMENT_CENTER, 80.0, label_size, colour)

func _draw_dashed_line(from: Vector2, to: Vector2, colour: Color, width: float, dash: float = 8.0, gap: float = 8.0) -> void:
	var diff := to - from
	var length := diff.length()
	if length <= 0.0:
		return
	var direction := diff / length
	var travelled := 0.0
	while travelled < length:
		var segment_end := minf(travelled + dash, length)
		draw_line(from + direction * travelled, from + direction * segment_end, colour, width)
		travelled += dash + gap

## Quadratic bezier bowed away from the graph interior, drawn dashed -
## §5's "never a straight line, a straight line reads as a route that
## exists."
func _draw_dashed_arc(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	var mid := (from + to) / 2.0
	var normal := (to - from).orthogonal().normalized()
	var control := mid + normal * 44.0
	const SEGMENTS := 24
	var points: Array[Vector2] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var u := 1.0 - t
		points.append(u * u * from + 2.0 * u * t * control + t * t * to)
	var i := 0
	while i < points.size() - 1:
		draw_line(points[i], points[i + 1], colour, width)
		i += 2

func _draw_dashed_ring(center: Vector2, radius: float, colour: Color, width: float) -> void:
	const SEGMENTS := 28
	for i in range(0, SEGMENTS, 2):
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		draw_arc(center, radius, a0, a1, 4, colour, width, true)

func _draw_dashed_rect(rect: Rect2, colour: Color, width: float) -> void:
	var tl := rect.position
	var tr := rect.position + Vector2(rect.size.x, 0)
	var bl := rect.position + Vector2(0, rect.size.y)
	var br := rect.position + rect.size
	_draw_dashed_line(tl, tr, colour, width, 4.0, 3.0)
	_draw_dashed_line(tr, br, colour, width, 4.0, 3.0)
	_draw_dashed_line(br, bl, colour, width, 4.0, 3.0)
	_draw_dashed_line(bl, tl, colour, width, 4.0, 3.0)

# --- nodes (§4) ---------------------------------------------------------------

func _draw_nodes(chip_rects: Dictionary) -> void:
	var coord_font := WolfAttackTokens.font("T_STAT")
	var letter_font := WolfAttackTokens.font("T_WOLF_CODE")
	var chip_font := WolfAttackTokens.font("T_CHIP")

	var group_colour_by_coordinate: Dictionary[String, Color] = {}
	for group: Dictionary in (view.get("groups", []) as Array):
		var is_aegis: bool = bool((group["representative"] as Dictionary)["is_aegis"])
		group_colour_by_coordinate[String(group["at"])] = StarMapTokens.group_colour(is_aegis)

	for node: Dictionary in (view.get("nodes", []) as Array):
		var coordinate: String = node["id"]
		var pos := _screen_pos(coordinate)
		var state: String = node["state"]
		var node_class: String = String(node.get("class", ""))
		var is_large: bool = state == "visited" or state == "occupied"
		var radius: float = node_radius_for_state(state)
		var is_wolf: bool = node_class == "wolf" and is_large

		var fill: Color
		var ring: Color
		var ring_width: float
		match state:
			"unknown", "destination":
				fill = Color(8.0 / 255.0, 11.0 / 255.0, 20.0 / 255.0, 0.7)
				ring = StarMapTokens.UNKNOWN
				ring_width = 2.0
			"reported":
				fill = Color(26.0 / 255.0, 20.0 / 255.0, 4.0 / 255.0, 0.82)
				ring = StarMapTokens.CLAIM
				ring_width = 3.0
			_: # visited / occupied
				var tint := StarMapTokens.class_tint(node_class)
				fill = Color(tint.r, tint.g, tint.b, 0.14)
				ring = StarMapTokens.WOLF if is_wolf else tint
				ring_width = 5.0 if is_wolf else 4.0

		draw_circle(pos, radius, fill)
		if state == "reported":
			_draw_dashed_ring(pos, radius, ring, ring_width)
		else:
			draw_arc(pos, radius, 0.0, TAU, 40, ring, ring_width, true)

		if state == "occupied":
			_draw_locator(pos, group_colour_by_coordinate.get(coordinate, StarMapTokens.FLEET))

		if is_large:
			var letter: String = String(node.get("letter", ""))
			var letter_colour := Color("#FF8375") if is_wolf else StarMapTokens.TEXT_PRIMARY
			draw_string(letter_font, Vector2(pos.x - radius, pos.y + 15.0), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, StarMapTokens.FONT_SIZE_LETTER, letter_colour)
		else:
			draw_string(coord_font, Vector2(pos.x - radius, pos.y + 8.0), coordinate, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, StarMapTokens.FONT_SIZE_COORD, Color("#7E8EA6"))

		_draw_info_chip(node, chip_font, chip_rects)

## Three concentric elements in the group's accent, per §4.2: pulse
## ring, corner brackets, halo (the halo is _draw_soft_glow(), drawn
## earlier in the glow layer so it sits behind the edges).
func _draw_locator(center: Vector2, colour: Color) -> void:
	var t := (sin(_pulse_time / PULSE_PERIOD * TAU) + 1.0) / 2.0
	var pulse_radius := lerpf(60.0, 60.0 * 1.16, t)
	var pulse_alpha := lerpf(0.55, 0.10, t)
	draw_arc(center, pulse_radius, 0.0, TAU, 40, Color(colour.r, colour.g, colour.b, pulse_alpha), 3.0, true)

	var half := 70.0
	var bracket := 22.0
	var corners: Array[Vector2] = [
		center + Vector2(-half, -half), center + Vector2(half, -half),
		center + Vector2(-half, half), center + Vector2(half, half),
	]
	var arms: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 0)]
	var verticals: Array[Vector2] = [Vector2(0, 1), Vector2(0, 1), Vector2(0, -1), Vector2(0, -1)]
	for i in 4:
		draw_line(corners[i], corners[i] + arms[i] * bracket, colour, 4.0)
		draw_line(corners[i], corners[i] + verticals[i] * bracket, colour, 4.0)

## §4.1: single-line info chip. `unknown` nodes get none - the
## coordinate already sits inside the (otherwise empty) circle. 0000 is
## the one node whose chip goes above, per §4.1's own explicit
## exception. Claim text is rail-only (design-handoff override #2) -
## the map keeps only a claim *count*, dashed.
func _draw_info_chip(node: Dictionary, font: Font, chip_rects: Dictionary) -> void:
	var state: String = node["state"]
	if state != "visited" and state != "occupied" and state != "reported":
		return

	var coordinate: String = node["id"]
	var rect: Rect2 = chip_rects.get(coordinate, chip_rect_for(coordinate, state))

	var text: String
	var colour: Color
	var dashed := false
	if state == "reported":
		var claims: Array = node.get("claims", [])
		dashed = true
		colour = StarMapTokens.CLAIM
		if claims.size() > 1 and _claims_disagree(claims):
			text = "%d CLAIMS · CONFLICT" % claims.size()
		elif claims.size() > 1:
			text = "%d CLAIMS" % claims.size()
		else:
			text = "1 CLAIM"
	else:
		colour = StarMapTokens.TEXT_PRIMARY
		text = "%s · %s" % [coordinate, String(node.get("short_name", node.get("name", "")))]

	draw_rect(rect, Color(0.03, 0.04, 0.08, 0.85))
	if dashed:
		_draw_dashed_rect(rect, colour, 1.0)
	else:
		draw_rect(rect, colour, false, 1.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y - 8.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, StarMapTokens.FONT_SIZE_CHIP, colour)

static func _claims_disagree(claims: Array) -> bool:
	if claims.size() < 2:
		return false
	var first_text := String((claims[0] as Dictionary)["text"])
	for claim: Variant in claims:
		if String((claim as Dictionary)["text"]) != first_text:
			return true
	return false

# --- group tokens (§4.3) -------------------------------------------------------

## One token per group (§4.1) - the display collapses the fleet, never
## draws a token per ship. Hull silhouette reused directly from
## ShipIcon's own texture table (res://ui/design_handoff_wolf_attack_lanes/
## svg/capital-*.svg - byte-identical to this handoff's own svg/ copy,
## confirmed by diff, so this doesn't need a second preload list).
func _draw_group_tokens(token_positions: Dictionary) -> void:
	var abbr_font := WolfAttackTokens.font("T_SEC")
	var abbr_size := StarMapTokens.FONT_SIZE_TOKEN_ABBR
	var dmg_font := WolfAttackTokens.font("T_SEC")

	for group: Dictionary in (view.get("groups", []) as Array):
		var pos: Vector2 = token_positions.get(String(group["id"]), _screen_pos(String(group["at"])) + Vector2(TOKEN_RADIUS + 14.0, -(TOKEN_RADIUS + 14.0)))
		var representative: Dictionary = group["representative"]
		var is_aegis: bool = bool(representative["is_aegis"])
		var colour := StarMapTokens.group_colour(is_aegis)
		# §4.3: "AEGIS's token: 3px white outline. Any other group: 6px
		# WOLF-coloured bottom edge if the group contains a damaged
		# ship, plus a DMG tag." AEGIS's group never gets the damaged
		# treatment even if it has a damaged member - the spec's own
		# wording ("any OTHER group") gives the white outline priority
		# there, not this.
		var is_damaged: bool = not is_aegis and not (group.get("damaged_member_ids", []) as Array).is_empty()

		draw_circle(pos, TOKEN_RADIUS, colour)
		if is_aegis:
			draw_arc(pos, TOKEN_RADIUS + 2.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
		if is_damaged:
			draw_line(pos + Vector2(-TOKEN_RADIUS, TOKEN_RADIUS - 1.0), pos + Vector2(TOKEN_RADIUS, TOKEN_RADIUS - 1.0), StarMapTokens.WOLF, 6.0)
			var dmg_pos := pos + Vector2(-TOKEN_RADIUS, TOKEN_RADIUS + 18.0)
			draw_string(dmg_font, dmg_pos, "DMG", HORIZONTAL_ALIGNMENT_CENTER, TOKEN_RADIUS * 2.0, StarMapTokens.FONT_SIZE_DMG_TAG, StarMapTokens.WOLF)

		var rep_id: String = String(representative["id"])
		var texture: Texture2D = ShipIcon._TEXTURES.get(rep_id)
		if texture != null:
			var icon_box := Vector2(TOKEN_RADIUS * 1.3, TOKEN_RADIUS * 0.6)
			var tex_size := texture.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				var fit_scale := minf(icon_box.x / tex_size.x, icon_box.y / tex_size.y)
				var fitted := tex_size * fit_scale
				draw_texture_rect(texture, Rect2(pos - fitted / 2.0 - Vector2(0, TOKEN_RADIUS * 0.4), fitted), false, INK)

		var member_count: int = (group["members"] as Array).size()
		var label: String = String(representative["abbr"])
		if member_count > 1:
			label += " +%d" % (member_count - 1)

		draw_string(abbr_font, Vector2(pos.x - TOKEN_RADIUS - 24.0, pos.y + TOKEN_RADIUS * 0.55 + 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, (TOKEN_RADIUS + 24.0) * 2.0, abbr_size, INK)

# --- legend bar (§7) -----------------------------------------------------------

const _LEGEND_ITEMS: Array[Dictionary] = [
	{"label": "FLEET HERE", "kind": "ring"},
	{"label": "PATH TRAVELLED", "kind": "line"},
	{"label": "JUMP FAILURE", "kind": "dashed_arc"},
	{"label": "ABANDONED ROUTE", "kind": "dotted"},
	{"label": "WOLF SYSTEM", "kind": "ring"},
	{"label": "HAZARD", "kind": "ring"},
	{"label": "SCOUT CLAIM", "kind": "dashed_ring"},
	{"label": "UNVISITED", "kind": "ring"},
]

## Permanent, not a host toggle (§7) - "the direct answer to 'not sure
## what the yellow line is'."
func _draw_legend() -> void:
	var colours := [
		StarMapTokens.FLEET, StarMapTokens.FLEET, StarMapTokens.FLEET_ALT,
		Color(StarMapTokens.TEXT_LABEL.r, StarMapTokens.TEXT_LABEL.g, StarMapTokens.TEXT_LABEL.b, 0.6),
		StarMapTokens.WOLF, StarMapTokens.HAZARD, StarMapTokens.CLAIM, StarMapTokens.UNKNOWN,
	]
	var y := StarMapTokens.Y_LEGEND_TOP + 24.0
	var usable_width := StarMapTokens.X_MAP_RIGHT - StarMapTokens.X_MAP_LEFT
	var slot := usable_width / _LEGEND_ITEMS.size()
	var font := WolfAttackTokens.font("T_STAT")

	for i in _LEGEND_ITEMS.size():
		var item: Dictionary = _LEGEND_ITEMS[i]
		var colour: Color = colours[i]
		var x0 := StarMapTokens.X_MAP_LEFT + slot * i
		var swatch := Vector2(x0 + 12.0, y)
		match String(item["kind"]):
			"ring":
				draw_arc(swatch, 8.0, 0.0, TAU, 16, colour, 2.0, true)
			"dashed_ring":
				_draw_dashed_ring(swatch, 8.0, colour, 2.0)
			"line":
				draw_line(swatch + Vector2(-10, 0), swatch + Vector2(10, 0), colour, 3.0)
			"dotted":
				_draw_dashed_line(swatch + Vector2(-10, 0), swatch + Vector2(10, 0), colour, 2.0, 2.0, 3.0)
			"dashed_arc":
				_draw_dashed_line(swatch + Vector2(-10, -4), swatch + Vector2(10, 4), colour, 2.0, 4.0, 3.0)
		draw_string(font, Vector2(x0 + 26.0, y + 6.0), String(item["label"]), HORIZONTAL_ALIGNMENT_LEFT, slot - 30.0, StarMapTokens.FONT_SIZE_LEGEND, StarMapTokens.TEXT_SECONDARY)
