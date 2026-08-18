class_name WolfAttackTokens
extends RefCounted

## Design tokens for the Wolf Attack TV screen, per
## wolf_attack_tv_display_v2_gap_spec.md §2. Single source for colors,
## fonts and layout coordinates so wolf_attack_display.gd and its helper
## scripts never hardcode a color or font size - matches the spec's "No
## hardcoded colours or font sizes anywhere in the scene scripts" rule.
##
## Ship-identity colors live here, not in core/ShipRegistry, despite the
## spec's §2.2 suggestion to fold them into "the same lookup table as
## display names". That table is core/ship_registry.gd, and the same
## spec's own §7 says "core/ stays clean. No Color, no font, no pixel
## value in the rules engine" - CLAUDE.md's architecture rule (core/ never
## references presentation) settles the contradiction in favor of §7. This
## file is the ui/-layer equivalent: still one table, keyed the same way,
## just not core/'s table.

# --- canvas (§2.1) -------------------------------------------------------

const DESIGN_WIDTH := 1920
const DESIGN_HEIGHT := 1080
const SAFE_MARGIN_X := 95.0
const SAFE_MARGIN_TOP := 60.0
const SAFE_MARGIN_BOTTOM := 55.0
const CONTENT_RIGHT := float(DESIGN_WIDTH) - SAFE_MARGIN_X  # 1825

# --- palette (§2.2) -------------------------------------------------------

const BG_DEEP := Color("#07090F")
const BG_MID := Color("#12101E")
const BLOOM_CRIMSON := Color("#4A0E18")
const BLOOM_EDGE := Color("#6B1220")

const INK := Color("#F2EADB")
const INK_DIM := Color("#8A8578")
const INK_GHOST := Color("#3B4252")

const CYAN := Color("#38E1E8")
const CYAN_DIM := Color("#1E6E78")
const ALERT := Color("#FF3B30")
const ALERT_DEEP := Color("#8E1A15")
const AMBER := Color("#F7B733")

const PURSUIT_EMPTY_FILL := Color("#1B2540")
const PURSUIT_EMPTY_BORDER := Color("#2E3C60")
const PURSUIT_DOOM := Color("#6E1616")

const CARD_BG := Color("#0E1424")
const CARD_BG_TARGETED := Color("#1A0E14")
const RULE := Color("#24303F")

## Canonical values, not this file's own invention - see docs/ship_colors.md
## for the full rationale (each hue tied to what the ship supplies,
## "colour is identity never status", "no ship gets red").
const SHIP_COLOR: Dictionary[String, Color] = {
	"aegis": Color("#CFE4F5"),
	"dione": Color("#A97BFF"),
	"icebreaker": Color("#E8873C"),
	"quellon": Color("#46D6C0"),
	"shepherd": Color("#7FD46A"),
	"refinery_124": Color("#F2D04A"),
}

static func ship_color(ship_id: String) -> Color:
	return SHIP_COLOR.get(ship_id, INK)

## All display strings are uppercased at render time, never in the data
## model (spec §2.3) - the one place that happens.
static func fmt_display(s: String) -> String:
	return s.to_upper()

# --- fonts (§2.3) ----------------------------------------------------------
# Chakra Petch (DISPLAY) + JetBrains Mono (DATA), both OFL, bundled under
# res://assets/fonts/ - no CDN, no runtime download, per CLAUDE.md's "no
# assumption of internet access" rule. JetBrains Mono ships as a single
# variable font; DATA_BOLD/DATA_REGULAR select the wght axis instead of
# needing two separate files.

const _DISPLAY_BOLD: Font = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const _DISPLAY_REGULAR: Font = preload("res://assets/fonts/ChakraPetch-Regular.ttf")
const _DATA_VARIABLE: Font = preload("res://assets/fonts/JetBrainsMono[wght].ttf")

## §2.3 groups tokens into two font "roles" by what they label (title/
## phase-rail/wolf-codes/card-numbers-and-names vs. stat-lines/chips/SEC/
## wraps/footer) rather than giving every token an explicit family column.
## T_PURSUIT_NUM and T_DMG_NUM are the one deliberate exception: §7 calls
## for tabular figures specifically on those two ("the pursuit counter and
## damage numbers do not jitter"), which only the DATA font declares, so
## they're DATA despite reading as "numbers on the title role" tokens.
enum Family { DISPLAY, DATA }

