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
## path_tree plus the four additive fields from ui/design_handoff_star_map/
## star_map_tv_visual_implementation.md §9 (short_name,
## consequence_summary, left_turn/visited_turns, band_tint, scouts) -
## scout_rings, jump_ranges, and highlight are still left out: they're
## host-toggled overlays needing destination state nothing in core/
## tracks yet, separate from the scout *reach* data `scouts` now
## carries (see TODO.md).

static func build(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState, craft: Dictionary) -> Dictionary:
	return _build(chart, turn, fleet_positions, reveal_state, craft, false)

## Ground truth for the host's own admin console (§8) - every node's
## letter/name/class/consequence is always attached, regardless of
## whether the fleet has actually been there. **Never wire this to the
## TV or to anything that reaches the network** - it's a separate
## entrypoint precisely so the redacted `build()` path (what the TV and
## GameState.to_public_dict() actually use) has no flag or parameter
## that could accidentally be flipped to this. The admin console is its
## own scene, never routed to the second monitor, same boundary
## CLAUDE.md and the spec already draw for it.
static func build_ground_truth(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState, craft: Dictionary) -> Dictionary:
	return _build(chart, turn, fleet_positions, reveal_state, craft, true)

static func _build(chart: String, turn: int, fleet_positions: FleetPositions, reveal_state: RevealState, craft: Dictionary, reveal_all: bool) -> Dictionary:
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
		nodes.append(_build_node(coordinate, chart, visited, occupied, fleet_positions.visited_turns, reveal_state, reveal_all))

	var band_tint_winners := _band_tint_winners(groups, aegis_group_id)
	var group_dicts: Array[Dictionary] = []
	for group: Dictionary in groups:
		var tier := _tier_of(String(group["at"]))
		var band_tint: bool = band_tint_winners.get(tier, "") == group["id"]
		group_dicts.append(_build_group(group, band_tint, _scouts_for_group(group["id"], craft, unit_group)))

	return {
		"type": "star_map",
		"chart_id": chart,
		"turn": turn,
		"nodes": nodes,
		"groups": group_dicts,
		"path_tree": PathTree.build(fleet_positions.trails, unit_group, aegis_group_id),
	}

static func _tier_of(coordinate: String) -> int:
	return 0 if coordinate == StarChart.START else -StarChart.pursuit_reduction_at(coordinate)

## §2.2: "Two groups in one band: the AEGIS group's accent wins."
## tier -> the group id whose band tint should show there.
static func _band_tint_winners(groups: Array, aegis_group_id: String) -> Dictionary:
	var winner_by_tier: Dictionary[int, String] = {}
	for group: Dictionary in groups:
		var tier := _tier_of(String(group["at"]))
		if not winner_by_tier.has(tier) or group["id"] == aegis_group_id:
			winner_by_tier[tier] = group["id"]
	return winner_by_tier

## Which scout craft currently dock on a member of this group, with
## their jump range (§6.6). Public information (players can count hops
## on their own chart) - see core/map/scout_ranges.gd's own comment on
## why this isn't the constraint-1 violation that validating a scout's
## *report* would be. Reads live CraftState.docked_ship_id, not each
## scout's home ship, since redeploy can move a scout to a different
## ship mid-game.
static func _scouts_for_group(group_id: String, craft: Dictionary, unit_group: Dictionary) -> Array[Dictionary]:
	var scouts: Array[Dictionary] = []
	for craft_id in ScoutRanges.all_scout_craft_ids():
		var craft_state: CraftState = craft.get(craft_id)
		if craft_state == null:
			continue
		if unit_group.get(craft_state.docked_ship_id, "") != group_id:
			continue
		var entry := {"label": ScoutRanges.label_for(craft_id)}
		if ScoutRanges.is_unlimited(craft_id):
			entry["unlimited"] = true
		else:
			entry["jumps"] = ScoutRanges.jumps_for(craft_id)
		scouts.append(entry)
	return scouts

static func _build_node(coordinate: String, chart: String, visited: Dictionary, occupied: Dictionary, visited_turns: Dictionary, reveal_state: RevealState, reveal_all: bool) -> Dictionary:
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

	# C1/C2: letter/name/class/consequence/short_name/consequence_summary/
	# visited_turns exist iff the coordinate has genuinely been visited or
	# is occupied right now - derived from is_visited/is_occupied
	# directly, never from `state`, so a host "force state" override can
	# change what's *displayed* without ever becoming a path to leaking
	# real content for a node the fleet hasn't actually reached.
	if reveal_all or is_visited or is_occupied:
		var turns: Array = (visited_turns.get(coordinate, []) as Array).duplicate()
		if not turns.is_empty():
			node["visited_turns"] = turns
			# left_turn (design handoff §9): "visited_turns.back() when no
			# unit is there" - omitted while occupied, since the rail shows
			# who's *currently* there instead (§6.2).
			if not is_occupied:
				node["left_turn"] = turns[-1]

		if coordinate == StarChart.START:
			node["letter"] = "START"
			node["name"] = "Fleet Origin"
			node["class"] = "start"
			node["short_name"] = "ORIGIN"
		else:
			var letter := StarChart.system_letter_at(chart, coordinate)
			var definition := StarSystemDefinitions.get_definition(letter)
			node["letter"] = letter
			node["name"] = definition.display_name if definition != null else ""
			node["class"] = _system_class(letter)
			if definition != null and not definition.short_name.is_empty():
				node["short_name"] = definition.short_name
			var consequence := _consequence(letter)
			if not consequence.is_empty():
				node["consequence"] = consequence
			if definition != null and not definition.consequence_summary.is_empty():
				node["consequence_summary"] = definition.consequence_summary

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

static func _build_group(group: Dictionary, band_tint: bool, scouts: Array[Dictionary]) -> Dictionary:
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
		"band_tint": band_tint,
		"scouts": scouts,
	}
