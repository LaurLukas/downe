class_name Ship
extends RefCounted

signal jump_coordinates_set(text: String)
signal drive_charge_changed(charged: bool)
signal unrest_changed(new_unrest: int)

var id: String
var resources: ResourceStock
var consoles: Dictionary[String, Console] = {}
var can_scout: bool = false
var drive_charged: bool = false
var jump_coordinates: String = ""

## Raised by low maintenance rolls, lowered by... none of that is
## modeled yet. This is just the counter - see TODO.md.
var unrest: int = 0

## The evacuation ceiling: no ship may exceed its starting population.
## Crew/passenger capacity numbers on the printed ship sheets are flavor
## only and are deliberately not enforced here (resources.md).
var survivor_population: int = 0
var max_survivor_population: int = 0

func _init(ship_id: String, scout_capable: bool = false) -> void:
	id = ship_id
	can_scout = scout_capable
	resources = ResourceStock.new()

func add_console(console_id: String) -> Console:
	var console := Console.new(console_id)
	consoles[console_id] = console
	return console

func get_console(console_id: String) -> Console:
	return consoles.get(console_id)

## Accepts whatever the scout typed, verbatim. Never validate this against
## real star system data, auto-fill it, or flag it as wrong - a lying
## scout is the game, not a bug. See CLAUDE.md constraint 1.
func set_jump_coordinates(text: String) -> void:
	jump_coordinates = text
	jump_coordinates_set.emit(text)

func set_drive_charged(charged: bool) -> void:
	drive_charged = charged
	drive_charge_changed.emit(charged)

func set_unrest(new_unrest: int) -> void:
	unrest = new_unrest
	unrest_changed.emit(new_unrest)

func to_dict() -> Dictionary:
	var console_dict := {}
	for console_id: String in consoles:
		console_dict[console_id] = consoles[console_id].to_dict()
	return {
		"id": id,
		"can_scout": can_scout,
		"drive_charged": drive_charged,
		"jump_coordinates": jump_coordinates,
		"unrest": unrest,
		"survivor_population": survivor_population,
		"max_survivor_population": max_survivor_population,
		"resources": resources.to_dict(),
		"consoles": console_dict,
	}
