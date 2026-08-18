class_name WolfDisplayPalette
extends RefCounted

## Colors for the Wolf Attack TV screen, matched to
## Wolf_Ships-selection.png (the reference mockup the user asked this
## screen to match) - which uses a noticeably different ship-identity
## palette than wolf_attack_tv_display.md's original written color
## table. The image is the current target; this supersedes that table
## for this screen.

const BG := Color(0.043, 0.055, 0.078)
const PANEL := Color(0.078, 0.098, 0.129)
const PANEL_RAISED := Color(0.114, 0.145, 0.192)
const RULE := Color(0.165, 0.204, 0.267)
const TEXT_PRIMARY := Color(0.910, 0.929, 0.961)
const TEXT_MUTED := Color(0.478, 0.525, 0.6)
const WOLF_RED := Color(0.851, 0.290, 0.290)
const WOLF_DIM := Color(0.361, 0.149, 0.149)
const ALERT := Color(0.961, 0.753, 0.263)
const OK := Color(0.298, 0.686, 0.490)
const PURSUIT_FILLED := Color(0.910, 0.776, 0.290)
const PURSUIT_EMPTY := Color(0.184, 0.239, 0.337)
const PURSUIT_DANGER := WOLF_RED

const SHIP_COLORS: Dictionary[String, Color] = {
	"aegis": Color(0.91, 0.93, 0.96),
	"dione": Color(0.663, 0.482, 0.851),
	"icebreaker": Color(0.788, 0.482, 0.290),
	"quellon": Color(0.306, 0.808, 0.784),
	"shepherd": Color(0.494, 0.851, 0.353),
	"refinery_124": Color(0.910, 0.776, 0.290),
}

static func ship_color(ship_id: String) -> Color:
	return SHIP_COLORS.get(ship_id, TEXT_PRIMARY)
