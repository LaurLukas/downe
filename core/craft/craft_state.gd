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

## Fires on any change to this craft, including its cargo. GameState
## listens to this per-craft the same way it listens to Ship.changed -
## see that signal's comment.
signal changed()

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
	cargo.amount_changed.connect(func(_kind: ResourceStock.Kind, _amount: int) -> void: changed.emit())
	docked_ship_changed.connect(func(_new_ship_id: String) -> void: changed.emit())
	fuelled_changed.connect(func(_is_fuelled: bool) -> void: changed.emit())
	combat_damage_changed.connect(func(_new_damage: int) -> void: changed.emit())
	fighter_count_changed.connect(func(_new_count: int) -> void: changed.emit())
	scout_report_set.connect(func(_text: String) -> void: changed.emit())

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

## Rebuilds a CraftState from a to_dict()-shaped dict. Loads cargo onto
## the ResourceStock _init() already wired for changed-bubbling rather
## than replacing it - see Ship.from_dict()'s comment for why.
static func from_dict(data: Dictionary) -> CraftState:
	var craft_state := CraftState.new(data.get("id", ""), String(data.get("docked_ship_id", "")))
	craft_state.fuelled = bool(data.get("fuelled", false))
	craft_state.cargo.load_from_dict(data.get("cargo", {}))
	craft_state.combat_damage = int(data.get("combat_damage", 0))
	craft_state.fighter_count = int(data.get("fighter_count", 0))
	craft_state.scout_report = String(data.get("scout_report", ""))
	var uses: Dictionary = data.get("uses_this_turn", {})
	for ability_id: String in uses:
		craft_state.uses_this_turn[ability_id] = int(uses[ability_id])
	return craft_state
