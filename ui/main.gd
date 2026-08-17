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
	var err := net_server.start(HTTP_LISTEN_PORT, WS_LISTEN_PORT)
	if err != OK:
		push_error("Main: failed to start NetServer (http %d, ws %d): %s" % [HTTP_LISTEN_PORT, WS_LISTEN_PORT, err])

	# add_child() first in both cases below: @onready vars (and thus
	# set_game_state()/the game_state setter, which touch them) only
	# resolve once _ready() has run, which requires being in the tree.
	var host_console := preload("res://ui/host/host_console.tscn").instantiate()
	add_child(host_console)
	host_console.set_game_state(game_state)

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
	var tv_display := preload("res://ui/tv/tv_display.tscn").instantiate()
	tv_window.add_child(tv_display)
	var wolf_attack_display := preload("res://ui/tv/wolf_attack_display.tscn").instantiate()
	tv_window.add_child(wolf_attack_display)
	add_child(tv_window)
	tv_display.game_state = game_state
	wolf_attack_display.game_state = game_state

	# Same TV window, two screens sharing it: WolfAttackDisplay takes
	# over the instant a Wolf Attack starts and TVDisplay resumes the
	# instant it ends. Toggled via visible, not swapped in/out of the
	# tree, so animation/scroll state in either one survives a host
	# flipping back and forth (e.g. checking pursuit mid-attack).
	game_state.mutated.connect(func() -> void:
		var attack_active := game_state.wolf_attack != null
		wolf_attack_display.visible = attack_active
		tv_display.visible = not attack_active
	)
	tv_display.visible = game_state.wolf_attack == null
	wolf_attack_display.visible = game_state.wolf_attack != null

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
