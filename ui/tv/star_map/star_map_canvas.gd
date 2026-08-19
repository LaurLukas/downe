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
## Deliberately NOT built this pass (see TODO.md): the animated locator
## pulse (§4.2 - drawn here as a static ring at rest scale instead,
## same "structural now, Tween later" call the Wolf Attack screen's own
## v1 pass made); per-chip/per-token collision avoidance (§4.1/§4.3 -
## chips/tokens use a fixed default slot, not the spec's "push to
## another quadrant when taken" logic, which needs knowing where every
## other chip on screen landed); the group token's index disc and
## "damaged member" DMG tag (needs a ship-damage definition that isn't
## settled - see TODO.md); the new tests/test_star_map_layout.gd file.

const TOKEN_RADIUS := 26.0
const INK := Color(0.03, 0.04, 0.08)

var view: Dictionary = {}:
	set(value):
		view = value
		queue_redraw()

func _draw() -> void:
	if view.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, StarMapTokens.CANVAS_SIZE), StarMapTokens.BG)
	_draw_glow_layer()
	_draw_bands()
	_draw_edges()
	_draw_trails()
	_draw_nodes()
	_draw_group_tokens()
	_draw_legend()

func _screen_pos(coordinate: String) -> Vector2:
	var uv := StarChart.node_position(coordinate)
	return StarMapTokens.node_screen_pos(uv.x, uv.y)

static func _tier_of(coordinate: String) -> int:
	return 0 if coordinate == StarChart.START else -StarChart.pursuit_reduction_at(coordinate)

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
	var label_size := WolfAttackTokens.font_size("T_BAND_GUTTER")
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
	var label_font := WolfAttackTokens.font("T_CHIP")
	var label_size := WolfAttackTokens.font_size("T_CHIP")
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

func _draw_nodes() -> void:
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
		var radius: float = StarMapTokens.NODE_RADIUS_LARGE if is_large else StarMapTokens.NODE_RADIUS_SMALL
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
			draw_string(letter_font, Vector2(pos.x - radius, pos.y + 15.0), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 42, letter_colour)
		else:
			draw_string(coord_font, Vector2(pos.x - radius, pos.y + 8.0), coordinate, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 24, Color("#7E8EA6"))

		_draw_info_chip(node, pos, radius, chip_font)

## Corner-bracket locator (§4.2) - static at rest scale, no pulse. See
## this file's header note on why the animation itself is deferred.
func _draw_locator(center: Vector2, colour: Color) -> void:
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
func _draw_info_chip(node: Dictionary, pos: Vector2, radius: float, font: Font) -> void:
	var state: String = node["state"]
	if state != "visited" and state != "occupied" and state != "reported":
		return

	var coordinate: String = node["id"]
	var above := coordinate == StarChart.START
	var chip_height := 26.0
	var chip_y := (pos.y - radius - 8.0 - chip_height) if above else (pos.y + radius + 8.0)

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

	var width := 260.0
	var rect := Rect2(pos.x - width / 2.0, chip_y, width, chip_height)
	draw_rect(rect, Color(0.03, 0.04, 0.08, 0.85))
	if dashed:
		_draw_dashed_rect(rect, colour, 1.0)
	else:
		draw_rect(rect, colour, false, 1.0)
	draw_string(font, Vector2(rect.position.x, chip_y + chip_height - 8.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, 20, colour)

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
func _draw_group_tokens() -> void:
	var abbr_font := WolfAttackTokens.font("T_SEC")
	var abbr_size := WolfAttackTokens.font_size("T_SEC")

	for group: Dictionary in (view.get("groups", []) as Array):
		var pos := _screen_pos(String(group["at"])) + Vector2(TOKEN_RADIUS + 14.0, -(TOKEN_RADIUS + 14.0))
		var representative: Dictionary = group["representative"]
		var is_aegis: bool = bool(representative["is_aegis"])
		var colour := StarMapTokens.group_colour(is_aegis)

		draw_circle(pos, TOKEN_RADIUS, colour)
		if is_aegis:
			draw_arc(pos, TOKEN_RADIUS + 2.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)

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
		draw_string(font, Vector2(x0 + 26.0, y + 6.0), String(item["label"]), HORIZONTAL_ALIGNMENT_LEFT, slot - 30.0, 18, StarMapTokens.TEXT_SECONDARY)