const TYPE_SCALE: Dictionary[String, Dictionary] = {
	"T_TITLE": {"family": Family.DISPLAY, "size": 64, "bold": true, "spacing": 6.0},
	"T_TURN": {"family": Family.DISPLAY, "size": 40, "bold": true, "spacing": 5.0},
	"T_STAT": {"family": Family.DATA, "size": 22, "bold": false, "spacing": 3.0},
	"T_PURSUIT_NUM": {"family": Family.DATA, "size": 26, "bold": true, "spacing": 2.0},
	"T_PHASE": {"family": Family.DISPLAY, "size": 24, "bold": false, "spacing": 4.0},
	"T_PHASE_ACTIVE": {"family": Family.DISPLAY, "size": 30, "bold": true, "spacing": 4.0},
	"T_WOLF_CODE": {"family": Family.DISPLAY, "size": 34, "bold": true, "spacing": 3.0},
	"T_WOLF_ABILITY": {"family": Family.DISPLAY, "size": 19, "bold": true, "spacing": 2.0},
	"T_WOLF_TARGET": {"family": Family.DATA, "size": 17, "bold": false, "spacing": 2.0},
	"T_BAND_GUTTER": {"family": Family.DISPLAY, "size": 28, "bold": false, "spacing": 6.0},
	"T_BAND_ACTIVE": {"family": Family.DISPLAY, "size": 26, "bold": true, "spacing": 5.0},
	"T_CARD_INDEX": {"family": Family.DISPLAY, "size": 62, "bold": true, "spacing": 0.0},
	"T_CARD_NAME": {"family": Family.DISPLAY, "size": 27, "bold": true, "spacing": 2.0},
	"T_SEC": {"family": Family.DATA, "size": 18, "bold": false, "spacing": 2.0},
	"T_DMG_NUM": {"family": Family.DATA, "size": 38, "bold": true, "spacing": 0.0},
	"T_DMG_SUFFIX": {"family": Family.DATA, "size": 18, "bold": false, "spacing": 2.0},
	"T_CHIP": {"family": Family.DATA, "size": 17, "bold": false, "spacing": 1.0},
	"T_WRAPS": {"family": Family.DATA, "size": 19, "bold": false, "spacing": 5.0},
	"T_FOOTER_LABEL": {"family": Family.DATA, "size": 16, "bold": false, "spacing": 4.0},
	"T_FOOTER_ITEM": {"family": Family.DATA, "size": 22, "bold": true, "spacing": 2.0},
	"T_FOOTER_VALUE": {"family": Family.DATA, "size": 20, "bold": false, "spacing": 2.0},
	# v3 lane layout additions (§8/§10.1 header zone).
	"T_TALLY": {"family": Family.DATA, "size": 24, "bold": true, "spacing": 1.0},
	"T_RANGE_LABEL": {"family": Family.DISPLAY, "size": 22, "bold": true, "spacing": 4.0},
	"T_INCOMING_NUM": {"family": Family.DATA, "size": 26, "bold": true, "spacing": 0.0},
	"T_COMPACT_CODE": {"family": Family.DATA, "size": 19, "bold": true, "spacing": 1.0},
	"T_COMPACT_ABILITY": {"family": Family.DATA, "size": 17, "bold": true, "spacing": 1.0},
}

static func _variation(family: Family, bold: bool, spacing: float) -> FontVariation:
	var fv := FontVariation.new()
	if family == Family.DISPLAY:
		fv.base_font = _DISPLAY_BOLD if bold else _DISPLAY_REGULAR
	else:
		fv.base_font = _DATA_VARIABLE
		fv.variation_opentype = {"wght": 700.0 if bold else 400.0}
	fv.spacing_glyph = spacing
	return fv

## Applies a §2.3 type-scale token to any Control with theme font/font-size
## overrides (Label, RichTextLabel, Button…) - font family, weight and
## tracking come from the token; color is deliberately left to the caller,
## since the same token is reused with different colors (e.g. T_CHIP is
## ALERT for ship-type tags but INK for the filled BP chip).
static func apply(control: Control, token: String) -> void:
	var scale: Dictionary = TYPE_SCALE[token]
	control.add_theme_font_override("font", _variation(scale["family"], scale["bold"], scale["spacing"]))
	control.add_theme_font_size_override("font_size", scale["size"])

static func font_size(token: String) -> int:
	return TYPE_SCALE[token]["size"]

## For custom _draw() callers (pursuit meter, range bands, attack vectors)
## that need a Font object directly rather than a Control to style.
static func font(token: String) -> Font:
	var scale: Dictionary = TYPE_SCALE[token]
	return _variation(scale["family"], scale["bold"], scale["spacing"])

# --- vertical rhythm (§2.4) -----------------------------------------------
# y-coordinates in the fixed 1920×1080 design space, not screen pixels -
# see WolfAttackDisplay's content_scale setup in ui/main.gd.

const Y_TITLE_BASELINE := 112.0
const Y_STAT_LINE := 155.0
const Y_HEADER_RULE := 190.0
const Y_PHASE_RAIL := 217.0

# v3 lane layout (wolf_attack_tv_display_v3_lanes.md §2) - the zones below
# replace v2's Y_WOLF_SILHOUETTE_*/Y_WOLF_CODE_PIPS/Y_WOLF_ABILITY/
# Y_WOLF_TARGET/Y_BAND_ARC_*/Y_VECTOR_ORIGIN/Y_SEC_LABEL/Y_FLEET_CARD_TOP/
# FLEET_CARD_HEIGHT (single wolf row + bezier vectors + gutter bands, all
# deleted per §7). "Default" values are the normal case; at max_stack <= 2
# WolfLaneLayout.stack_zone_geometry() returns the roomy-case override for
# Y_IMPACT_DEFAULT/Y_CARD_TOP_DEFAULT/CARD_HEIGHT_DEFAULT instead - callers
# read that dict, not these constants directly, once a snapshot is in hand.
const Y_WOLF_TALLY := 248.0
const Y_STACK_ZONE_TOP := 280.0
const Y_IMPACT_DEFAULT := 626.0
## README's explicit formula ("impactY + 8", a 26px-tall row) is used here
## rather than the .md spec's single table value of 652 for this zone -
## 626 + 8 = 634, not 652, and the two documents don't reconcile on this
## one number. Trusting the stated formula over an unexplained table
## number matches how this project already resolved v3's lane_width
## table/formula mismatch (TODO.md) - not guessed, the formula is the
## more explicit of the two sources.
const Y_INCOMING_LINE_OFFSET := 8.0
const Y_CARD_TOP_DEFAULT := 666.0
const CARD_HEIGHT_DEFAULT := 240.0
const Y_WRAPS_LINE := 944.0
const Y_CANNOT_LABEL := 982.0
const Y_UNTARGETABLE_ROW := 1018.0
