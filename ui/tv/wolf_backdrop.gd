class_name WolfBackdrop
extends Control

## Near-black gradient + crimson top-corner bloom behind the Wolf Attack
## STANDING layout - wolf_attack_tv_display_v2_gap_spec.md §4.1 (P0-03).
## Static per attack (doesn't redraw on GameState.mutated), so this is
## built once in _ready(), not every refresh.
##
## The spec asks for pre-baked PNGs composited with additive blending,
## since the Compatibility renderer has no reliable WorldEnvironment glow
## (§7). This project has no image editor in its toolchain to bake PNGs
## with, so the gradient and bloom are built as GradientTexture2D
## resources instead - Godot's own procedural equivalent of a baked
## raster gradient, computed once and cached like any other texture, with
## the "soft blur" approximated by wide multi-stop color ramps rather
## than a blurred bitmap. Same result the spec is after (near-black base,
## crimson glow falling off from the top corners) without needing an
## external asset pipeline.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_base_gradient()
	_add_bloom(Vector2(0.0, 0.0), Vector2(1.0, 0.0))
	_add_bloom(Vector2(1.0, 0.0), Vector2(0.0, 0.0))
	_add_top_edge_bloom()

func _add_base_gradient() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, WolfAttackTokens.BG_MID)
	gradient.set_color(1, WolfAttackTokens.BG_DEEP)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = WolfAttackTokens.DESIGN_HEIGHT
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	add_child(rect)

## A soft radial glow anchored at one top corner, additive-blended so it
## brightens rather than replaces the base gradient underneath it.
func _add_bloom(anchor: Vector2, opposite_corner_uv: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(WolfAttackTokens.BLOOM_CRIMSON, 0.55))
	gradient.add_point(0.55, Color(WolfAttackTokens.BLOOM_CRIMSON, 0.18))
	gradient.set_color(1, Color(WolfAttackTokens.BLOOM_CRIMSON, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = opposite_corner_uv
	texture.fill_to = Vector2(0.5, 0.5)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(950.0, 750.0)
	rect.position = Vector2(anchor.x * WolfAttackTokens.DESIGN_WIDTH, 0.0) - Vector2(rect.size.x * anchor.x, 0.0)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rect.material = material
	add_child(rect)

func _add_top_edge_bloom() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(WolfAttackTokens.BLOOM_EDGE, 0.22))
	gradient.set_color(1, Color(WolfAttackTokens.BLOOM_EDGE, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = WolfAttackTokens.DESIGN_WIDTH
	texture.height = 4
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(WolfAttackTokens.DESIGN_WIDTH, 140.0)
	rect.position = Vector2.ZERO
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rect.material = material
	add_child(rect)
