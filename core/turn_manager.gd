class_name TurnManager
extends RefCounted

## One Turn = one Team Phase (5 min) + one Coordination Phase (15 min).
## 6-8 turns per game.

enum Phase { TEAM, COORDINATION }

signal phase_changed(turn: int, phase: Phase)

## Emitted only by advance() - never by force_set(). Distinct from
## phase_changed because some effects (pursuit +2/turn -
## GameState._on_advanced()) must fire on a genuine turn advance and
## must NOT fire when force_set() is used to restore a save
## (GameState.from_dict()) or for a host correction (HostConsole's
## "Force Set" override) - neither of those is really "a turn
## happened". phase_changed still fires for both, for things that
## legitimately care about "the displayed phase changed" regardless of
## why (UI refreshes, the Team-Phase clearing sweep, which is a no-op
## against empty ships/craft during from_dict() restore either way).
signal advanced(turn: int, phase: Phase)

var turn_number: int = 1
var phase: Phase = Phase.TEAM

func advance() -> void:
	if phase == Phase.TEAM:
		phase = Phase.COORDINATION
	else:
		phase = Phase.TEAM
		turn_number += 1
	phase_changed.emit(turn_number, phase)
	advanced.emit(turn_number, phase)

## Host override - jump straight to any turn/phase to match a ruling
## made at the table. See CLAUDE.md constraint 5.
func force_set(new_turn: int, new_phase: Phase) -> void:
	turn_number = new_turn
	phase = new_phase
	phase_changed.emit(turn_number, phase)

func to_dict() -> Dictionary:
	return {"turn_number": turn_number, "phase": Phase.keys()[phase]}
