class_name NetServer
extends Node

## One TCPServer for everything: ESP32 terminals, phones, and the
## browser terminal client. Sniffs each new connection's opening
## bytes - "Upgrade: websocket" gets WebSocketPeer.accept_stream(),
## anything else gets a static file from res://web/. Do not use
## Godot's high-level multiplayer/RPC here; these are not Godot peers.
## See CLAUDE.md's Networking section.

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal message_received(peer_id: int, message: Dictionary)

var _tcp_server := TCPServer.new()
var _pending: Array[StreamPeerTCP] = []
var _sockets: Dictionary[int, WebSocketPeer] = {}
var _next_peer_id: int = 1

func start(listen_port: int) -> Error:
	return _tcp_server.listen(listen_port)

func stop() -> void:
	_tcp_server.stop()
	for peer_id: int in _sockets:
		_sockets[peer_id].close()
	_sockets.clear()
	_pending.clear()

func _process(_delta: float) -> void:
	while _tcp_server.is_connection_available():
		_pending.append(_tcp_server.take_connection())
	_poll_pending()
	_poll_sockets()

func _poll_pending() -> void:
	var still_pending: Array[StreamPeerTCP] = []
	for connection in _pending:
		connection.poll()
		if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		if connection.get_available_bytes() <= 0:
			still_pending.append(connection)
		else:
			_handle_new_connection(connection)
	_pending = still_pending

func _handle_new_connection(connection: StreamPeerTCP) -> void:
	var request := connection.get_utf8_string(connection.get_available_bytes())
	if request.findn("Upgrade: websocket") != -1:
		_accept_websocket(connection)
	else:
		_serve_static_file(connection, request)

func _accept_websocket(connection: StreamPeerTCP) -> void:
	var socket := WebSocketPeer.new()
	socket.write_mode = WebSocketPeer.WRITE_MODE_TEXT
	var err := socket.accept_stream(connection)
	if err != OK:
		push_error("NetServer: failed to accept websocket stream (%s)" % err)
		return
	var peer_id := _next_peer_id
	_next_peer_id += 1
	_sockets[peer_id] = socket
	client_connected.emit(peer_id)

func _serve_static_file(connection: StreamPeerTCP, request: String) -> void:
	var resolved := HttpStaticFiles.resolve_path(_parse_request_path(request))
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		var body := "Not found".to_utf8_buffer()
		connection.put_data(HttpStaticFiles.build_response_header(404, "Not Found", "text/plain", body.size()).to_utf8_buffer())
		connection.put_data(body)
		connection.disconnect_from_host()
		return
	var file := FileAccess.open(resolved, FileAccess.READ)
	var body := file.get_buffer(file.get_length())
	var header := HttpStaticFiles.build_response_header(200, "OK", HttpStaticFiles.content_type_for(resolved), body.size())
	connection.put_data(header.to_utf8_buffer())
	connection.put_data(body)
	connection.disconnect_from_host()

## GET /path?query HTTP/1.1 -> /path?query
static func _parse_request_path(request: String) -> String:
	var first_line := request.split("\r\n")[0]
	var parts := first_line.split(" ")
	if parts.size() < 2:
		return "/"
	return parts[1]

func _poll_sockets() -> void:
	for peer_id: int in _sockets.keys():
		var socket := _sockets[peer_id]
		socket.poll()
		match socket.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while socket.get_available_packet_count() > 0:
					var message := NetMessage.decode(socket.get_packet().get_string_from_utf8())
					if not message.is_empty():
						message_received.emit(peer_id, message)
			WebSocketPeer.STATE_CLOSED:
				_sockets.erase(peer_id)
				client_disconnected.emit(peer_id)

func send(peer_id: int, message: Dictionary) -> void:
	if _sockets.has(peer_id):
		_sockets[peer_id].send_text(NetMessage.encode(message))

func broadcast(message: Dictionary) -> void:
	var text := NetMessage.encode(message)
	for peer_id: int in _sockets:
		_sockets[peer_id].send_text(text)
