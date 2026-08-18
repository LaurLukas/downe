class_name LaneSpines
extends Control

## The one attack-vector graphic v3 keeps (wolf_attack_tv_display_v3_lanes.md
## §3/§10): one vertical bar per attacked lane, from the bottom of its
## stack zone down through the card's top edge. One _draw() for every
## spine, not a node per lane (§11 - "do not create a Line2D per lane"),
## matching this project's existing single-overlay-Control pattern
## (targeting_lines.gd/range_bands.gd before it).

var _spines: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Each entry: {"x": center-x, "width": px, "top": y, "bottom": y}.
func set_spines(spines: Array[Dictionary]) -> void:
	_spines = spines
	queue_redraw()

func _draw() -> void:
	var color := Color(WolfAttackTokens.ALERT, 0.75)
	for spine: Dictionary in _spines:
		var x: float = spine["x"]
		var half_w: float = spine["width"] * 0.5
		var rect := Rect2(x - half_w, spine["top"], spine["width"], spine["bottom"] - spine["top"])
		draw_rect(rect, color)
