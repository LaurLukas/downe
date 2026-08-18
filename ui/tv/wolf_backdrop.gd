class_name WolfBackdrop
extends Control

## Backdrop behind the Wolf Attack STANDING layout -
## wolf_attack_tv_display_v2_gap_spec.md §4.1 (P0-03). Static per attack
## (doesn't redraw on GameState.mutated), so this is built once in
## _ready(), not every refresh.
##
## Flat BG_DEEP fill for now, on the user's explicit instruction ("do the
## whole background in a single dark color") after looking at the P0
## pass running - the spec's gradient + crimson corner bloom is not
## currently built. See TODO.md if that changes again.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.color = WolfAttackTokens.BG_DEEP
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
