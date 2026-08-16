class_name Persistence
extends RefCounted

## Dumps GameState to user:// on every mutation and can reload it on
## startup. Crash recovery matters more than performance here - the
## failure mode is twenty people standing around while the host
## restarts something. See CLAUDE.md's Persistence section.
##
## core/ never touches FileAccess; this is where its pure
## GameState.to_dict() output meets the filesystem.

const SAVE_PATH := "user://game_state.json"

var game_state: GameState

func _init(state: GameState) -> void:
	game_state = state
	game_state.mutated.connect(save)

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Persistence: failed to open %s for writing (%s)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(game_state.to_dict(), "\t"))

## Returns the last saved dict, or {} if there's nothing on disk yet or
## it fails to parse. Rehydrating a GameState from this dict is the
## caller's job - this only moves bytes.
static func load_dict() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
