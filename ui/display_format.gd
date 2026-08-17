class_name DisplayFormat
extends RefCounted

## Pure string-formatting helpers shared by the TV display and host
## console. No Node/scene access here, so these are unit testable the
## same way core/ is.

static func phase_label(phase: TurnManager.Phase) -> String:
	match phase:
		TurnManager.Phase.TEAM:
			return "Team Phase"
		TurnManager.Phase.COORDINATION:
			return "Coordination Phase"
		_:
			return "Unknown Phase"

static func turn_label(turn_manager: TurnManager) -> String:
	return "Turn %d - %s" % [turn_manager.turn_number, phase_label(turn_manager.phase)]

static func pursuit_bar(track: PursuitTrack, width: int = 10) -> String:
	var filled := clampi(roundi(float(track.value) / float(PursuitTrack.MAX_VALUE) * width), 0, width)
	return "[%s%s] %d/%d" % ["#".repeat(filled), "-".repeat(width - filled), track.value, PursuitTrack.MAX_VALUE]

static func console_state_label(state: Console.State) -> String:
	match state:
		Console.State.OK:
			return "OK"
		Console.State.DAMAGED:
			return "DAMAGED"
		Console.State.DESTROYED:
			return "DESTROYED"
		_:
			return "UNKNOWN"

const _RESOURCE_KIND_LABELS: Dictionary[ResourceStock.Kind, String] = {
	ResourceStock.Kind.STRYTIUM_ORE: "Ore",
	ResourceStock.Kind.STRYTIUM_FUEL: "Fuel",
	ResourceStock.Kind.FOOD: "Food",
	ResourceStock.Kind.WATER: "Water",
	ResourceStock.Kind.MATERIALS: "Materials",
	ResourceStock.Kind.SECURITY_TEAMS: "Security",
}

## e.g. "Ore 0 | Fuel 4 | Food 8 | Water 6 | Materials 1 | Security 9"
static func resource_summary(stock: ResourceStock) -> String:
	var parts: Array[String] = []
	for kind: ResourceStock.Kind in _RESOURCE_KIND_LABELS:
		parts.append("%s %d" % [_RESOURCE_KIND_LABELS[kind], stock.get_amount(kind)])
	return " | ".join(parts)

## One-line spectacle summary for the TV display's fleet overview.
static func ship_status_line(ship: Ship) -> String:
	var drive := "charged" if ship.drive_charged else "uncharged"
	var jump := ship.jump_coordinates if not ship.jump_coordinates.is_empty() else "(none)"
	return "Drive: %s | Jump: %s | Unrest: %d | %s" % [drive, jump, ship.unrest, resource_summary(ship.resources)]

## One line for the TV display's announcement feed. entry is an
## AnnouncementLog entry dict - see that class for the shape. Whatever
## was typed is shown verbatim, never validated - see CLAUDE.md
## constraint 1.
static func announcement_line(entry: Dictionary) -> String:
	var kind: String = entry.get("kind", "")
	var source_id: String = entry.get("source_id", "")
	var source_label := source_id
	var kind_label := "Report"
	if kind == "jump":
		source_label = ShipRegistry.display_name(source_id)
		kind_label = "Jump coordinates"
	elif kind == "scout":
		var definition := CraftDefinitions.get_definition(source_id)
		source_label = definition.display_name if definition != null else source_id
		kind_label = "Scout report"
	return "Turn %d - %s (%s): %s" % [entry.get("turn_number", 0), kind_label, source_label, entry.get("text", "")]
