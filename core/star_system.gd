class_name StarSystem
extends RefCounted

## Per-game mutable state for one star system: which opportunities have
## been completed, whether an L/M Wolf base has been destroyed yet,
## K's secretly-rolled difficulty. Static content (name, opportunities,
## standing effects) lives on StarSystemDefinition instead - mirrors
## Ship/ShipRegistry and CraftState/CraftDefinitions' split.

signal opportunity_completed(index: int)
signal wolf_base_destroyed_changed(destroyed: bool)
signal hidden_difficulty_rolled()
signal changed()

var letter: String

## Indices into definition().opportunities that have already been run
## this game. Doesn't apply to J/K's opportunity, which is
## repeatable_each_turn - check that on the definition before
## consulting this.
var completed_opportunity_indices: Array[int] = []

## L, M only: the away mission there is blocked while the Wolf base is
## still operational (open_questions_answered.md §1.2). Stays false and
## unused for every other system.
var wolf_base_destroyed: bool = false

## K only: the secretly-rolled difficulty (1d6 = X; difficulty 5X,
## critical 5X+10), generated once via roll_hidden_difficulty() and
## never disclosed to players - "Your UI must be able to show an
## unknown difficulty without leaking the rolled value." -1 means "not
## yet rolled". See GameState.to_public_dict()'s star_systems handling.
var hidden_difficulty: int = -1
var hidden_critical_threshold: int = -1

func _init(system_letter: String) -> void:
	letter = system_letter
	opportunity_completed.connect(func(_i: int) -> void: changed.emit())
	wolf_base_destroyed_changed.connect(func(_d: bool) -> void: changed.emit())
	hidden_difficulty_rolled.connect(func() -> void: changed.emit())

func definition() -> StarSystemDefinition:
	return StarSystemDefinitions.get_definition(letter)

func is_opportunity_completed(index: int) -> bool:
	return index in completed_opportunity_indices

func complete_opportunity(index: int) -> void:
	if index in completed_opportunity_indices:
		return
	completed_opportunity_indices.append(index)
	opportunity_completed.emit(index)

func set_wolf_base_destroyed(destroyed: bool) -> void:
	wolf_base_destroyed = destroyed
	wolf_base_destroyed_changed.emit(destroyed)

## Rolls against the given rng (never randi()/randf() directly, per
## CLAUDE.md), and only the first time - the source treats this as a
## single fixed value once generated, not something re-rolled per
## attempt at the opportunity.
func roll_hidden_difficulty(rng: RandomNumberGenerator) -> void:
	if hidden_difficulty != -1:
		return
	var x := rng.randi_range(1, 6)
	hidden_difficulty = 5 * x
	hidden_critical_threshold = 5 * x + 10
	hidden_difficulty_rolled.emit()

func to_dict() -> Dictionary:
	return {
		"letter": letter,
		"completed_opportunity_indices": completed_opportunity_indices.duplicate(),
		"wolf_base_destroyed": wolf_base_destroyed,
		"hidden_difficulty": hidden_difficulty,
		"hidden_critical_threshold": hidden_critical_threshold,
	}

func load_from_dict(data: Dictionary) -> void:
	completed_opportunity_indices.clear()
	for index: Variant in data.get("completed_opportunity_indices", []):
		completed_opportunity_indices.append(int(index))
	wolf_base_destroyed = bool(data.get("wolf_base_destroyed", false))
	hidden_difficulty = int(data.get("hidden_difficulty", -1))
	hidden_critical_threshold = int(data.get("hidden_critical_threshold", -1))

static func from_dict(data: Dictionary) -> StarSystem:
	var system := StarSystem.new(data.get("letter", ""))
	system.load_from_dict(data)
	return system
