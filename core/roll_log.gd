class_name RollLog
extends RefCounted

## Append-only audit trail of every roll RollService has made - the
## artefact a suspicious player (or host) is pointed at when someone
## accuses the software of cheating (docs/dice_engine_spec.md §1/§8).
## Unlike AnnouncementLog, this is deliberately NOT capped: "append-only"
## is the whole point (§6), and a full game only produces a few hundred
## rolls - trimming the very thing meant to prove nothing was hidden
## would defeat it.
##
## Entries are the exact dict RollService stamps, plus the RollService-
## internal recipe (n/modifier/thresholds or n/target) needed to
## recompute an override later - see RollService.override_roll(). Newest
## last, matching sequence order (unlike AnnouncementLog, which is
## newest-first for a "most recent at the top" TV feed - there's no
## equivalent display reason to reverse an audit log; sequence order is
## the natural read order).

signal entry_added(entry: Dictionary)

var entries: Array[Dictionary] = []

func add(entry: Dictionary) -> void:
	entries.append(entry)
	entry_added.emit(entry)

## Used by RollService.override_roll() to find the original entry by
## its stamped id and append a new, marked-override entry - the
## original is never mutated or removed (spec §7: "the original result
## stays in the audit log; overrides append, never overwrite").
func find_by_id(id: int) -> Dictionary:
	for entry: Dictionary in entries:
		if int(entry.get("id", -1)) == id:
			return entry
	return {}

func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}

func load_from_dict(data: Dictionary) -> void:
	entries.clear()
	for entry: Dictionary in data.get("entries", []):
		entries.append(entry)
