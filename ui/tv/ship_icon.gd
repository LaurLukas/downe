class_name ShipIcon
extends Control

## Renders one of the hand-authored ship silhouettes under
## res://ui/design_handoff_wolf_attack_lanes/svg/ - six Wolf hull classes
## (wolf_attack_tv_display_v2_gap_spec.md §4.5 step 7 / P1-14) and six
## fleet ship silhouettes (§4.8's P1-10), replacing this file's earlier
## _draw()-based vector art now that real artwork exists. That folder is
## the v3 lane-redesign handoff bundle (see TODO.md) - its SVGs are the
## one production copy, not reference material, per the user's explicit
## instruction; there is no res://svg/ anymore. Fit "contain" (aspect
## preserved, centered) within whatever size the caller gives this
## Control, same as the old custom draw calls did.
##
## icon_color multiplies the SVG's own baked colors (Godot's normal
## texture modulate) rather than replacing them - the fleet ship SVGs
## already bake in a color close to WolfAttackTokens.SHIP_COLOR per ship,
## and the wolf hull SVGs bake in a near-white stroke close to
## WolfAttackTokens.INK, so passing those same tokens through as
## icon_color is close to a no-op most of the time and exists mainly for
## the "destroyed" dim state (INK_GHOST, which is dark, muting the icon
## when multiplied in).

const _TEXTURES: Dictionary[String, Texture2D] = {
	"battlestation": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-battlestation.svg"),
	"strikecarrier": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-strikecarrier.svg"),
	"cruiser": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-cruiser.svg"),
	"assault_transport": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-assault-transport.svg"),
	"destroyer": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-destroyer.svg"),
	"fighter_wing": preload("res://ui/design_handoff_wolf_attack_lanes/svg/wolf-fighter-wing.svg"),
	"aegis": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-aegis.svg"),
	"dione": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-dione.svg"),
	"icebreaker": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-icebreaker.svg"),
	"quellon": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-quellon.svg"),
	"shepherd": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-shepherd.svg"),
	"refinery_124": preload("res://ui/design_handoff_wolf_attack_lanes/svg/capital-refinery-124.svg"),
}

@export var icon_id: String = "":
	set(value):
		icon_id = value
		queue_redraw()
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()

func _draw() -> void:
	var texture: Texture2D = _TEXTURES.get(icon_id)
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := minf(size.x / texture_size.x, size.y / texture_size.y)
	var fitted := texture_size * scale
	var origin := (size - fitted) * 0.5
	draw_texture_rect(texture, Rect2(origin, fitted), false, icon_color)
