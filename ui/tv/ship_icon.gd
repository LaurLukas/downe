class_name ShipIcon
extends Control

## Hand-drawn vector silhouette for one Wolf ship class or fleet ship,
## matching Wolf_Ships-selection.png's outline/stroke art style
## (no fill, light-colored strokes). Parameterized by icon_id + color
## so one script covers every class instead of one scene per ship -
## same "data, not a class per instance" pattern as CraftDefinitions.
##
## First pass, not pixel-matched: these shapes were hand-derived from
## looking at the reference image, not measured from it, and this
## project has no way to render/screenshot a live Godot window to
## check the result - see TODO.md. Expect to need visual adjustment
## once someone actually looks at these running.

@export var icon_id: String = "":
	set(value):
		icon_id = value
		queue_redraw()
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()
@export var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()

func _draw() -> void:
	var s := size
	match icon_id:
		"battlestation":
			_draw_battlestation(s)
		"strikecarrier":
			_draw_strikecarrier(s)
		"cruiser":
			_draw_cruiser(s)
		"assault_transport":
			_draw_assault_transport(s)
		"destroyer":
			_draw_destroyer(s)
		"fighter_wing":
			_draw_fighter_wing(s)
		"aegis":
			_draw_aegis(s)
		"dione":
			_draw_dione(s)
		"icebreaker":
			_draw_icebreaker(s)
		"quellon":
			_draw_quellon(s)
		"shepherd":
			_draw_shepherd(s)
		"refinery_124":
			_draw_refinery(s)

func _poly(points: PackedVector2Array) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, icon_color, line_width, true)

func _rect_outline(top_left: Vector2, rect_size: Vector2) -> void:
	draw_rect(Rect2(top_left, rect_size), icon_color, false, line_width)

## Blocky hexagonal hull with two forward prongs and small side fins.
func _draw_battlestation(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.10, h * 0.5),
		Vector2(w * 0.22, h * 0.22),
		Vector2(w * 0.68, h * 0.18),
		Vector2(w * 0.90, h * 0.35),
		Vector2(w * 0.90, h * 0.65),
		Vector2(w * 0.68, h * 0.82),
		Vector2(w * 0.22, h * 0.78),
	]))
	draw_line(Vector2(w * 0.90, h * 0.40), Vector2(w * 1.0, h * 0.30), icon_color, line_width)
	draw_line(Vector2(w * 0.90, h * 0.60), Vector2(w * 1.0, h * 0.70), icon_color, line_width)
	_rect_outline(Vector2(w * 0.35, h * 0.35), Vector2(w * 0.08, h * 0.08))
	_rect_outline(Vector2(w * 0.48, h * 0.35), Vector2(w * 0.08, h * 0.08))

## Elongated torpedo shape - pointed nose, tapering tail fin.
func _draw_strikecarrier(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.05, h * 0.42),
		Vector2(w * 0.05, h * 0.58),
		Vector2(w * 0.55, h * 0.62),
		Vector2(w * 0.80, h * 0.5),
		Vector2(w * 0.55, h * 0.38),
	]))
	draw_line(Vector2(w * 0.80, h * 0.5), Vector2(w * 0.95, h * 0.35), icon_color, line_width)
	draw_line(Vector2(w * 0.80, h * 0.5), Vector2(w * 0.95, h * 0.65), icon_color, line_width)
	_rect_outline(Vector2(w * 0.15, h * 0.44), Vector2(w * 0.10, h * 0.12))

## Simple arrow/wedge.
func _draw_cruiser(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.10, h * 0.35),
		Vector2(w * 0.10, h * 0.65),
		Vector2(w * 0.55, h * 0.65),
		Vector2(w * 0.90, h * 0.5),
		Vector2(w * 0.55, h * 0.35),
	]))
	_rect_outline(Vector2(w * 0.20, h * 0.42), Vector2(w * 0.08, h * 0.16))

## Boxy hull with a pointed beak and small deck notches.
func _draw_assault_transport(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.15, h * 0.3),
		Vector2(w * 0.85, h * 0.3),
		Vector2(w * 0.85, h * 0.7),
		Vector2(w * 0.15, h * 0.7),
		Vector2(w * 0.02, h * 0.5),
	]))
	for i in 4:
		_rect_outline(Vector2(w * (0.28 + i * 0.15), h * 0.38), Vector2(w * 0.08, h * 0.1))

