class_name CraftSetup
extends RefCounted

## Populates a GameState with the starting craft roster: docked at
## home_ship, empty cargo, unfuelled. Source: resources.md's "Not
## specified in the source" section - shuttle starting cargo/fuel isn't
## printed anywhere, so this follows its explicit recommendation
## ("assume all shuttles start empty and unfuelled, but confirm before
## playtest").
##
## Fighter wings start full (4 fighters) - also unconfirmed.
## resources.md: "no setup value is given. Full wings (4 each) is the
## likely intent given the Construction Bay exists to replace losses,
## but confirm." Flagged in TODO.md; do not treat this as settled.

static func populate_starting_craft(game_state: GameState) -> void:
	for craft_id: String in CraftDefinitions.all_craft_ids():
		game_state.add_craft(build_craft(craft_id))

static func build_craft(craft_id: String) -> CraftState:
	var definition := CraftDefinitions.get_definition(craft_id)
	var state := CraftState.new(craft_id, definition.home_ship)
	if definition.max_fighters > 0:
		state.fighter_count = definition.max_fighters
	return state
