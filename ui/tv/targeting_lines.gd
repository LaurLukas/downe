class_name TargetingLines
extends Control

## Draws a dashed red bezier curve from each wolf ship down to the top
## edge of its target's fleet card, per
## wolf_attack_tv_display_v2_gap_spec.md §4.7 (P0-06). Sits above
## RangeBands and below FleetRow in draw order (same parent, added after
## bands, before cards visually overlap it) and reads each linked node's
## actual laid-out x-position every frame, since this screen's content
## rebuilds on every GameState.mutated and Godot only finalizes container
## layout after a process frame - redrawing once immediately after a
## rebuild would often draw against stale positions. Redrawing every
## frame is simpler than chasing that timing exactly, and cheap for a
## handful of curves. mouse_filter IGNORE since this is a read-only
## overlay with nothing underneath it to block.

var links: Array[Dictionary] = []  # [{"from": Control, "to": Control}]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func set_links(new_links: Array[Dictionary]) -> void:
	links = new_links
	queue_redraw()

func _draw() -> void:
	var impact_points: Array[Vector2] = []
	for link: Dictionary in links:
		var from: Control = link["from"]
		var to: Control = link["to"]
		if not is_instance_valid(from) or not is_instance_valid(to):
			continue
		var origin := _to_local(Vector2(from.get_global_rect().get_center().x, WolfAttackTokens.Y_VECTOR_ORIGIN))
		var terminus := _to_local(Vector2(to.get_global_rect().get_center().x, WolfAttackTokens.Y_FLEET_CARD_TOP))
		_draw_dashed_bezier(origin, terminus)
		if not impact_points.has(terminus):
			impact_points.append(terminus)
	for point in impact_points:
		draw_circle(point, 4.0, WolfAttackTokens.ALERT)

func _to_local(global_point: Vector2) -> Vector2:
	return global_point - get_global_rect().position

## Cubic bezier with vertically-pulled control points (§4.7's "S-curve
## that fans outward near the top and converges at the card"), drawn as
## alternating dash/gap segments instead of a solid line.
func _draw_dashed_bezier(origin: Vector2, terminus: Vector2) -> void:
	var c1 := origin + Vector2(0.0, 60.0)
	var c2 := terminus - Vector2(0.0, 70.0)
	var segments := 48
	var points: Array[Vector2] = []
	for i in range(segments + 1):
		var t := float(i) / segments
		points.append(origin.bezier_interpolate(c1, c2, terminus, t))

	var color := Color(WolfAttackTokens.ALERT, 0.75)
	const DASH_LENGTH := 10.0
	const GAP_LENGTH := 8.0
	var distance_since_toggle := 0.0
	var dash_on := true
	for i in range(points.size() - 1):
		var segment_length := points[i].distance_to(points[i + 1])
		if dash_on:
			draw_line(points[i], points[i + 1], color, 1.5)
		distance_since_toggle += segment_length
		var threshold := DASH_LENGTH if dash_on else GAP_LENGTH
		if distance_since_toggle >= threshold:
			distance_since_toggle = 0.0
			dash_on = not dash_on