## Twin thin hulls with crossing struts between them.
func _draw_destroyer(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	draw_line(Vector2(w * 0.08, h * 0.28), Vector2(w * 0.92, h * 0.28), icon_color, line_width)
	draw_line(Vector2(w * 0.08, h * 0.72), Vector2(w * 0.92, h * 0.72), icon_color, line_width)
	draw_line(Vector2(w * 0.15, h * 0.28), Vector2(w * 0.85, h * 0.72), icon_color, line_width)
	draw_line(Vector2(w * 0.85, h * 0.28), Vector2(w * 0.15, h * 0.72), icon_color, line_width)
	draw_line(Vector2(w * 0.08, h * 0.28), Vector2(w * 0.08, h * 0.72), icon_color, line_width)
	draw_line(Vector2(w * 0.92, h * 0.28), Vector2(w * 0.92, h * 0.72), icon_color, line_width)

## Three loose single-seat fighter chevrons.
func _draw_fighter_wing(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	var offsets: Array[Vector2] = [Vector2(0.0, 0.15), Vector2(0.28, 0.4), Vector2(0.05, 0.6)]
	for offset in offsets:
		var ox := w * offset.x
		var oy := h * offset.y
		_poly(PackedVector2Array([
			Vector2(ox + w * 0.02, oy + h * 0.02),
			Vector2(ox + w * 0.20, oy + h * 0.10),
			Vector2(ox + w * 0.02, oy + h * 0.18),
			Vector2(ox + w * 0.08, oy + h * 0.10),
		]))

## Boxy elongated military hull, slight forward taper.
func _draw_aegis(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.05, h * 0.4),
		Vector2(w * 0.05, h * 0.6),
		Vector2(w * 0.6, h * 0.65),
		Vector2(w * 0.95, h * 0.5),
		Vector2(w * 0.6, h * 0.35),
	]))

## Elongated liner with porthole marks.
func _draw_dione(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.05, h * 0.45),
		Vector2(w * 0.05, h * 0.55),
		Vector2(w * 0.85, h * 0.58),
		Vector2(w * 0.95, h * 0.5),
		Vector2(w * 0.85, h * 0.42),
	]))
	for i in 4:
		_rect_outline(Vector2(w * (0.2 + i * 0.15), h * 0.46), Vector2(w * 0.05, w * 0.05))

## Wedge/arrow, pointed front.
func _draw_icebreaker(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.08, h * 0.4),
		Vector2(w * 0.08, h * 0.6),
		Vector2(w * 0.5, h * 0.6),
		Vector2(w * 0.95, h * 0.5),
		Vector2(w * 0.5, h * 0.4),
	]))

## Rounded/bulbous hull, approximated with a soft polyline curve.
func _draw_quellon(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	var points := PackedVector2Array()
	var segments := 16
	for i in range(segments + 1):
		var t := float(i) / segments * PI
		points.append(Vector2(w * 0.5 - cos(t) * w * 0.42, h * 0.5 - sin(t) * h * 0.28))
	draw_polyline(points, icon_color, line_width, true)
	draw_line(points[0], points[segments], icon_color, line_width)

## Elongated hull with dome bumps on top (hydroponics domes).
func _draw_shepherd(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.08, h * 0.5),
		Vector2(w * 0.15, h * 0.65),
		Vector2(w * 0.85, h * 0.65),
		Vector2(w * 0.92, h * 0.5),
		Vector2(w * 0.85, h * 0.4),
		Vector2(w * 0.15, h * 0.4),
	]))
	for i in 3:
		draw_arc(Vector2(w * (0.32 + i * 0.18), h * 0.38), w * 0.06, PI, TAU, 12, icon_color, line_width)

## Industrial hull with vertical tank/bar details.
func _draw_refinery(s: Vector2) -> void:
	var w := s.x
	var h := s.y
	_poly(PackedVector2Array([
		Vector2(w * 0.08, h * 0.35),
		Vector2(w * 0.08, h * 0.65),
		Vector2(w * 0.75, h * 0.65),
		Vector2(w * 0.92, h * 0.5),
		Vector2(w * 0.75, h * 0.35),
	]))
	for i in 4:
		draw_line(Vector2(w * (0.2 + i * 0.12), h * 0.4), Vector2(w * (0.2 + i * 0.12), h * 0.6), icon_color, line_width)
