class_name GameState
extends RefCounted

## Root of the rules engine. Holds everything the host's persistence
## layer (net/) dumps to user:// on every mutation - see CLAUDE.md's
## Persistence section. This class stays pure data + rules; it never
## touches FileAccess, Node, or the scene tree.

signal mutated()

var ships: Dictionary[String, Ship] = {}
var star_systems: Dictionary[String, StarSystem] = {}
var pursuit_track := PursuitTrack.new()
var turn_manager := TurnManager.new()

func add_ship(ship: Ship) -> void:
	ships[ship.id] = ship
	mutated.emit()

func get_ship(ship_id: String) -> Ship:
	return ships.get(ship_id)

func add_star_system(system: StarSystem) -> void:
	star_systems[system.id] = system
	mutated.emit()

func get_star_system(system_id: String) -> StarSystem:
	return star_systems.get(system_id)

func to_dict() -> Dictionary:
	var ship_dict := {}
	for ship_id: String in ships:
		ship_dict[ship_id] = ships[ship_id].to_dict()
	return {
		"pursuit_track": pursuit_track.to_dict(),
		"turn": turn_manager.to_dict(),
		"ships": ship_dict,
	}
