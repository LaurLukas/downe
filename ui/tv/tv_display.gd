class_name TVDisplay
extends Control

## Spectacle screen for the TV/projector. Read-only view onto core/'s
## GameState - it never mutates state, only displays it. Wolf Attacks
## keep their physical battle-map gathering (CLAUDE.md constraint 3);
## this screen supports the room, it doesn't replace it.
##
## No Wolf Attack support screen yet - that needs a Wolf ship roster and
## attack-strength/battle-table model in core/ that doesn't exist yet
## (see TODO.md's Blocked section). Building a screen ahead of that data
## would mean inventing game rules rather than displaying real ones.
##
## Unlike HostConsole, everything here rebuilds freely on every
## GameState.mutated - there's no editable input a rebuild could
## interrupt, since this view never mutates anything.

@onready var _turn_label: Label = %TurnLabel
@onready var _pursuit_label: Label = %PursuitLabel
@onready var _fleet_list: VBoxContainer = %FleetList
@onready var _announcements_list: VBoxContainer = %AnnouncementsList

const TURN_FONT_SIZE := 48
const PURSUIT_FONT_SIZE := 40
const SHIP_NAME_FONT_SIZE := 28
const SHIP_DETAIL_FONT_SIZE := 20
const ANNOUNCEMENT_FONT_SIZE := 20

var game_state: GameState:
	set(value):
		if game_state != null:
			game_state.turn_manager.phase_changed.disconnect(_refresh)
			game_state.pursuit_track.changed.disconnect(_refresh)
			game_state.mutated.disconnect(_rebuild_fleet_status)
			game_state.mutated.disconnect(_rebuild_announcements)
		game_state = value
		if game_state != null:
			game_state.turn_manager.phase_changed.connect(_refresh)
			game_state.pursuit_track.changed.connect(_refresh)
			game_state.mutated.connect(_rebuild_fleet_status)
			game_state.mutated.connect(_rebuild_announcements)
			_refresh()
			_rebuild_fleet_status()
			_rebuild_announcements()

func _ready() -> void:
	_turn_label.add_theme_font_size_override("font_size", TURN_FONT_SIZE)
	_pursuit_label.add_theme_font_size_override("font_size", PURSUIT_FONT_SIZE)

func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	if game_state == null:
		return
	_turn_label.text = DisplayFormat.turn_label(game_state.turn_manager)
	_pursuit_label.text = DisplayFormat.pursuit_bar(game_state.pursuit_track)

func _rebuild_fleet_status() -> void:
	# free(), not queue_free(): this rebuild adds the replacement
	# children in the same call, and queue_free()'s deferred removal
	# would briefly leave old and new rows coexisting as siblings until
	# end-of-frame cleanup runs.
	for child in _fleet_list.get_children():
		child.free()
	for ship_id: String in game_state.ships:
		_fleet_list.add_child(_build_ship_row(game_state.ships[ship_id]))

func _build_ship_row(ship: Ship) -> Control:
	var row := VBoxContainer.new()

	var name_label := Label.new()
	name_label.text = ShipRegistry.display_name(ship.id)
	name_label.add_theme_font_size_override("font_size", SHIP_NAME_FONT_SIZE)
	row.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = DisplayFormat.ship_status_line(ship)
	detail_label.add_theme_font_size_override("font_size", SHIP_DETAIL_FONT_SIZE)
	row.add_child(detail_label)

	return row

func _rebuild_announcements() -> void:
	for child in _announcements_list.get_children():
		child.free()
	for entry: Dictionary in game_state.announcement_log.entries:
		var label := Label.new()
		label.text = DisplayFormat.announcement_line(entry)
		label.add_theme_font_size_override("font_size", ANNOUNCEMENT_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_announcements_list.add_child(label)
