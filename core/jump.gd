class_name JumpResolver
extends RefCounted

## Jump adjudication, run during the Coordination Phase. Coordinates are
## whatever the scout wrote down and are never checked here - see
## CLAUDE.md constraint 1. This only handles the arithmetic: drive,
## fuel, and pursuit-track consequences.

static func can_jump(ship: Ship, fuel_cost: int) -> bool:
	return ship.drive_charged \
		and ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL) >= fuel_cost \
		and not ship.jump_coordinates.is_empty()

static func resolve(ship: Ship, pursuit_track: PursuitTrack, fuel_cost: int, moves_away_from_wolves: bool) -> void:
	ship.resources.add(ResourceStock.Kind.STRYTIUM_FUEL, -fuel_cost)
	ship.set_drive_charged(false)
	if moves_away_from_wolves:
		pursuit_track.fall()
	else:
		pursuit_track.rise()
