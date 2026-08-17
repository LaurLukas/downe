class_name Ship
extends RefCounted

signal jump_coordinates_set(text: String)
signal drive_charge_changed(charged: bool)
signal unrest_changed(new_unrest: int)
signal maintenance_step_completed(step: int)

## Fires on any change to this ship or anything docked in it - resources,
## consoles, jump coordinates, drive charge, unrest. GameState listens to
## this per-ship so it knows when to emit its own mutated signal, rather
## than every caller having to remember to notify GameState directly.
signal changed()

var id: String
var resources: ResourceStock
var consoles: Dictionary[String, Console] = {}
var can_scout: bool = false
var drive_charged: bool = false
var jump_coordinates: String = ""

## Raised by MaintenanceCycle.roll_unrest_gain(). Nothing in the source
## documents describes a way to lower it, other than the mutiny
## threshold (8+) itself being a facilitator-adjudicated event, not an
## automatic reset - see resources.md.
var unrest: int = 0

## Which of this Team Phase's Maintenance Cycle steps (MaintenanceCycle.
## Step) this ship's table has already run. Cleared every new Team
## Phase (GameState._on_phase_changed()) - it's a per-turn checklist,
## not a permanent record.
var completed_maintenance_steps: Array[int] = []

## The evacuation ceiling: no ship may exceed its starting population.
## Crew/passenger capacity numbers on the printed ship sheets are flavor
## only and are deliberately not enforced here (resources.md).
var survivor_population: int = 0
var max_survivor_population: int = 0

func _init(ship_id: String, scout_capable: bool = false) -> void:
	id = ship_id
	can_scout = scout_capable
	resources = ResourceStock.new()
	resources.amount_changed.connect(func(_kind: ResourceStock.Kind, _amount: int) -> void: changed.emit())
	jump_coordinates_set.connect(func(_text: String) -> void: changed.emit())
	drive_charge_changed.connect(func(_charged: bool) -> void: changed.emit())
	unrest_changed.connect(func(_new_unrest: int) -> void: changed.emit())
	maintenance_step_completed.connect(func(_step: int) -> void: changed.emit())

func add_console(console_id: String) -> Console:
	var console := Console.new(console_id)
	consoles[console_id] = console
	console.state_changed.connect(func(_new_state: Console.State) -> void: changed.emit())
	console.upgrade_changed.connect(func(_new_level: int) -> void: changed.emit())
	console.charged_changed.connect(func(_is_charged: bool) -> void: changed.emit())
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

func is_maintenance_step_complete(step: int) -> bool:
	return step in completed_maintenance_steps

func mark_maintenance_step_complete(step: int) -> void:
	if step in completed_maintenance_steps:
		return
	completed_maintenance_steps.append(step)
	maintenance_step_completed.emit(step)

## Bulk reset for a new Team Phase - deliberately silent (no signal per
## step), since GameState._on_phase_changed() already triggers its own
## mutated emission for the whole sweep it's part of.
func clear_maintenance_steps() -> void:
	completed_maintenance_steps.clear()

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
		"completed_maintenance_steps": completed_maintenance_steps.duplicate(),
	}

## Rebuilds a Ship from a to_dict()-shaped dict (Persistence's saved
## state). Loads resources/consoles onto the objects add_console() and
## _init() already created and wired for changed-bubbling, rather than
## replacing them wholesale - a fresh ResourceStock or Console here
## would be unwired from Ship.changed, and mutating a rehydrated ship
## post-load would silently stop reaching GameState.mutated. See
## GameState.from_dict().
static func from_dict(data: Dictionary) -> Ship:
	var ship := Ship.new(data.get("id", ""), bool(data.get("can_scout", false)))
	ship.drive_charged = bool(data.get("drive_charged", false))
	ship.jump_coordinates = String(data.get("jump_coordinates", ""))
	ship.unrest = int(data.get("unrest", 0))
	ship.survivor_population = int(data.get("survivor_population", 0))
	ship.max_survivor_population = int(data.get("max_survivor_population", 0))
	ship.resources.load_from_dict(data.get("resources", {}))
	var console_dict: Dictionary = data.get("consoles", {})
	for console_id: String in console_dict:
		ship.add_console(console_id).load_from_dict(console_dict[console_id])
	for step: Variant in data.get("completed_maintenance_steps", []):
		ship.completed_maintenance_steps.append(int(step))
	return ship
