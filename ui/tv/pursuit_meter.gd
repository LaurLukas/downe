class_name PursuitMeter
extends Control

## Ten-cell pursuit track, drawn in one _draw() call per
## wolf_attack_tv_display_v2_gap_spec.md §4.3 (P1-15) instead of ten
## ColorRect nodes. Cells 1..pursuit are amber; the rest are dark navy
## with a border; cell 10 is always crimson when unfilled, since it's the
## game-over slot and should read as menacing even at pursuit 0.

const CELL_SIZE := Vector2(30.0, 26.0)
const GAP := 5.0

var pursuit: int = 0:
	set(value):
		pursuit = value
		queue_redraw()

func _draw() -> void:
	for i in PursuitTrack.MAX_VALUE:
		var rect := Rect2(Vector2(i * (CELL_SIZE.x + GAP), 0.0), CELL_SIZE)
		if i < pursuit:
			draw_rect(rect, WolfAttackTokens.AMBER)
		elif i == PursuitTrack.MAX_VALUE - 1:
			draw_rect(rect, WolfAttackTokens.PURSUIT_DOOM)
		else:
			draw_rect(rect, WolfAttackTokens.PURSUIT_EMPTY_FILL)
			draw_rect(rect, WolfAttackTokens.PURSUIT_EMPTY_BORDER, false, 1.0)
