class_name Player
extends RefCounted

## A physical player at the table. Loyalty itself stays on paper -
## CLAUDE.md constraint 4, and the software never learns who's a Wolf
## Agent. This class only tracks the two things
## open_questions_answered.md §4.5 says a phone page carries: a
## suspicion number, and any clues the facilitator chooses to send.
##
## Starting suspicion varies by which paper loyalty card a player was
## dealt (0/5/6/10/15 - see open_questions_answered.md §4.1) and the
## host types it in once cards are dealt at the table; there's no
## fleet-wide default the way ship resources have one.
##
## A nonzero suspicion score is not evidence of anything by itself -
## the doc is explicit that loyalists start at 5 and 10 on purpose.
## Nothing in this class or its UI should imply otherwise.

signal suspicion_changed(new_value: int)
signal clue_added(entry: Dictionary)
signal changed()

var id: String
var name: String
var suspicion: int = 0

## Facilitator-issued messages only - see class comment. Oldest first;
## newest-first ordering is a display concern, not a storage one.
var clues: Array[Dictionary] = []

func _init(player_id: String, player_name: String) -> void:
	id = player_id
	name = player_name
	suspicion_changed.connect(func(_v: int) -> void: changed.emit())
	clue_added.connect(func(_e: Dictionary) -> void: changed.emit())

func set_suspicion(new_value: int) -> void:
	suspicion = maxi(new_value, 0)
	suspicion_changed.emit(suspicion)

func add_suspicion(delta: int) -> void:
	set_suspicion(suspicion + delta)

func add_clue(text: String, turn_number: int) -> void:
	var entry := {"text": text, "turn_number": turn_number}
	clues.append(entry)
	clue_added.emit(entry)

## FG's arrest-posse formula (open_questions_answered.md §4.3): 6
## players including the accuser, minus 1 per 5 suspicion on the
## target, plus 1 per player who stands up for them. Host-only -
## "tell the players the number required, never the suspicion value."
## Facilitators may still adjust by +/-1 at their own discretion; this
## returns the unadjusted base number.
static func posse_size_required(target_suspicion: int, standers: int) -> int:
	return maxi(6 - (target_suspicion / 5) + standers, 1)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"suspicion": suspicion,
		"clues": clues.duplicate(true),
	}

func load_from_dict(data: Dictionary) -> void:
	name = String(data.get("name", name))
	suspicion = int(data.get("suspicion", 0))
	clues.clear()
	for entry: Dictionary in data.get("clues", []):
		clues.append(entry)

static func from_dict(data: Dictionary) -> Player:
	var player := Player.new(data.get("id", ""), String(data.get("name", "")))
	player.load_from_dict(data)
	return player
