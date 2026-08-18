class_name TargetingLines
extends Control

## Draws a dashed curved line from each Wolf token down to its target's
## fleet card, matching Wolf_Ships-selection.png. Sits above WolfGrid
## and FleetRow (same parent, added after them, plus mouse_filter
## IGNORE so it never blocks anything on a read-only screen) and reads
## their children's actual laid-out positions each frame - Godot only
## finalizes container layout after a process frame, and this screen's
## content rebuilds every GameState.mutated, so redrawing once
## immediately after rebuilding would often draw against stale
## positions. Redrawing every frame is simpler than chasing that
## timing exactly, and cheap for a handful of line segments.

var links: Array[Dictionary] = []  # [{"from": Control, "to": Control, "color": Color}]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func set_links(new_links: Array[Dictionary]) -> void:
	links = new_links
	queue_redraw()

func _draw() -> void:
	for link: Dictionary in links:
		var from: Control = link["from"]
		var to: Control = link["to"]
		if not is_instance_valid(from) or not is_instance_valid(to):
			continue
		var start := _to_local(from.get_global_rect().get_center() + Vector2(0, from.size.y * 0.5))
		var end := _to_local(to.get_global_rect().get_center() - Vector2(0, to.size.y * 0.5))
		_draw_dashed_curve(start, end, link.get("color", WolfDisplayPalette.WOLF_RED))

func _to_local(global_point: Vector2) -> Vector2:
	return global_point - get_global_rect().position

## Quadratic bezier sagging downward between the two points, drawn as
## short dashes rather than a solid line.
func _draw_dashed_curve(from: Vector2, to: Vector2, color: Color) -> void:
	var control := Vector2((from.x + to.x) * 0.5, maxf(from.y, to.y) + 40.0)
	var segments := 40
	var points: Array[Vector2] = []
	for i in range(segments + 1):
		var t := float(i) / segments
		var point := from.lerp(control, t).lerp(control.lerp(to, t), t)
		points.append(point)

	var dash_on := true
	var since_toggle := 0
	const DASH_LENGTH := 3
	for i in range(points.size() - 1):
		if dash_on:
			draw_line(points[i], points[i + 1], color, 2.0)
		since_toggle += 1
		if since_toggle >= DASH_LENGTH:
			since_toggle = 0
			dash_on = not dash_on

	draw_circle(to, 4.0, color)
