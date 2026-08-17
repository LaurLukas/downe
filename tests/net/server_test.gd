extends TestCase

## The socket-level tests below exercise real loopback TCP/WebSocket
## connections against a live NetServer - not just its pure helper
## methods. This is deliberate: the two-port split (see server.gd's
## file comment) exists because the previous one-port sniffing design
## silently hung every WebSocket handshake forever, and nothing in the
## suite caught it since nothing opened a real socket against it. Each
## test uses its own port pair so a slow-to-release listener from a
## previous test can't collide with the next one.

func test_parse_request_path_extracts_path() -> void:
	var request := "GET /app.js HTTP/1.1\r\nHost: example\r\n\r\n"
	assert_eq(NetServer._parse_request_path(request), "/app.js", "should extract the path from the request line")

func test_parse_request_path_defaults_to_root_on_malformed_request() -> void:
	assert_eq(NetServer._parse_request_path("garbage"), "/", "a malformed request line should default to /")

func _wait_for(condition: Callable, max_iterations: int = 300) -> bool:
	for _i in max_iterations:
		if condition.call():
			return true
		OS.delay_msec(5)
	return false

func test_static_file_served_over_http_port() -> void:
	var server := NetServer.new()
	assert_eq(server.start(18180, 18181), OK, "server should start on both ports")

	var client := StreamPeerTCP.new()
	client.connect_to_host("127.0.0.1", 18180)
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return client.get_status() == StreamPeerTCP.STATUS_CONNECTED
	), "client should connect to the http port")

	client.put_data("GET /app.js HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".to_utf8_buffer())
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return client.get_available_bytes() > 0
	), "client should receive a response")

	var response := client.get_utf8_string(client.get_available_bytes())
	assert_true(response.begins_with("HTTP/1.1 200 OK"), "requesting an existing static file should return 200")

	server.stop()

func test_websocket_client_completes_handshake_and_server_routes_its_message() -> void:
	var server := NetServer.new()
	assert_eq(server.start(18182, 18183), OK, "server should start on both ports")
	var received: Array[Dictionary] = []
	server.message_received.connect(func(_peer_id: int, message: Dictionary) -> void: received.append(message))

	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:18183/")
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return client.get_ready_state() == WebSocketPeer.STATE_OPEN
	), "a client should be able to complete a WebSocket handshake against the dedicated ws port")

	client.send_text(NetMessage.encode(NetMessage.make("set_drive_charged", {"ship_id": "aegis", "charged": true})))
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return received.size() > 0
	), "the server should route a message the client sent")
	assert_eq(received[0].get("type"), "set_drive_charged", "the routed message should be the one the client sent")

	server.stop()

func test_client_connected_signal_and_broadcast() -> void:
	var server := NetServer.new()
	assert_eq(server.start(18184, 18185), OK, "server should start on both ports")
	var connected_peer_ids: Array[int] = []
	server.client_connected.connect(func(peer_id: int) -> void: connected_peer_ids.append(peer_id))

	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:18185/")
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return client.get_ready_state() == WebSocketPeer.STATE_OPEN
	), "client should reach STATE_OPEN")
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		return connected_peer_ids.size() > 0
	), "client_connected should fire once the handshake completes")

	server.broadcast(NetMessage.make("state", {"value": 42}))
	assert_true(_wait_for(func() -> bool:
		server._process(0.0)
		client.poll()
		return client.get_available_packet_count() > 0
	), "broadcast should deliver a packet to the connected client")
	var msg: Dictionary = JSON.parse_string(client.get_packet().get_string_from_utf8())
	assert_eq(msg.get("type"), "state", "the broadcast message should decode back to what was sent")
	assert_eq(msg.get("value"), 42, "the broadcast payload should round-trip")

	server.stop()
