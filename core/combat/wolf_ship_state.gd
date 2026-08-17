class_name WolfShipState
extends RefCounted

## One physical Wolf ship card's state for the current attack. Id is
## generated once by WolfAttack.add_wolf_ship() and stays stable for
## the whole attack, so the TV display can animate a specific token
## instead of rebuilding its grid (wolf_attack_tv_display.md §6).

signal damage_changed(new_value: int)
signal target_changed(new_die: int)
signal changed()

var id: String
var wolf_class: WolfShipDefinitions.Class
var damage_taken: int = 0

## 1-6 once targeting is rolled (WolfAttack.add_wolf_ship() rolls it
## immediately - FG p10: pre-roll before announcing the attack). 0 only
## ever appears transiently before that roll.
var target_die: int = 0

## Which range phase this ship was destroyed in, or -1 if it hasn't
## been destroyed (or was destroyed outside a range phase, which
## shouldn't normally happen). Needed because a destroyed ship's dying
## blow is locked in at the moment of destruction - see
## WolfAttack.compute_damage_tally().
var destroyed_at_phase: int = -1

func _init(ship_id: String, cls: WolfShipDefinitions.Class) -> void:
	id = ship_id
	wolf_class = cls
	damage_changed.connect(func(_v: int) -> void: changed.emit())
	target_changed.connect(func(_v: int) -> void: changed.emit())

func capacity() -> int:
	return WolfShipDefinitions.capacity_for(wolf_class)

func is_destroyed() -> bool:
	return damage_taken >= capacity()

func set_damage(new_value: int) -> void:
	damage_taken = clampi(new_value, 0, capacity())
	damage_changed.emit(damage_taken)

func add_damage(delta: int) -> void:
	set_damage(damage_taken + delta)

## Wraps 1-6: a shift below 1 lands on 6, above 6 lands on 1 - "0s hit
## Refinery 124 and 7s hit the AEGIS" per the source's own phrasing.
func set_target_die(new_die: int) -> void:
	var wrapped := new_die
	if wrapped < 1:
		wrapped = 6
	elif wrapped > 6:
		wrapped = 1
	target_die = wrapped
	target_changed.emit(target_die)

func target_ship_id() -> String:
	if target_die == 0:
		return ""
	return WolfShipDefinitions.TARGETING_TABLE.get(target_die, "")

func to_dict() -> Dictionary:
	return {
		"id": id,
		"wolf_class": WolfShipDefinitions.Class.keys()[wolf_class],
		"damage_taken": damage_taken,
		"target_die": target_die,
		"destroyed_at_phase": destroyed_at_phase,
	}

static func from_dict(data: Dictionary) -> WolfShipState:
	var state := WolfShipState.new(data.get("id", ""), WolfShipDefinitions.Class[data.get("wolf_class", "CRUISER")])
	state.damage_taken = int(data.get("damage_taken", 0))
	state.target_die = int(data.get("target_die", 0))
	state.destroyed_at_phase = int(data.get("destroyed_at_phase", -1))
	return state
