class_name AnnouncementLog
extends RefCounted

## Rolling record of jump-coordinate and scout reports, newest first,
## for the TV display's announcement feed (TODO.md's "TV display
## completeness"). Purely a record of what was typed, whether it came
## from a scout's real report, a lying Wolf agent, or a host override
## through the same setters - never validated or flagged, per CLAUDE.md
## constraint 1. GameState wires this to Ship.jump_coordinates_set and
## CraftState.scout_report_set so every caller of those setters is
## logged automatically, with nothing in net/ or ui/ needing to know
## this exists.

signal entry_added(entry: Dictionary)

## Capped so a long game's save file and the TV feed don't grow without
## bound - only the most recent announcements matter for spectacle.
const MAX_ENTRIES := 30

## Newest first. Each entry: {kind: "jump"|"scout", source_id: ship or
## craft id, text: String, turn_number: int}.
var entries: Array[Dictionary] = []

func add(kind: String, source_id: String, text: String, turn_number: int) -> void:
	var entry := {
		"kind": kind,
		"source_id": source_id,
		"text": text,
		"turn_number": turn_number,
	}
	entries.push_front(entry)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	entry_added.emit(entry)

func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}

func load_from_dict(data: Dictionary) -> void:
	entries.clear()
	for entry: Dictionary in data.get("entries", []):
		entries.append(entry)
