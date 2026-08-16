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
