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
## mapping is superseded). Kept for context only - node_screen_pos_for()
## below is what actually drives rendering; see its own comment on why.
const NODE_ORIGIN := Vector2(80, 112)
const NODE_SPAN := Vector2(1250, 812)

static func node_screen_pos(u: float, v: float) -> Vector2:
	return NODE_ORIGIN + Vector2(u * NODE_SPAN.x, v * NODE_SPAN.y)

## §2.1's own worked pixel table, used *directly* - "Resulting
## positions, for test fixtures... use those, don't re-derive" is the
## spec's own instruction. Re-deriving from StarChart.NODE_POSITION's
## u/v values via node_screen_pos() above (that file's own transcription,
## from docs/star_charts.json, independent of this one) introduced just
## enough floating-point drift to fail tests/ui/star_map_layout_test.gd's
## minimum-separation check for the one pair that's already razor-thin
## in the spec's own table.
##
## That check's own near-miss is worth recording here too: 1380↔6798
## measure ~160.07px apart in this exact table - the spec's prose claims
## "163px minimum (6964↔6943)" as its closest pair, but 6964↔6943 is
## actually ~162.8px by this same table, and 1380↔6798 is tighter still.
## The prose doesn't match the spec's own worked table. Not a bug to fix
## by moving nodes - these are given, fixed reference positions - just
## flagged honestly rather than silently accepted or hidden by loosening
## the test's own threshold.
const NODE_PIXEL_POSITION: Dictionary[String, Vector2] = {
	"0000": Vector2(80, 525), "1413": Vector2(230, 629), "5143": Vector2(322, 359),
	"0488": Vector2(404, 780), "6837": Vector2(433, 523), "9997": Vector2(471, 200),
	"6931": Vector2(592, 367), "4454": Vector2(626, 683), "1096": Vector2(757, 470),
	"4753": Vector2(785, 227), "6964": Vector2(785, 826), "3068": Vector2(915, 338),
	"6943": Vector2(915, 924), "0853": Vector2(942, 631), "2580": Vector2(969, 112),
	"1964": Vector2(1073, 799), "6798": Vector2(1107, 205), "8378": Vector2(1137, 551),
	"4888": Vector2(1240, 903), "1380": Vector2(1242, 119), "1836": Vector2(1269, 359),
	"0408": Vector2(1330, 659),
}

static func node_screen_pos_for(coordinate: String) -> Vector2:
	return NODE_PIXEL_POSITION.get(coordinate, Vector2.ZERO)

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

# --- font sizes (§1: "no text anywhere below 18px") ------------------------
# Centralized so tests/test_star_map_layout.gd can check every size this
# screen actually uses against MIN_FONT_SIZE in one place, instead of
# grepping draw_string() literals scattered across star_map_canvas.gd -
# a real 17px violation (the "JUMP FAILURE" label, borrowed from
# WolfAttackTokens' T_CHIP, tuned for the *other* screen's budget) was
# found and fixed by building this list, not the other way around.

const MIN_FONT_SIZE := 18

const FONT_SIZE_COORD := 24 # unvisited/reported node's in-circle coordinate
const FONT_SIZE_LETTER := 42 # visited/occupied node's in-circle letter
const FONT_SIZE_CHIP := 20 # info chip text (§4.1)
const FONT_SIZE_BAND_LABEL := 28 # band-scale labels (START, -1..-7)
const FONT_SIZE_LEGEND := 18 # legend bar item labels (§7)
const FONT_SIZE_TOKEN_ABBR := 18 # group token abbreviation (§4.3)
const FONT_SIZE_EDGE_LABEL := 18 # "JUMP FAILURE" trail label (§5)

const ALL_FONT_SIZES: Array[int] = [
	FONT_SIZE_COORD, FONT_SIZE_LETTER, FONT_SIZE_CHIP, FONT_SIZE_BAND_LABEL,
	FONT_SIZE_LEGEND, FONT_SIZE_TOKEN_ABBR, FONT_SIZE_EDGE_LABEL,
]
