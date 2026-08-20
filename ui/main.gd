class_name Main
extends Node

## Composition root for the host application. Wires core/'s GameState
## to net/'s server, router, and persistence, and to ui/'s two views:
## the host console (this window) and the TV display (a second Window
## meant for the projector/TV). Runs natively on the host's laptop -
## never exported to web. See CLAUDE.md's Runtime topology.

const HTTP_LISTEN_PORT := 8080
const WS_LISTEN_PORT := 8081

var game_state: GameState
var net_server := NetServer.new()
var message_router: MessageRouter
var persistence: Persistence

## player_id -> peer_id, for the one channel that isn't broadcast to
## everyone: a player's own suspicion/clues. Populated when a phone
## page identifies itself (see _on_identify_player()), cleared on
## disconnect. See GameState.to_public_dict()'s comment for why this
## split exists.
var _player_peer_ids: Dictionary[String, int] = {}

## Which of TVDisplay/StarMapScreen is up when no Wolf Attack is active
## - toggled from HostConsole's "Show Star Map" button
## (star_map_toggle_pressed), or forced on for STAR_MAP_AUTO_SHOW_SECONDS
## after a unit actually moves (see _star_map_auto_show_timer below).
## docs/star_map_tv_display.md §8's "on demand during the Coordination
## Phase" line is just this same toggle - a host action, nothing further
## to build. Its "idle screen between phases, at 60% brightness" line is
## NOT built: that only makes sense if StarMapScreen is the *default*
## idle screen, and in this app TVDisplay already holds that role
## (fleet status + announcements) - swapping the default out is a real
## product decision, not something to sneak in while "just wiring", so
## it's left as an open question in TODO.md rather than guessed here.
var _show_star_map := false

## §8: "Automatically for 45s after every jump resolution." This
## codebase has no separate "jump resolution" event yet - JumpResolver
## isn't wired into any UI (see TODO.md) - so FleetPositions.changed is
## the closest real signal: it fires when the host records a unit
## actually arriving somewhere via the admin console's Move control,
## which today *is* how a jump gets recorded. Restarted, not just
## started, on every move, so back-to-back jumps keep the map up rather
## than letting it drop between them.
const STAR_MAP_AUTO_SHOW_SECONDS := 45.0
var _star_map_auto_show_timer: Timer

var _tv_display: Control
var _wolf_attack_display: Control
var _star_map_screen: Control

func _init() -> void:
	# Crash recovery: if a previous run left a save behind, resume from
	# it instead of starting a fresh fleet. See CLAUDE.md's Persistence
	# section - the failure mode this exists for is twenty people
	# standing around while the host restarts something.
	var saved := Persistence.load_dict()
	if saved.is_empty():
		game_state = FleetSetup.build_starting_fleet()
		CraftSetup.populate_starting_craft(game_state)
		StarSystemSetup.populate_star_systems(game_state)
	else:
		game_state = GameState.from_dict(saved)

