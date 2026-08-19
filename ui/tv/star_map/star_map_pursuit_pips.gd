class_name StarMapPursuitPips
extends Control

## 10-cell pursuit pip row for a Star Map rail group card
## (ui/design_handoff_star_map/star_map_tv_visual_implementation.md
## §6.1: "PURSUIT ▮▮▮▮▯▯▯▯▨▨ 4", 18×15 cells, 3px gap, last two cells
## shaded as the danger zone). Mirrors ui/tv/pursuit_meter.gd's
## established "one _draw() call, no per-cell ColorRects" pattern for
## the Wolf Attack screen's own pursuit meter, but with this screen's
## own colours (CLAIM fill, WOLF danger zone) rather than that screen's
## AMBER/PURSUIT_DOOM - the two screens' meters look different on
## purpose, matching each screen's own palette.

const CELL_SIZE := Vector2(18.0, 15.0)
const GAP := 3.0

var value: int = 0:
	set(v):
		value = v
		queue_redraw()

func _draw() -> void:
	for i in PursuitTrack.MAX_VALUE:
		var rect := Rect2(Vector2(i * (CELL_SIZE.x + GAP), 0.0), CELL_SIZE)
		var in_danger_zone := i >= PursuitTrack.MAX_VALUE - 2
		if i < value:
			draw_rect(rect, StarMapTokens.CLAIM)
		elif in_danger_zone:
			draw_rect(rect, Color(StarMapTokens.WOLF.r, StarMapTokens.WOLF.g, StarMapTokens.WOLF.b, 0.28))
		else:
			draw_rect(rect, Color(1, 1, 1, 0.08))
			draw_rect(rect, Color(1, 1, 1, 0.18), false, 1.0)

## Godot won't allocate real space for a bare _draw()-only Control
## otherwise - same lesson this project already learned the hard way
## building the Wolf Attack lane tokens (TODO.md's "content-aware
## sizing" bug writeups), applied up front here instead of found later.
func _get_minimum_size() -> Vector2:
	return Vector2(PursuitTrack.MAX_VALUE * (CELL_SIZE.x + GAP) - GAP, CELL_SIZE.y)
