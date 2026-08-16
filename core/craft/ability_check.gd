class_name AbilityCheck
extends RefCounted

## Result of Ability.can_execute(). Carries *why* an ability is
## unavailable, not just whether - the terminal UI needs to show the
## player the reason ("not fuelled", "not docked", "insufficient
## materials"). See downe_shuttle_implementation_prompt.md §1.

var ok: bool
var reason: String

func _init(is_ok: bool, why: String = "") -> void:
	ok = is_ok
	reason = why

static func allowed() -> AbilityCheck:
	return AbilityCheck.new(true)

static func denied(reason: String) -> AbilityCheck:
	return AbilityCheck.new(false, reason)
