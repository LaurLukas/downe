class_name CraftState
extends RefCounted

## Per-craft mutable state. Static facts (cargo types allowed, which
## abilities it has) live on CraftDefinition instead - see
## CraftDefinitions.get_definition(id).

signal docked_ship_changed(new_ship_id: String)
signal fuelled_changed(is_fuelled: bool)
signal combat_damage_changed(new_damage: int)
signal fighter_count_changed(new_count: int)
signal scout_report_set(text: String)

var id: String
var docked_ship_id: String = ""
var fuelled: bool = false
var cargo: ResourceStock
var combat_damage: int = 0
var fighter_count: int = 0
var scout_report: String = ""

## ability_id -> times used this turn. Backs per-turn caps like mining
## operations (2, or 3 fuelled) and scout uses (usually 1). Cleared at
## end of turn alongside fuel - see clear_turn_state().
var uses_this_turn: Dictionary[String, int] = {}

func _init(craft_id: String, home_ship_id: String) -> void:
	id = craft_id
	docked_ship_id = home_ship_id
	cargo = ResourceStock.new()

func set_docked_ship(ship_id: String) -> void:
	docked_ship_id = ship_id
	docked_ship_changed.emit(ship_id)

func set_fuelled(is_fuelled: bool) -> void:
	fuelled = is_fuelled
	fuelled_changed.emit(is_fuelled)

func set_combat_damage(new_damage: int) -> void:
	combat_damage = new_damage
	combat_damage_changed.emit(new_damage)

func set_fighter_count(new_count: int) -> void:
	fighter_count = new_count
	fighter_count_changed.emit(new_count)

## Accepts whatever the scout typed, verbatim - never validated against
## real star system data. Same pattern as Ship.set_jump_coordinates.
## See CLAUDE.md constraint 1.
func set_scout_report(text: String) -> void:
	scout_report = text
	scout_report_set.emit(text)

func get_uses(ability_id: String) -> int:
	return uses_this_turn.get(ability_id, 0)

func record_use(ability_id: String) -> void:
	uses_this_turn[ability_id] = get_uses(ability_id) + 1

## Unused fuel and unused per-turn ability uses are lost at the end of
## every turn whether or not they were spent. See
## downe_shuttle_implementation_prompt.md §2 "Fuelling".
func clear_turn_state() -> void:
	set_fuelled(false)
	uses_this_turn.clear()

func to_dict() -> Dictionary:
	return {
		"id": id,
		"docked_ship_id": docked_ship_id,
		"fuelled": fuelled,
		"cargo": cargo.to_dict(),
		"combat_damage": combat_damage,
		"fighter_count": fighter_count,
		"scout_report": scout_report,
		"uses_this_turn": uses_this_turn.duplicate(),
	}
