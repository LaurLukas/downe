class_name StarMapProjection
extends RefCounted

## The C2 leak boundary (docs/star_map_tv_display.md §2/§7): builds the
## flat dict ui/ receives for the star map screen. Unvisited letters
## are stripped *here*, at the source - the TV scene this feeds never
## holds the full chart, so a future bug in a label binding can't put
## it on screen. See test_star_map_projection.gd's leak tests, which
## are the load-bearing tests for this whole module (matching how
## WolfAttackView's leak tests were written first for the same reason).
##
## Deliberately scoped to what §7's schema needs for nodes/groups/
## path_tree - scout_rings, jump_ranges, and highlight are host-toggled
## overlays that need scout-range and destination state nothing in
## core/ tracks yet, and are left out of this pass; see TODO.md.

static func build(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState) -> Dictionary:
	return _build(chart, turn, fleet_positions, reveal_state, false)

## Ground truth for the host's own admin console (§8) - every node's
## letter/name/class/consequence is always attached, regardless of
## whether the fleet has actually been there. **Never wire this to the
## TV or to anything that reaches the network** - it's a separate
## entrypoint precisely so the redacted `build()` path (what the TV and
## GameState.to_public_dict() actually use) has no flag or parameter
## that could accidentally be flipped to this. The admin console is its
## own scene, never routed to the second monitor, same boundary
## CLAUDE.md and the spec already draw for it.
static func build_ground_truth(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState) -> Dictionary:
	return _build(chart, turn, fleet_positions, reveal_state, true)

static func _build(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState, reveal_all: bool) -> Dictionary:
	var groups := fleet_positions.groups()

	var unit_group: Dictionary[String, String] = {}
	var aegis_group_id := ""
	for group: Dictionary in groups:
		var members: Array = group["members"]
		for unit_id: String in members:
			unit_group[unit_id] = group["id"]
		if FleetPositions.AEGIS in members:
			aegis_group_id = group["id"]

	var visited: Dictionary[String, bool] = {}
	for unit_id: String in fleet_positions.trails:
		for coordinate: Variant in (fleet_positions.trails[unit_id] as Array):
			visited[String(coordinate)] = true

	var occupied: Dictionary[String, bool] = {}
	for unit_id: String in fleet_positions.positions:
		occupied[fleet_positions.positions[unit_id]] = true

	var nodes: Array[Dictionary] = []
	for coordinate in StarChart.all_coordinates():
		nodes.append(_build_node(coordinate, chart, visited, occupied, reveal_state, reveal_all))

	var group_dicts: Array[Dictionary] = []
	for group: Dictionary in groups:
		group_dicts.append(_build_group(group))

	return {
		"type": "star_map",
		"chart_id": chart,
		"turn": turn,
		"nodes": nodes,
		"groups": group_dicts,
		"path_tree": PathTree.build(fleet_positions.trails, unit_group, aegis_group_id),
	}

static func _build_node(coordinate: String, chart: String, visited: Dictionary, occupied: Dictionary, reveal_state: RevealState, reveal_all: bool) -> Dictionary:
	var forced: String = reveal_state.forced_states.get(coordinate, "")
	var claims: Array = reveal_state.claims_at(coordinate)
	var is_visited: bool = visited.get(coordinate, false)
	var is_occupied: bool = occupied.get(coordinate, false)

	var state: String
	if not forced.is_empty():
		state = forced
	elif is_occupied:
		state = "occupied"
	elif is_visited:
		state = "visited"
	elif not claims.is_empty():
		state = "reported"
	else:
		state = "unknown"

	var node: Dictionary = {"id": coordinate, "state": state}
	if not claims.is_empty():
		node["claims"] = claims

	# C1/C2: letter/name/class/consequence exist iff the coordinate has
	# genuinely been visited or is occupied right now - derived from
	# is_visited/is_occupied directly, never from `state`, so a host
	# "force state" override can change what's *displayed* without ever
	# becoming a path to leaking real content for a node the fleet
	# hasn't actually reached.
	if reveal_all or is_visited or is_occupied:
		if coordinate == StarChart.START:
			node["letter"] = "START"
			node["name"] = "Fleet Origin"
			node["class"] = "start"
		else:
			var letter := StarChart.system_letter_at(chart, coordinate)
			var definition := StarSystemDefinitions.get_definition(letter)
			node["letter"] = letter
			node["name"] = definition.display_name if definition != null else ""
			node["class"] = _system_class(letter)
			var consequence := _consequence(letter)
			if not consequence.is_empty():
				node["consequence"] = consequence

	return node

## Derived from StarSystemDefinition's existing flags rather than a
## second hand-typed table, so it can't drift from docs/star_charts.json's
## `systems[letter].class` values - cross-checked by hand against all
## 13 card-based letters when this was written.
static func _system_class(letter: String) -> String:
	var definition := StarSystemDefinitions.get_definition(letter)
	if definition == null:
		return ""
	if definition.is_new_eden_candidate:
		return "new_eden"
	if definition.triggers_wolf_attack_on_arrival:
		return "wolf"
	if definition.triggers_wolf_attack_unless_critical or definition.maintenance_damage_threshold != -1:
		return "hazard"
	if definition.rating == "Poor":
		return "poor"
	if definition.rating == "Neutral":
		return "neutral"
	return "standard"

static func _consequence(letter: String) -> String:
	var definition := StarSystemDefinitions.get_definition(letter)
	if definition == null:
		return ""
	if definition.suppresses_pursuit_reduction:
		return "no_pursuit_reduction"
	if definition.triggers_wolf_attack_on_arrival:
		return "wolf_attack"
	if definition.triggers_wolf_attack_unless_critical:
		return "wolf_attack_risk"
	if definition.maintenance_damage_threshold != -1:
		return "maintenance_damage"
	return ""

const _ABBREVIATIONS: Dictionary = {
	"aegis": "AEG", "dione": "DIO", "icebreaker": "ICE",
	"shepherd": "SHP", "quellon": "QUE", "refinery_124": "R124",
	"voyage_33_0": "V330",
}

static func _display_name(unit_id: String) -> String:
	if unit_id == "voyage_33_0":
		return "G.I.V. Voyage 33-0"
	return ShipRegistry.display_name(unit_id)

static func _build_group(group: Dictionary) -> Dictionary:
	var members: Array = group["members"]
	var member_names: Array[String] = []
	for unit_id: String in members:
		member_names.append(_display_name(unit_id))

	var representative: String = group["representative"]
	return {
		"id": group["id"],
		"index": group["index"],
		"label": group["label"],
		"at": group["at"],
		"representative": {
			"id": representative,
			"abbr": _ABBREVIATIONS.get(representative, representative.to_upper()),
			"colour": "#" + ShipColors.for_ship(representative).to_html(false),
			"is_aegis": representative == FleetPositions.AEGIS,
		},
		"members": member_names,
		# Raw unit ids alongside the display names above - not secret
		# (capital ship names are public in the fiction), needed by the
		# admin console's "set representative" control to actually call
		# FleetPositions.set_group_representative(group_id, unit_id).
		"member_ids": (members as Array).duplicate(),
		"pursuit": group["pursuit"],
		"pending_merge_pursuits": group["pending_merge_pursuits"],
	}
