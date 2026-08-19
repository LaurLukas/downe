class_name ShipColors
extends RefCounted

## Canonical capital-ship signature colours - docs/ship_colors.md,
## extracted from wolf_attack_tv_visual_redesign.md §5.1 for use across
## the whole project (TV display, ESP32 terminals, phone pages, printed
## material). Pure colour lookup, no Node dependency, safe in core/ per
## that doc's own note.
##
## ui/tv/wolf_attack_tokens.gd currently keeps its own copy of these
## same six values rather than referencing this file - see TODO.md's
## "Signature colors" entries for why (it predates this file). Treat
## this as the source of truth for any new code; reconciling the
## existing duplicate is a separate, not-yet-done cleanup.

const SIGNATURE: Dictionary = {
	&"aegis": Color("CFE4F5"),
	&"dione": Color("A97BFF"),
	&"icebreaker": Color("E8873C"),
	&"quellon": Color("46D6C0"),
	&"shepherd": Color("7FD46A"),
	&"refinery_124": Color("F2D04A"),
}

const FLEET_DIM: Color = Color("3C5F70")

static func for_ship(id: StringName, crippled: bool = false, destroyed: bool = false) -> Color:
	if destroyed:
		return FLEET_DIM
	var c: Color = SIGNATURE.get(id, Color("7FD8F0"))
	if crippled:
		c.s *= 0.30
		c.v = 0.40
	return c
