class_name GameState
extends RefCounted

## Root of the rules engine. Holds everything the host's persistence
## layer (net/) dumps to user:// on every mutation - see CLAUDE.md's
## Persistence section. This class stays pure data + rules; it never
## touches FileAccess, Node, or the scene tree.

signal mutated()

var ships: Dictionary[String, Ship] = {}
var craft: Dictionary[String, CraftState] = {}
var star_systems: Dictionary[String, StarSystem] = {}
var pursuit_track := PursuitTrack.new()
var turn_manager := TurnManager.new()

## Abilities and other rules that need randomness must roll against
## this, never call randi()/randf() directly, so a game is reproducible
## from its JSON dump (downe_shuttle_implementation_prompt.md §1). The
## seed is persisted; the stream's current position is not - reloading
## a save resumes with a fresh stream from the same seed, not the exact
## roll sequence in progress.
var rng := RandomNumberGenerator.new()

func _init() -> void:
	turn_manager.phase_changed.connect(_on_phase_changed)

func add_ship(ship: Ship) -> void:
	ships[ship.id] = ship
	mutated.emit()

func get_ship(ship_id: String) -> Ship:
	return ships.get(ship_id)

func add_craft(craft_state: CraftState) -> void:
	craft[craft_state.id] = craft_state
	mutated.emit()

func get_craft(craft_id: String) -> CraftState:
	return craft.get(craft_id)

func add_star_system(system: StarSystem) -> void:
	star_systems[system.id] = system
	mutated.emit()

func get_star_system(system_id: String) -> StarSystem:
	return star_systems.get(system_id)

## Unused console charge and unused craft fuel/per-turn ability uses are
## lost at the end of every turn, whether or not they were spent - see
## downe_shuttle_implementation_prompt.md §2 "Fuelling" and
## open_questions_answered.md §5.3. The boundary is "a new Team Phase
## started", since Team Phase is always turn N+1's first phase.
func _on_phase_changed(_turn: int, phase: TurnManager.Phase) -> void:
	if phase != TurnManager.Phase.TEAM:
		return
	for ship_id: String in ships:
		var ship: Ship = ships[ship_id]
		for console_id: String in ship.consoles:
			ship.consoles[console_id].set_charged(false)
	for craft_id: String in craft:
		craft[craft_id].clear_turn_state()

func to_dict() -> Dictionary:
	var ship_dict := {}
	for ship_id: String in ships:
		ship_dict[ship_id] = ships[ship_id].to_dict()
	var craft_dict := {}
	for craft_id: String in craft:
		craft_dict[craft_id] = craft[craft_id].to_dict()
	return {
		"pursuit_track": pursuit_track.to_dict(),
		"turn": turn_manager.to_dict(),
		"rng_seed": rng.seed,
		"ships": ship_dict,
		"craft": craft_dict,
	}