func _ready() -> void:
	message_router = MessageRouter.new(game_state)
	persistence = Persistence.new(game_state)

	add_child(net_server)
	net_server.message_received.connect(_on_message_received)
	net_server.client_connected.connect(_on_client_connected)
	net_server.client_disconnected.connect(_on_client_disconnected)
	game_state.mutated.connect(_broadcast_state)
	game_state.roll_service.rolled.connect(_on_roll_result)
	var err := net_server.start(HTTP_LISTEN_PORT, WS_LISTEN_PORT)
	if err != OK:
		push_error("Main: failed to start NetServer (http %d, ws %d): %s" % [HTTP_LISTEN_PORT, WS_LISTEN_PORT, err])

	# add_child() first in both cases below: @onready vars (and thus
	# set_game_state()/the game_state setter, which touch them) only
	# resolve once _ready() has run, which requires being in the tree.
	var host_console := preload("res://ui/host/host_console.tscn").instantiate()
	add_child(host_console)
	host_console.set_game_state(game_state)
	host_console.star_map_toggle_pressed.connect(_on_star_map_toggle_pressed)

	var tv_window := Window.new()
	tv_window.title = "Downe - TV Display"
	# 1920x1080 is the design resolution (see wolf_attack_tv_display.md),
	# but sizing the actual OS window to exactly that and leaving Godot
	# to place it at its default (0, 0) means the title bar and edges -
	# which sit outside the content area - land off-screen on any
	# display at or near that same resolution, making the window look
	# borderless and impossible to drag despite genuinely having a
	# border. Smaller default so decorations always have room to render
	# on-screen; still freely resizable up to full design resolution
	# and beyond. A dedicated fullscreen/multi-monitor mode for actual
	# venue use is a separate, not-yet-built concern - see TODO.md's
	# Deployment item.
	tv_window.size = Vector2i(1280, 720)
	tv_window.position = Vector2i(80, 80)
	# WolfAttackDisplay's STANDING layout is authored against a fixed
	# 1920x1080 design space (wolf_attack_tv_display_v2_gap_spec.md §2.1)
	# - every position inside it is a literal design-space pixel value,
	# not computed from get_viewport_rect(). content_scale makes this
	# Window report that fixed canvas to its children regardless of the
	# real OS window size (still freely resizable, per the window-border
	# fix above - KEEP_ASPECT letterboxes rather than distorting).
	tv_window.content_scale_size = Vector2i(1920, 1080)
	tv_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	tv_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var tv_display := preload("res://ui/tv/tv_display.tscn").instantiate()
	tv_window.add_child(tv_display)
	var wolf_attack_display := preload("res://ui/tv/wolf_attack_display.tscn").instantiate()
	tv_window.add_child(wolf_attack_display)
	var star_map_screen := preload("res://ui/tv/star_map/star_map_screen.tscn").instantiate()
	tv_window.add_child(star_map_screen)
	add_child(tv_window)
	tv_display.game_state = game_state
	wolf_attack_display.game_state = game_state
	star_map_screen.game_state = game_state

	_tv_display = tv_display
	_wolf_attack_display = wolf_attack_display
	_star_map_screen = star_map_screen

	# Three screens sharing one TV window: WolfAttackDisplay takes over
	# the instant a Wolf Attack starts and whichever of TVDisplay/
	# StarMapScreen was showing resumes the instant it ends (constraint
	# 3 - the attack screen has absolute priority, matching
	# docs/star_map_tv_display.md §8's "Never during a Wolf Attack").
	# Toggled via visible, not swapped in/out of the tree, so scroll/draw
	# state in any of them survives a host flipping back and forth.
	game_state.mutated.connect(_update_tv_visibility)

	_star_map_auto_show_timer = Timer.new()
	_star_map_auto_show_timer.one_shot = true
	_star_map_auto_show_timer.wait_time = STAR_MAP_AUTO_SHOW_SECONDS
	add_child(_star_map_auto_show_timer)
	# timeout drops the map back to whatever the manual toggle alone
	# would show; connected directly (not via `mutated`, which
	# FleetPositions.changed already bubbles into) so the auto-show
	# window is guaranteed to actually be running before this same
	# handler re-evaluates visibility - see _on_fleet_positions_changed.
	_star_map_auto_show_timer.timeout.connect(_update_tv_visibility)
	game_state.fleet_positions.changed.connect(_on_fleet_positions_changed)

	_update_tv_visibility()

func _on_star_map_toggle_pressed() -> void:
	_show_star_map = not _show_star_map
	_update_tv_visibility()

## Starting the timer here, in a handler on FleetPositions.changed
## itself, rather than relying on GameState's own fleet_positions.changed
## -> mutated bubbling (which _update_tv_visibility is also connected
## to) matters: GameState wires that bubble before Main ever runs, so if
## this only listened to `mutated`, _update_tv_visibility would run
## *before* the timer had been (re)started on the very move that should
## trigger it, showing stale visibility for one mutation.
func _on_fleet_positions_changed() -> void:
	_star_map_auto_show_timer.start(STAR_MAP_AUTO_SHOW_SECONDS)
	_update_tv_visibility()

