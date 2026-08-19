class_name JumpResolver
extends RefCounted

## Jump adjudication, run during the Coordination Phase. Coordinates are
## whatever the scout wrote down and are never checked here - see
## CLAUDE.md constraint 1. This only handles the arithmetic: drive,
## fuel, and pursuit-track consequences.
##
## pursuit_delta is a signed amount supplied by the caller (negative
## falls, positive rises) - it is never derived here from
## ship.jump_coordinates. Looking that text up against StarChart to
## compute a magnitude would mean this engine validating a scout's
## typed coordinates against reality, exactly what constraint 1
## forbids. The host adjudicates where a ship actually went and looks
## up the right magnitude themselves, e.g. via
## StarChart.pursuit_reduction_at() for a real destination, before
## calling this - confirmed as the cumulative per-tier reading (-1
## through -7 by tier depth, not a flat -1 per jump).

static func can_jump(ship: Ship, fuel_cost: int) -> bool:
	return ship.drive_charged \
		and ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL) >= fuel_cost \
		and not ship.jump_coordinates.is_empty()

static func resolve(ship: Ship, pursuit_track: PursuitTrack, fuel_cost: int, pursuit_delta: int) -> void:
	ship.resources.add(ResourceStock.Kind.STRYTIUM_FUEL, -fuel_cost)
	ship.set_drive_charged(false)
	pursuit_track.set_value(pursuit_track.value + pursuit_delta)
