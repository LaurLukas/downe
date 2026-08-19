class_name FleetPositions
extends RefCounted

## Ground truth for where the seven jump-capable units are on the star
## chart, and their move history - docs/star_map_tv_display.md §4/§4.2.
## Set only through move_unit()/undo_last_move() (the host's "Move
## unit"/"Undo last move" controls, §8) - never derived from
## Ship.jump_coordinates, which is a scout's freely typed, possibly-
## lying claim (CLAUDE.md constraint 1), not the fleet's actual
## position. Units are the six capital ships (ShipRegistry ids) plus
## "voyage_33_0" - an optional Small Ship, not modeled as a core/
## object anywhere else yet, tracked here as a bare id (same "the data
## exists even where the object doesn't" treatment TODO.md gives every
## other Small-Ship-shaped gap). Shuttles and fighter wings never get a
## position (§4) - they're cargo, not units.
##
## Groups (§4.2) are *derived* - the set of units currently sharing a
## node - every time groups() is called, never stored as a partition.
## What *is* stored, and persists across a split/merge, is each group's
## id/label/representative/pursuit. Whether a group's pursuit still
## tracks the legacy single GameState.pursuit_track isn't a stored
## flag - it's just "is this currently the only group" (see
## sync_global_pursuit()): the instant a split makes that untrue, this
## group and whatever it split into are independently host-managed;
## the instant every unit merges back into one group, that single
## group starts tracking the live value again automatically.
##
## Every public mutator changes at most one unit's position per call,
## which bounds how much of the group structure can move in one step:
## a single relocation can peel at most one unit off its old group
## (a split) and/or land it on an already-occupied node (a merge) -
## never both a multi-way split and a multi-way merge at once. That
## lets _relocate() reason about "the one unit that moved" instead of
## re-diffing the whole partition from scratch on every call.

signal changed()

const AEGIS := "aegis"

## Selection order for a new group's representative when AEGIS isn't a
## member - §4.1: "which one does not matter to the display, so it is
## picked once when the group forms and then held for the life of that
## group."
const REPRESENTATIVE_ORDER: Array[String] = [
	"dione", "icebreaker", "shepherd", "quellon", "refinery_124", "voyage_33_0",
]

static func unit_ids() -> Array[String]:
	var ids: Array[String] = ShipRegistry.all_ship_ids().duplicate()
	ids.append("voyage_33_0")
	return ids

var positions: Dictionary[String, String] = {}
var trails: Dictionary[String, Array] = {}

var _group_of_unit: Dictionary[String, String] = {}
## group_id -> {label, representative, pursuit, pending_merge_pursuits}.
var _groups: Dictionary[String, Dictionary] = {}
var _next_group_number := 2 # "MAIN FLEET" is always g1; new groups count up from GROUP 2
var _next_group_id := 2

func _init() -> void:
	for unit_id in unit_ids():
		positions[unit_id] = StarChart.START
		trails[unit_id] = [StarChart.START] as Array[String]
		_group_of_unit[unit_id] = "g1"
	_groups["g1"] = _new_group_record("MAIN FLEET", AEGIS, 0)

func _new_group_record(label: String, representative: String, pursuit: int) -> Dictionary:
	return {
		"label": label,
		"representative": representative,
		"pursuit": pursuit,
		"pending_merge_pursuits": [] as Array[int],
	}

## Called by whoever wires this up to the legacy single GameState.
## pursuit_track (its `changed` signal). Only takes effect while
## there's exactly one group - the moment a split makes that untrue,
## every group involved is independently host-managed from then on
## (docs/star_map_tv_display.md §4.2: "pursuit is a property of a
## group, not of the game"); the moment everything merges back into
## one group, that group starts tracking this again automatically,
## without needing a special "resume tracking" call anywhere.
func sync_global_pursuit(value: int) -> void:
	if _groups.size() != 1:
		return
	var only_id: String = _groups.keys()[0]
	if _groups[only_id]["pursuit"] == value:
		return
	_groups[only_id]["pursuit"] = value
	changed.emit()

