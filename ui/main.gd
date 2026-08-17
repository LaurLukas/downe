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

func _init() -> void:
	# Crash recovery: if a previous run left a save behind, resume from
	# it instead of starting a fresh fleet. See CLAUDE.md's Persistence
	# section - the failure mode this exists for is twenty people
	# standing around while the host restarts something.
	var saved := Persistence.load_dict()
	if saved.is_empty():
		game_state = FleetSetup.build_starting_fleet()
		CraftSetup.populate_starting_craft(game_state)
	else:
		game_state = GameState.from_dict(saved)

func _ready() -> void:
	message_router = MessageRouter.new(game_state)
	persistence = Persistence.new(game_state)

	add_child(net_server)
	net_server.message_received.connect(_on_message_received)
	net_server.client_connected.connect(_on_client_connected)
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
	tv_window.size = Vector2i(1920, 1080)
	var tv_display := preload("res://ui/tv/tv_display.tscn").instantiate()
	tv_window.add_child(tv_display)
	add_child(tv_window)
	tv_display.game_state = game_state

func _on_message_received(_peer_id: int, message: Dictionary) -> void:
	message_router.route(message)

## Pushes the full state to a client the moment it connects, so it
## isn't stuck showing nothing until someone else causes a mutation.
func _on_client_connected(peer_id: int) -> void:
	net_server.send(peer_id, NetMessage.make("state", {"state": game_state.to_dict()}))

## Every connected ESP32/web/phone client gets the full state pushed on
## every mutation - see GameState.mutated and CLAUDE.md's Persistence
## section, which asks for the same "dump everything, every mutation"
## treatment for the save file. Right-sizing this to per-field diffs is
## future work if payload size ever becomes a real problem on the
## ESP32s (see CLAUDE.md's Networking section).
func _broadcast_state() -> void:
	net_server.broadcast(NetMessage.make("state", {"state": game_state.to_dict()}))
