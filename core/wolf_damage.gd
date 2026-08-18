class_name WolfDamage
extends RefCounted

## Pure per-hull damage-ladder derivations for the Wolf Attack TV display's
## damage ladder redesign - see
## ui/design_handoff_damage_ladder/spec/wolf_attack_damage_ladder.md.
## Deliberately a thin re-derivation of wolf_ship_definitions.gd's already-
## verified constants (cross-checked against the real printed Wolf Ship
## cards earlier this project - see TODO.md), not a second hand-typed copy
## of the same six hulls' numbers. No Node/scene access, same as every
## other file in core/.
##
## A note on the Strikecarrier/Fighter-Wing bonus, resolved against
## primary sources rather than the design doc's own ambiguous wording:
## the handoff spec's §8 says "damage_if_survives takes live_fw_count
## because the Strikecarrier's contribution is 2 + live_fw_count", which
## read literally would put the bonus on the STRIKECARRIER's own number.
## That contradicts both the real printed Strikecarrier card ("If not
## destroyed: 2 damage to target, plus any Wolf Fighter Wings that have
## not been destroyed do +1 damage" - the bonus is to OTHER ships) and
## this project's own already-tested WolfAttack.compute_damage_tally(),
## which adds the bonus to each surviving Fighter Wing's own damage, never
## to the Strikecarrier's. The spec's own very next paragraph ("Get the
## double-count right") agrees with that reading and explicitly warns
## against folding it into the Strikecarrier's row. This file follows the
## verified primary sources: a Strikecarrier's own ceiling is always flat
## damage_if_survives(STRIKECARRIER) = 2, never modified by any count. A
## Fighter Wing's own ceiling rises by STRIKECARRIER_FIGHTER_BONUS for
## every Strikecarrier alive anywhere in the attack (not per-lane, matching
## compute_damage_tally()'s attack-wide scope) - the parameter is named
## live_strikecarrier_count here, not live_fw_count, because that's what
## the calculation actually needs.

## The 4-cell ladder for a hull: [long, medium, short, survives]. null in
## a range-phase slot means "cannot be destroyed in that phase" (only the
## Battlestation at Short) - render as "—", never as 0.
static func ladder(wolf_class: WolfShipDefinitions.Class) -> Array:
	var cells: Array = []
	for phase in [WolfShipDefinitions.RangePhase.LONG, WolfShipDefinitions.RangePhase.MEDIUM, WolfShipDefinitions.RangePhase.SHORT]:
		cells.append(damage_if_destroyed_now(wolf_class, phase))
	cells.append(WolfShipDefinitions.damage_if_survives(wolf_class))
	return cells

## Damage dealt if this hull is destroyed during range_phase, or null if
## it cannot be destroyed in that phase at all (§3.1's "Unavailable" cell
## state).
static func damage_if_destroyed_now(wolf_class: WolfShipDefinitions.Class, range_phase: WolfShipDefinitions.RangePhase) -> Variant:
	if WolfShipDefinitions.is_immune_at(wolf_class, range_phase):
		return null
	return WolfShipDefinitions.damage_if_destroyed_at(wolf_class, range_phase)

## Damage this hull deals if it survives to end-of-attack resolution.
## live_strikecarrier_count only affects Fighter Wings (see file header) -
## every other hull's ceiling is the flat base value regardless of it.
static func damage_if_survives(wolf_class: WolfShipDefinitions.Class, live_strikecarrier_count: int = 0) -> int:
	var base := WolfShipDefinitions.damage_if_survives(wolf_class)
	if wolf_class == WolfShipDefinitions.Class.FIGHTER_WING:
		base += live_strikecarrier_count * WolfShipDefinitions.STRIKECARRIER_FIGHTER_BONUS
	return base
