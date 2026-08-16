class_name Ability
extends RefCounted

## Base contract every craft ability implements. Subclasses live in
## core/craft/abilities/, one file per ability, attached to craft by id
## via AbilityRegistry - not one hand-rolled class per shuttle.
##
## execute() must be pure with respect to randomness: roll against
## game_state.rng, never call randi()/randf() directly, so a game is
## reproducible from its JSON dump. See
## downe_shuttle_implementation_prompt.md §1.

func can_execute(_game_state: GameState, _craft_id: String, _params: Dictionary) -> AbilityCheck:
	return AbilityCheck.denied("not implemented")

func execute(_game_state: GameState, _craft_id: String, _params: Dictionary) -> AbilityResult:
	return AbilityResult.failure("not implemented")
