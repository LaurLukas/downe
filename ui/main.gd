class_name Main
extends Node

## Composition root for the host application. Wires core/'s GameState
## to net/'s server, router, and persistence, and to ui/'s two views:
## the host console (this window) and the TV display (a second Window
## meant for the projector/TV). Runs natively on the host's laptop -
## never exported to web. See CLAUDE.md's Runtime topology.

const LISTEN_PORT := 8080

var game_state: GameState
var net_server := NetServer.new()
var message_router: MessageRouter
var persistence: Persistence

func _init() -> void:
	game_state = FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(game_state)

func _ready() -> void:
	message_router = MessageRouter.new(game_state)
	persistence = Persistence.new(game_state)

	add_child(net_server)
	net_server.message_received.connect(_on_message_received)
	var err := net_server.start(LISTEN_PORT)
	if err != OK:
		push_error("Main: failed to start NetServer on port %d (%s)" % [LISTEN_PORT, err])

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
