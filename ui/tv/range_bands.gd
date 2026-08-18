class_name RangeBands
extends Control

## Left-gutter LONG/MEDIUM/SHORT labels + a curved arc marking the active
## range band, per wolf_attack_tv_display_v2_gap_spec.md §4.6 (P0-05).
## Only meaningful during the three range phases - the caller hides this
## node during "targeting" (see WolfAttackDisplay._refresh_standing()).
##
## Arc geometry: the spec gives one fully-specified example (the MEDIUM
## arc: p0=(65,500), control=(960,452), p2=(1855,500) - an edge-to-apex
## delta of 48px) but only apex y-values for LONG (400) and SHORT (590),
## not their edge y's. Applying that same 48px delta to all three bands
## is the simplest reading consistent with the one fully-specified
## example; exact per-band calibration is a visual-QA follow-up, not a
## rules question, so this isn't a "verify against source" case.

const ARC_EDGE_DELTA := 48.0
const BANDS: Array[Dictionary] = [
	{"phase": "range_long", "label": "LONG", "gutter_y": 380.0, "apex_y": 400.0},
	{"phase": "range_medium", "label": "MEDIUM", "gutter_y": 478.0, "apex_y": 478.0},
	{"phase": "range_short", "label": "SHORT", "gutter_y": 573.0, "apex_y": 590.0},
]

var active_phase: String = "":
	set(value):
		active_phase = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for band: Dictionary in BANDS:
		var active: bool = band["phase"] == active_phase
		var edge_y: float = band["apex_y"] + ARC_EDGE_DELTA
		_draw_arc(band["apex_y"], edge_y, active)
		_draw_gutter_label(band["label"], band["gutter_y"], active)

func _draw_arc(apex_y: float, edge_y: float, active: bool) -> void:
	var p0 := Vector2(65.0, edge_y)
	var control := Vector2(960.0, apex_y)
	var p2 := Vector2(1855.0, edge_y)
	var points := PackedVector2Array()
	var segments := 64
	for i in range(segments + 1):
		var t := float(i) / segments
		points.append(p0.lerp(control, t).lerp(control.lerp(p2, t), t))
	if active:
		draw_polyline(points, WolfAttackTokens.CYAN, 2.0, true)
	else:
		_draw_dashed_polyline(points, WolfAttackTokens.RULE, 1.0)

func _draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var dash_on := true
	var since_toggle := 0
	const DASH_LENGTH := 4
	for i in range(points.size() - 1):
		if dash_on:
			draw_line(points[i], points[i + 1], color, width)
		since_toggle += 1
		if since_toggle >= DASH_LENGTH:
			since_toggle = 0
			dash_on = not dash_on

func _draw_gutter_label(text: String, y: float, active: bool) -> void:
	var token := "T_BAND_ACTIVE" if active else "T_BAND_GUTTER"
	var color := WolfAttackTokens.CYAN if active else WolfAttackTokens.INK_GHOST
	var font := WolfAttackTokens.font(token)
	var size := WolfAttackTokens.font_size(token)
	draw_string(font, Vector2(WolfAttackTokens.SAFE_MARGIN_X, y + size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
