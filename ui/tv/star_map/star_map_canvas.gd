class_name StarMapCanvas
extends Control

## Draws the map: bands, edges, path-tree trails, nodes and group
## tokens - all from one StarMapProjection dict, in one _draw() call.
## Matches this project's established pattern for the Wolf Attack
## screen's draw-only helper Controls (PursuitMeter, ImpactArc,
## LaneSpines): a structural pass using plain Godot drawing primitives,
## not docs/star_map_tv_display.md's pixel-exact node radii/reveal
## animations/dashed-chip styling - visual polish is explicitly
## deferred here, the same call already made for the Wolf Attack
## screen's v1 pass (see TODO.md).
##
## This Control never touches StarChart.CHART_ASSIGNMENTS or any other
## source of ground truth - it only ever draws what `view` (a
## StarMapProjection.build() dict) already contains, which has already
## stripped unvisited letters at the source (C2). A bug in this file
## structurally cannot leak one.

const MAP_RECT := Rect2(80, 90, 1280, 900)
const NODE_RADIUS := 20.0
const TOKEN_RADIUS := 18.0

const CLASS_TINT: Dictionary[String, Color] = {
	"start": WolfAttackTokens.CYAN_DIM,
	"poor": Color("#5A5648"),
	"neutral": Color("#4A5A48"),
	"standard": Color("#3A4048"),
	"hazard": WolfAttackTokens.AMBER,
	"wolf": WolfAttackTokens.ALERT_DEEP,
	"new_eden": Color("#3F6FB5"),
}

var view: Dictionary = {}:
	set(value):
		view = value
		queue_redraw()

func _draw() -> void:
	if view.is_empty():
		return
	_draw_bands()
	_draw_edges()
	_draw_trails()
	_draw_nodes()
	_draw_group_tokens()

func _screen_pos(coordinate: String) -> Vector2:
	var uv := StarChart.node_position(coordinate)
	return MAP_RECT.position + Vector2(uv.x * MAP_RECT.size.x, uv.y * MAP_RECT.size.y)

## Alternating band tint per tier, plus the bottom band-scale labels.
## Boundaries derived from StarChart.pursuit_reduction_at() (tier depth)
## and each tier's actual node x-positions - never a hardcoded pixel
## value (spec §6.1).
func _draw_bands() -> void:
	var tier_us: Dictionary[int, Array] = {}
	for coordinate in StarChart.all_coordinates():
		var tier := 0 if coordinate == StarChart.START else -StarChart.pursuit_reduction_at(coordinate)
		if not tier_us.has(tier):
			tier_us[tier] = []
		(tier_us[tier] as Array).append(_screen_pos(coordinate).x)

	var tiers: Array = tier_us.keys()
	tiers.sort()

	var bounds: Array[float] = [MAP_RECT.position.x]
	for i in range(tiers.size() - 1):
		var this_max: float = (tier_us[tiers[i]] as Array).max()
		var next_min: float = (tier_us[tiers[i + 1]] as Array).min()
		bounds.append((this_max + next_min) / 2.0)
	bounds.append(MAP_RECT.position.x + MAP_RECT.size.x)

	var label_font := WolfAttackTokens.font("T_BAND_GUTTER")
	var label_size := WolfAttackTokens.font_size("T_BAND_GUTTER")
	for i in tiers.size():
		var x0: float = bounds[i]
		var x1: float = bounds[i + 1]
		if i % 2 == 0:
			draw_rect(Rect2(x0, MAP_RECT.position.y, x1 - x0, MAP_RECT.size.y), Color(1, 1, 1, 0.03))

		var tier: int = tiers[i]
		var label := "START" if tier == 0 else "-%d" % tier
		var center_x := (x0 + x1) / 2.0
		draw_string(label_font, Vector2(center_x - 40.0, MAP_RECT.position.y + MAP_RECT.size.y + 26.0), label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, label_size, WolfAttackTokens.INK_DIM)

## All 41 edges - static topology, on every player's paper chart, so
## nothing here is a secret (spec §6.2). Flat neutral, never brightened.
func _draw_edges() -> void:
	var drawn: Dictionary[String, bool] = {}
	for coordinate in StarChart.all_coordinates():
		for neighbor in StarChart.neighbors_of(coordinate):
			var key := _edge_key(coordinate, neighbor)
			if drawn.has(key):
				continue
			drawn[key] = true
			draw_line(_screen_pos(coordinate), _screen_pos(neighbor), Color(1, 1, 1, 0.16), 2.0)

static func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