## The host's "Move unit" control (§8). Adjacency is *not* enforced -
## jump failures and host corrections can put a ship anywhere.
func move_unit(unit_id: String, coordinate: String) -> void:
	if not positions.has(unit_id):
		return
	trails[unit_id].append(coordinate)
	_relocate(unit_id, coordinate)

## The host's "Undo last move" control (§8) - pops the trail entry and
## restores the unit to wherever it was before.
func undo_last_move(unit_id: String) -> void:
	if not trails.has(unit_id) or trails[unit_id].size() <= 1:
		return
	trails[unit_id].pop_back()
	_relocate(unit_id, trails[unit_id][-1])

func _relocate(unit_id: String, new_coordinate: String) -> void:
	var old_coordinate: String = positions[unit_id]
	positions[unit_id] = new_coordinate
	if new_coordinate == old_coordinate:
		changed.emit()
		return

	var old_group_id: String = _group_of_unit[unit_id]
	var stayed_behind: Array[String] = []
	for other_unit in _members_of(old_group_id):
		if other_unit != unit_id:
			stayed_behind.append(other_unit)

	var movers_group_id := old_group_id
	if not stayed_behind.is_empty():
		# A split. The remainder keeps the old group's identity (label/
		# representative/pursuit) unless the unit that's leaving is
		# AEGIS - §4.1's "the group containing AEGIS is always
		# represented by AEGIS" reads as AEGIS's departure taking the
		# identity with it, so the side left behind is the one that
		# gets a fresh one instead.
		var pursuit_at_split: int = _groups[old_group_id]["pursuit"]
		if unit_id == AEGIS:
			_spawn_group(stayed_behind, pursuit_at_split)
		else:
			movers_group_id = _spawn_group([unit_id], pursuit_at_split)

	for other_unit in unit_ids():
		if other_unit != unit_id and positions[other_unit] == new_coordinate:
			_merge_groups(movers_group_id, _group_of_unit[other_unit])
			break

	changed.emit()

func _spawn_group(members: Array[String], pursuit: int) -> String:
	var group_id := "g%d" % _next_group_id
	_next_group_id += 1
	_groups[group_id] = _new_group_record("GROUP %d" % _next_group_number, _choose_representative(members), pursuit)
	_next_group_number += 1
	for unit_id in members:
		_group_of_unit[unit_id] = group_id
	return group_id

## Merges two groups into one, surviving as whichever of the two
## contains AEGIS (§4.1, no exception) or id_a otherwise. The absorbed
## group's pursuit is stashed, not discarded or averaged - §4.2/§8:
## "on merge, the host is prompted to reconcile the two pursuit values.
## Do not auto-resolve" - see reconcile_group_pursuit().
func _merge_groups(id_a: String, id_b: String) -> void:
	if id_a == id_b:
		return
	var members_b := _members_of(id_b)
	var survivor_id := id_a
	var absorbed_id := id_b
	var absorbed_members := members_b
	if AEGIS in members_b and not AEGIS in _members_of(id_a):
		survivor_id = id_b
		absorbed_id = id_a
		absorbed_members = _members_of(id_a)

	var survivor_record: Dictionary = _groups[survivor_id]
	var absorbed_record: Dictionary = _groups[absorbed_id]
	var pending: Array[int] = survivor_record["pending_merge_pursuits"].duplicate()
	pending.append(absorbed_record["pursuit"])
	pending.append_array(absorbed_record["pending_merge_pursuits"])
	survivor_record["pending_merge_pursuits"] = pending

	for unit_id in absorbed_members:
		_group_of_unit[unit_id] = survivor_id
	_groups.erase(absorbed_id)

func _members_of(group_id: String) -> Array[String]:
	var members: Array[String] = []
	for unit_id in unit_ids():
		if _group_of_unit.get(unit_id, "") == group_id:
			members.append(unit_id)
	return members

func _choose_representative(members: Array[String]) -> String:
	if AEGIS in members:
		return AEGIS
	for candidate in REPRESENTATIVE_ORDER:
		if candidate in members:
			return candidate
	return members[0] if not members.is_empty() else ""

