class_name WolfCodePips
extends Control

## One line combining a wolf ship's class code, its damage pips, and (for
## hulls that return - Battlestation and Fighter Wing) an inline "↻",
## drawn together in one _draw() per
## wolf_attack_tv_display_v2_gap_spec.md §4.5 step 6 (returns glyph
## inline, not on its own line) and step 5 (pips carry damage state:
## filled = remaining, hollow = damage taken, hollow first/leftmost -
## "CR ○ ● ●" is a cruiser with 1 of 3 capacity taken).
##
## v3 addition (wolf_attack_tv_display_v3_lanes.md §4.4): a destroyed
## wolf renders with EVERY pip hollow, not just the ones matching its
## damage_taken at the moment it died - "nothing remains" is the signal,
## regardless of how much capacity was left when it went down.

const PIP_RADIUS := 5.0
const PIP_GAP := 14.0

var code_text: String = ""
var capacity: int = 0
var damage_taken: int = 0
var show_returns: bool = false
var destroyed: bool = false
## Optional overrides so callers building compact (smaller) tokens can
## reuse this same drawing logic at a different scale/font rather than
## duplicating it - defaults reproduce the original full-form sizing.
var font_token: String = "T_WOLF_CODE"
var pip_radius: float = PIP_RADIUS
var pip_gap: float = PIP_GAP

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color := WolfAttackTokens.INK_GHOST if destroyed else WolfAttackTokens.INK
	var font := WolfAttackTokens.font(font_token)
	var font_size := WolfAttackTokens.font_size(font_token)
	var baseline := Vector2(0.0, font_size * 0.8)
	draw_string(font, baseline, code_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	var code_width := font.get_string_size(code_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pip_y := baseline.y - font_size * 0.32
	var x := code_width + 18.0
	var hollow_count := capacity if destroyed else damage_taken
	var filled_count := 0 if destroyed else maxi(capacity - damage_taken, 0)
	for _i in hollow_count:
		draw_arc(Vector2(x, pip_y), pip_radius, 0.0, TAU, 16, color, 1.5)
		x += pip_gap
	for _i in filled_count:
		draw_circle(Vector2(x, pip_y), pip_radius, color)
		x += pip_gap

	if show_returns and not destroyed:
		draw_string(font, Vector2(x + 2.0, baseline.y), "↻", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, WolfAttackTokens.INK_DIM)
