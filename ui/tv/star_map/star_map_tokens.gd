class_name StarMapTokens
extends RefCounted

## Design tokens for the Star Map TV screen -
## ui/design_handoff_star_map/star_map_tv_visual_implementation.md §2/§3.
## Single source for colour/geometry so star_map_canvas.gd and
## star_map_screen.gd never hardcode a colour or pixel value - same
## "one table, not per-scene literals" rule wolf_attack_tokens.gd
## already follows for the other TV screen.
##
## Background is a flat fill, not the spec's radial-gradient-plus-
## nebula-washes recipe - same call already made for the Wolf Attack
## screen ("do the whole background in a single dark colour" -
## wolf_attack_display.gd's own history) after a gradient attempt turned
## out to be unnecessary complexity for a first pass. Revisit together
## if either screen ever gets a dedicated visual-polish pass.

# --- canvas geometry (§2) --------------------------------------------------

const CANVAS_SIZE := Vector2(1920, 1080)
const Y_TITLE_BOTTOM := 68.0
const Y_MAP_TOP := 74.0
const Y_MAP_BOTTOM := 955.0
const Y_BAND_SCALE_TOP := 962.0
const Y_BAND_SCALE_BOTTOM := 996.0
const Y_LEGEND_TOP := 1020.0
const Y_LEGEND_BOTTOM := 1068.0
const X_MAP_LEFT := 30.0
const X_MAP_RIGHT := 1380.0
const X_RAIL_LEFT := 1400.0
const X_RAIL_RIGHT := 1890.0

## §2.1: paper rotated 90° CW, u->x, v->y - NOT a uniform scale (see
## that section's own note on why the earlier 1.153/1.152 uniform
## mapping is superseded).
const NODE_ORIGIN := Vector2(80, 112)
const NODE_SPAN := Vector2(1250, 812)

static func node_screen_pos(u: float, v: float) -> Vector2:
	return NODE_ORIGIN + Vector2(u * NODE_SPAN.x, v * NODE_SPAN.y)

# --- node sizes (§4) --------------------------------------------------------

const NODE_RADIUS_SMALL := 38.0 # unknown/reported (76px diameter)
const NODE_RADIUS_LARGE := 42.0 # visited/occupied (84px diameter)

## §2.2's exact per-tier band fill table - START and -6 read brighter,
## the rest are uniform. Not a simple alternating rule (the source
## table is genuinely uneven), so a lookup rather than an i%2 check.
const BAND_ALPHA: Dictionary[int, float] = {
	0: 0.055, 1: 0.022, 2: 0.022, 3: 0.022, 4: 0.022, 5: 0.022, 6: 0.055, 7: 0.022,
}

# --- colour table (§3) - enforce as a single table, not per-scene literals -

const FLEET := Color("#7FD8F0") # the AEGIS group
const FLEET_ALT := Color("#C9D8E8") # a non-AEGIS group
const WOLF := Color("#FF3B2E") # confirmed wolf system (L, M)
const CLAIM := Color("#FFC53D") # unverified scout claim - always paired with a dashed stroke
const HAZARD := Color("#A78BFA") # I, J, K
const KNOWN := Color("#A5B4C6") # visited, no consequence (D, E, F, H)
const POOR := Color("#8FA1B8") # A, B, C
const EDEN := Color("#EDE4D6") # N, O, P, and 0000
const UNKNOWN := Color(140.0 / 255.0, 158.0 / 255.0, 182.0 / 255.0, 0.32) # never-visited ring

const TEXT_PRIMARY := Color("#DCE6F2")
const TEXT_SECONDARY := Color("#A9B8CC")
const TEXT_LABEL := Color("#8A9AB0")

const BG := Color("#070A13")

## node "class" (StarMapProjection's derived value) -> colour. Folds
## "neutral" into KNOWN per §3's own class list (D is neutral and reads
## as KNOWN - "visited, no consequence").
static func class_tint(node_class: String) -> Color:
	match node_class:
		"wolf":
			return WOLF
		"hazard":
			return HAZARD
		"poor":
			return POOR
		"start", "new_eden":
			return EDEN
		_:
			return KNOWN

## Group representative colour -> FLEET (AEGIS) or FLEET_ALT (anyone
## else) - §3's "one colour, one meaning" rule means every non-AEGIS
## group reads as the same pale steel, not a rainbow of ship-identity
## hues fighting the wolf/claim/hazard palette for attention.
static func group_colour(is_aegis: bool) -> Color:
	return FLEET if is_aegis else FLEET_ALT
