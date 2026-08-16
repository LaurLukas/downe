class_name AbilityResult
extends RefCounted

## Result of Ability.execute(). data carries whatever the ability needs
## to report back (dice rolled, materials spent, hits scored) - the
## terminal UI reads it, the ability never displays anything itself.

var ok: bool
var reason: String
var data: Dictionary

func _init(is_ok: bool, why: String = "", result_data: Dictionary = {}) -> void:
	ok = is_ok
	reason = why
	data = result_data

static func success(result_data: Dictionary = {}) -> AbilityResult:
	return AbilityResult.new(true, "", result_data)

static func failure(reason: String) -> AbilityResult:
	return AbilityResult.new(false, reason)