func _update_tv_visibility() -> void:
	var attack_active := game_state.wolf_attack != null
	var auto_show_active := not _star_map_auto_show_timer.is_stopped()
	var show_star_map := _show_star_map or auto_show_active
	_wolf_attack_display.visible = attack_active
	_star_map_screen.visible = not attack_active and show_star_map
	_tv_display.visible = not attack_active and not show_star_map

## "identify_player" is transport bookkeeping (which socket belongs to
## which player), not a GameState mutation, so it's handled here rather
## than routed through MessageRouter - see that class's own comment on
## being "the only place in net/ that calls into core/" for mutations.
func _on_message_received(peer_id: int, message: Dictionary) -> void:
	if message.get("type", "") == "identify_player":
		_on_identify_player(peer_id, message)
		return
	message_router.route(message)

## Pushes the public state to a client the moment it connects, so it
## isn't stuck showing nothing until someone else causes a mutation.
## Never the full to_dict() here - see GameState.to_public_dict().
func _on_client_connected(peer_id: int) -> void:
	net_server.send(peer_id, NetMessage.make("state", {"state": game_state.to_public_dict()}))

func _on_client_disconnected(peer_id: int) -> void:
	for player_id: String in _player_peer_ids.keys():
		if _player_peer_ids[player_id] == peer_id:
			_player_peer_ids.erase(player_id)

## A phone page announces which player it belongs to right after
## connecting (see web/player.js). Unknown/malformed ids are ignored,
## same trust posture as the rest of net/ - untrusted clients on this
## network, but nothing here is worth validating harder than "does this
## id exist".
func _on_identify_player(peer_id: int, message: Dictionary) -> void:
	var player_id: String = message.get("player_id", "")
	if not game_state.players.has(player_id):
		return
	_player_peer_ids[player_id] = peer_id
	net_server.send(peer_id, NetMessage.make("player_state", {"state": game_state.player_to_dict(player_id)}))

## Every connected ESP32/web/phone client gets the public state pushed
## on every mutation - see GameState.mutated and CLAUDE.md's Persistence
## section, which asks for the same "dump everything, every mutation"
## treatment for the save file. Right-sizing this to per-field diffs is
## future work if payload size ever becomes a real problem on the
## ESP32s (see CLAUDE.md's Networking section).
##
## Players' own suspicion/clues go out on a separate, targeted channel
## instead of the broadcast - see GameState.to_public_dict()'s comment.
func _broadcast_state() -> void:
	net_server.broadcast(NetMessage.make("state", {"state": game_state.to_public_dict()}))
	for player_id: String in _player_peer_ids:
		net_server.send(_player_peer_ids[player_id], NetMessage.make("player_state", {"state": game_state.player_to_dict(player_id)}))

## Mirrors a stamped roll (docs/dice_engine_spec.md §7) to every
## connected client as its own roll_result message, rather than folding
## it into the generic "state" broadcast above - a roll is an event a
## client animates (tumble, then settle on the true faces), not a
## snapshot it just re-renders. Already persisted before this ever
## fires - see GameState.dice_engine's comment on roll_log.entry_added
## bubbling into mutated ahead of RollService's own `rolled` emission,
## and RollService._stamp()'s comment on why game-specific fields
## (unrest_gain, damaged, hits, ...) are already present by the time
## this runs rather than added afterward.
func _on_roll_result(result: Dictionary) -> void:
	var message := {
		"id": result.get("id", 0),
		"ship": result.get("ship", ""),
		"reason": result.get("reason", ""),
		"faces": result.get("faces", PackedInt32Array()),
		"over": result.get("over", false),
		"text": RollText.describe(result),
	}
	if result.has("modifier"):
		message["mod"] = result["modifier"]
	if result.has("successes"):
		# count_successes shape: spec §7 says "band is replaced by hits
		# and target" for this shape.
		message["hits"] = result["successes"]
		message["target"] = result.get("target", 0)
	elif result.has("band"):
		message["total"] = result.get("total", 0)
		message["band"] = result["band"]
	net_server.broadcast(NetMessage.make("roll_result", message))
