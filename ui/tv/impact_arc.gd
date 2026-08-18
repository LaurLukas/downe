class_name ImpactArc
extends Control

## v3 lane layout's single continuous range-band curve, replacing v2's
## RangeBands (LONG/MEDIUM/SHORT gutter labels + three separate arcs -
## deleted per wolf_attack_tv_display_v3_lanes.md §7: "range is a global
## phase, not a spatial position"). Spans the full content width and is
## drawn once here, not per lane, so it stays one continuous curve across
## every lane regardless of lane count (§10's own instruction).
##
## Geometry is the README's exact control points, read as offsets inside a
## local 1730×80 box positioned at (SAFE_MARGIN_X, impact_y - 40):
## medium "M 0 42 Q 865 20 1730 42", long "M 0 46 Q 865 26 1730 46",
## short "M 0 40 Q 865 60 1730 40".
##
## Not implemented: the ±14px control-point "settle" tween on phase
## change (§6.2). This project's established pattern for a first
## structural pass is data/geometry-correct now, animation-polish later
## (see TODO.md's own P0/P1/P2 split for the v2 build) - there is no way
## to visually verify a tween's feel without a human watching a live
## window, so it's deferred rather than guessed at.

const CURVES: Dictionary[String, Dictionary] = {
	"range_long": {"p0_y": 46.0, "control_y": 26.0, "p2_y": 46.0},
	"range_medium": {"p0_y": 42.0, "control_y": 20.0, "p2_y": 42.0},
	"range_short": {"p0_y": 40.0, "control_y": 60.0, "p2_y": 40.0},
}

var active_phase: String = "":
	set(value):
		active_phase = value
		queue_redraw()

var impact_y: float = 626.0:
	set(value):
		impact_y = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not CURVES.has(active_phase):
		return
	var curve: Dictionary = CURVES[active_phase]
	var box_top := impact_y - 40.0
	var left := WolfAttackTokens.SAFE_MARGIN_X
	var width := WolfAttackTokens.CONTENT_RIGHT - WolfAttackTokens.SAFE_MARGIN_X
	var p0 := Vector2(left, box_top + curve["p0_y"])
	var control := Vector2(left + width * 0.5, box_top + curve["control_y"])
	var p2 := Vector2(left + width, box_top + curve["p2_y"])

	var points := PackedVector2Array()
	var segments := 64
	for i in range(segments + 1):
		var t := float(i) / segments
		points.append(p0.lerp(control, t).lerp(control.lerp(p2, t), t))

	draw_polyline(points, Color(WolfAttackTokens.CYAN, 0.12), 9.0, true)
	draw_polyline(points, Color(WolfAttackTokens.CYAN, 0.75), 2.5, true)
