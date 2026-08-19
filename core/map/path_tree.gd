class_name PathTree
extends RefCounted

## Builds the "path tree" (docs/star_map_tv_display.md §6.3): the set
## of *distinct* routes the fleet has taken, deduplicated from every
## unit's individual trail. Each tree edge is drawn exactly once no
## matter how many units' trails pass through it; branches split only
## at a real fork (a node the tree gives more than one child), and a
## branch is tagged "live" if at least one group's current position
## still lies past it, "dead" otherwise (§6.3: "a route travelled by a
## group that has since merged back").
##
## Static, stateless, and independently testable against synthetic
## trails - doesn't touch FleetPositions or GameState directly, per
## this project's "core/ classes are RefCounted, headlessly testable"
## rule.
##
## Known simplification: a *single unit* revisiting an already-placed
## node (backtracking on its own trail, not a group split) isn't given
## its own distinct tree edge back - the existing edge is reused and
## simply stops being "live" once that unit's current position no
## longer descends from it. This produces the same dead/live result the
## spec's own worked example wants (an abandoned detour renders as a
## dead stub) without needing a second, reverse copy of the same edge.

static func build(trails: Dictionary, unit_group: Dictionary, aegis_group_id: String) -> Dictionary:
	var unit_ids: Array = trails.keys()
	unit_ids.sort() # deterministic regardless of Dictionary iteration order

	var children: Dictionary[String, Array] = {}
	var parent_of: Dictionary[String, String] = {}

	for unit_id in unit_ids:
		var trail: Array = trails[unit_id]
		for i in range(trail.size() - 1):
			var from: String = String(trail[i])
			var to: String = String(trail[i + 1])
			if from == to or to == StarChart.START or parent_of.has(to):
				continue
			if not children.has(from):
				children[from] = []
			if not (to in children[from]):
				(children[from] as Array).append(to)
			parent_of[to] = from

	## "from|to" -> Array[String] of group ids whose current position
	## descends from this edge.
	var live_group_ids_by_edge: Dictionary[String, Array] = {}
	for unit_id in unit_ids:
		var group_id: String = String(unit_group.get(unit_id, ""))
		if group_id.is_empty():
			continue
		var trail: Array = trails[unit_id]
		if trail.is_empty():
			continue
		var node := String(trail[-1])
		while parent_of.has(node):
			var parent: String = parent_of[node]
			var key := "%s|%s" % [parent, node]
			if not live_group_ids_by_edge.has(key):
				live_group_ids_by_edge[key] = []
			if not (group_id in live_group_ids_by_edge[key]):
				(live_group_ids_by_edge[key] as Array).append(group_id)
			node = parent

	var branches: Array[Dictionary] = []
	var branch_counter := 0
	var stack: Array[String] = [StarChart.START]
	while not stack.is_empty():
		var start: String = stack.pop_back()
		var kids: Array = children.get(start, [])
		for first_child in kids:
			var nodes: Array[String] = [start, first_child]
			var current: String = first_child
			while true:
				var next_children: Array = children.get(current, [])
				if next_children.size() != 1:
					break
				current = next_children[0]
				nodes.append(current)

			var key := "%s|%s" % [start, first_child]
			var group_ids: Array = (live_group_ids_by_edge.get(key, []) as Array).duplicate()
			group_ids.sort()

			branch_counter += 1
			branches.append({
				"id": "b%d" % branch_counter,
				"nodes": nodes,
				"state": "live" if not group_ids.is_empty() else "dead",
				"group": group_ids[0] if not group_ids.is_empty() else "",
				"group_ids": group_ids,
				"primary": not aegis_group_id.is_empty() and aegis_group_id in group_ids,
			})

			if (children.get(current, []) as Array).size() >= 2:
				stack.append(current)

	return {"root": StarChart.START, "branches": branches}