## The path tree (§6.3) - each tree edge drawn once, coloured by
## whichever group is still on it, dead segments in neutral grey. A
## branch pair that isn't a real graph edge (a multi-hop jump) draws as
## a dashed bowed arc instead of a straight line, per §6.3's "render
## these as a dashed quadratic arc... so a mis-jump or host correction
## is visually obvious".
func _draw_trails() -> void:
	var path_tree: Dictionary = view.get("path_tree", {})
	for branch: Dictionary in (path_tree.get("branches", []) as Array):
		var nodes: Array = branch["nodes"]
		var is_dead: bool = branch["state"] == "dead"
		var colour: Color = Color(0.62, 0.62, 0.66, 0.35) if is_dead else _branch_colour(branch)
		var width: float = 3.0 if is_dead else (5.0 if bool(branch.get("primary", false)) else 3.5)
		for i in range(nodes.size() - 1):
			var from: String = nodes[i]
			var to: String = nodes[i + 1]
			var from_pos := _screen_pos(from)
			var to_pos := _screen_pos(to)
			if to in StarChart.neighbors_of(from):
				draw_line(from_pos, to_pos, colour, width)
			else:
				_draw_dashed_arc(from_pos, to_pos, colour, width)

func _branch_colour(branch: Dictionary) -> Color:
	var group_id: String = branch.get("group", "")
	for group: Dictionary in (view.get("groups", []) as Array):
		if group["id"] == group_id:
			return Color(String((group["representative"] as Dictionary)["colour"]))
	return WolfAttackTokens.INK

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

## Five node states (§6.4). Letter/name/class only ever came from
## `view` in the first place - see this file's own header comment.
func _draw_nodes() -> void:
	var coord_font := WolfAttackTokens.font("T_STAT")
	var coord_size := WolfAttackTokens.font_size("T_STAT")
	var letter_font := WolfAttackTokens.font("T_WOLF_CODE")
	var letter_size := WolfAttackTokens.font_size("T_WOLF_CODE")
	var chip_font := WolfAttackTokens.font("T_CHIP")
	var chip_size := WolfAttackTokens.font_size("T_CHIP")

	for node: Dictionary in (view.get("nodes", []) as Array):
		var coordinate: String = node["id"]
		var pos := _screen_pos(coordinate)
		var state: String = node["state"]

		if node.has("class"):
			var fill: Color = CLASS_TINT.get(node["class"], Color("#3A4048"))
			fill.a = 0.85
			draw_circle(pos, NODE_RADIUS, fill)

		var ring := Color(1, 1, 1, 0.25)
		var ring_width := 2.0
		match state:
			"reported":
				ring = WolfAttackTokens.AMBER
				ring_width = 3.0
			"visited":
				ring = WolfAttackTokens.INK
				ring_width = 4.0
			"occupied":
				ring = WolfAttackTokens.INK
				ring_width = 4.0
			"destination":
				ring = WolfAttackTokens.CYAN
				ring_width = 4.0
		draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32, ring, ring_width, true)
		if state == "occupied":
			draw_arc(pos, NODE_RADIUS + 5.0, 0.0, TAU, 32, ring, 1.5, true)
		if state == "destination":
			draw_arc(pos, NODE_RADIUS + 9.0, 0.0, TAU, 32, WolfAttackTokens.CYAN, 1.5, false)

		draw_string(coord_font, pos + Vector2(NODE_RADIUS + 4.0, 4.0), coordinate, HORIZONTAL_ALIGNMENT_LEFT, -1, coord_size, Color(1, 1, 1, 0.4))

		if node.has("letter"):
			draw_string(letter_font, Vector2(pos.x - 30.0, pos.y + 8.0), String(node["letter"]), HORIZONTAL_ALIGNMENT_CENTER, 60.0, letter_size, WolfAttackTokens.INK)

		if node.has("claims"):
			var chip_y := pos.y + NODE_RADIUS + 16.0
			for claim: Variant in (node["claims"] as Array):
				var claim_dict: Dictionary = claim
				var text := "REPORTED · %s: \"%s\"" % [claim_dict["source"], claim_dict["text"]]
				draw_string(chip_font, Vector2(pos.x - 70.0, chip_y), text, HORIZONTAL_ALIGNMENT_LEFT, 240.0, chip_size, WolfAttackTokens.AMBER)
				chip_y += 18.0

## One token per group (§4.1/§6.5) - the display collapses the fleet,
## never draws a token per ship.
func _draw_group_tokens() -> void:
	var abbr_font := WolfAttackTokens.font("T_SEC")
	var abbr_size := WolfAttackTokens.font_size("T_SEC")

	for group: Dictionary in (view.get("groups", []) as Array):
		var pos := _screen_pos(String(group["at"])) + Vector2(TOKEN_RADIUS + 12.0, -(TOKEN_RADIUS + 12.0))
		var representative: Dictionary = group["representative"]
		var colour := Color(String(representative["colour"]))
		draw_circle(pos, TOKEN_RADIUS, colour)
		if bool(representative["is_aegis"]):
			draw_arc(pos, TOKEN_RADIUS + 2.0, 0.0, TAU, 32, WolfAttackTokens.INK, 2.5, true)

		var member_count: int = (group["members"] as Array).size()
		var label: String = String(representative["abbr"])
		if member_count > 1:
			label += " +%d" % (member_count - 1)

		draw_string(abbr_font, Vector2(pos.x - TOKEN_RADIUS - 20.0, pos.y + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, (TOKEN_RADIUS + 20.0) * 2.0, abbr_size, _readable_text_color(colour))

static func _readable_text_color(bg: Color) -> Color:
	var luminance := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color.BLACK if luminance > 0.6 else WolfAttackTokens.INK