## One entry per currently-derived group. "turns_here" (spec §6.5) isn't
## included yet - it needs a turn number, which nothing in this
## turn-agnostic, positions-only module has access to; deferred to
## whoever builds star_map_projection.gd, which already takes the
## current turn as an input.
func groups() -> Array[Dictionary]:
	var seen: Dictionary[String, bool] = {}
	var result: Array[Dictionary] = []
	var index := 1
	for unit_id in unit_ids():
		var group_id: String = _group_of_unit[unit_id]
		if seen.has(group_id):
			continue
		seen[group_id] = true
		var record: Dictionary = _groups[group_id]
		result.append({
			"id": group_id,
			"index": index,
			"label": record["label"],
			"representative": record["representative"],
			"members": _members_of(group_id),
			"at": positions[unit_id],
			"pursuit": record["pursuit"],
			"pending_merge_pursuits": (record["pending_merge_pursuits"] as Array).duplicate(),
		})
		index += 1
	return result

func set_group_label(group_id: String, label: String) -> void:
	if not _groups.has(group_id):
		return
	_groups[group_id]["label"] = label
	changed.emit()

## Direct host override of a group's pursuit (constraint 5) - also used
## for the non-merge case of just correcting a number.
func set_group_pursuit(group_id: String, value: int) -> void:
	if not _groups.has(group_id):
		return
	_groups[group_id]["pursuit"] = value
	changed.emit()

## The host's merge-reconciliation prompt (§4.2/§8) resolves to this -
## picks the value, clears the pending list it was choosing between.
func reconcile_group_pursuit(group_id: String, resolved_value: int) -> void:
	if not _groups.has(group_id):
		return
	_groups[group_id]["pursuit"] = resolved_value
	_groups[group_id]["pending_merge_pursuits"] = [] as Array[int]
	changed.emit()

## §8's "Set group representative" - locked to AEGIS for AEGIS's group,
## per §4.1's "no exception, no override".
func set_group_representative(group_id: String, unit_id: String) -> void:
	if not _groups.has(group_id):
		return
	var members := _members_of(group_id)
	if AEGIS in members and unit_id != AEGIS:
		return
	if not unit_id in members:
		return
	_groups[group_id]["representative"] = unit_id
	changed.emit()

func to_dict() -> Dictionary:
	var trails_dict := {}
	for unit_id: String in trails:
		trails_dict[unit_id] = (trails[unit_id] as Array).duplicate()
	var groups_dict := {}
	for group_id: String in _groups:
		groups_dict[group_id] = _groups[group_id].duplicate(true)
	return {
		"positions": positions.duplicate(),
		"trails": trails_dict,
		"group_of_unit": _group_of_unit.duplicate(),
		"groups": groups_dict,
		"next_group_number": _next_group_number,
		"next_group_id": _next_group_id,
	}

func load_from_dict(data: Dictionary) -> void:
	var raw_positions: Dictionary = data.get("positions", {})
	for unit_id: String in raw_positions:
		positions[unit_id] = String(raw_positions[unit_id])

	var raw_trails: Dictionary = data.get("trails", {})
	for unit_id: String in raw_trails:
		var trail: Array[String] = []
		for coordinate: Variant in (raw_trails[unit_id] as Array):
			trail.append(String(coordinate))
		trails[unit_id] = trail

	var raw_group_of_unit: Dictionary = data.get("group_of_unit", {})
	for unit_id: String in raw_group_of_unit:
		_group_of_unit[unit_id] = String(raw_group_of_unit[unit_id])

	_groups.clear()
	var raw_groups: Dictionary = data.get("groups", {})
	for group_id: String in raw_groups:
		var record: Dictionary = raw_groups[group_id]
		var pending: Array[int] = []
		for value: Variant in (record.get("pending_merge_pursuits", []) as Array):
			pending.append(int(value))
		_groups[group_id] = {
			"label": String(record.get("label", "")),
			"representative": String(record.get("representative", AEGIS)),
			"pursuit": int(record.get("pursuit", 0)),
			"pending_merge_pursuits": pending,
		}

	_next_group_number = int(data.get("next_group_number", 2))
	_next_group_id = int(data.get("next_group_id", 2))

static func from_dict(data: Dictionary) -> FleetPositions:
	var positions_state := FleetPositions.new()
	positions_state.load_from_dict(data)
	return positions_state
