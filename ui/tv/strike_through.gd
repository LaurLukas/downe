class_name StrikeThrough
extends Control

## A single horizontal line across the control's own rect, marking a
## destroyed wolf token per wolf_attack_tv_display_v3_lanes.md §4.4 ("1px
## strikethrough across the token"). The .md spec and its own README
## disagreed on whether a destroyed token dims as a whole (this file's
## approach, whole-token alpha 0.3) or only in its contents (README:
## full opacity, colour-only) - the user's explicit call was the former,
## see TODO.md.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var y := size.y * 0.5
	draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(WolfAttackTokens.INK_GHOST, 0.7), 1.0)
