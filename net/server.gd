class_name NetServer
extends Node

## Two TCPServers: one serves static files from res://web/, the other
## accepts only WebSocket upgrades for ESP32 terminals, phones, and the
## browser terminal client. Do not use Godot's high-level
## multiplayer/RPC here; these are not Godot peers. See CLAUDE.md's
## Networking section.
##
## This used to be one port with the opening bytes of each connection
## sniffed for "Upgrade: websocket" to route it. That doesn't work:
## reading those bytes to sniff them consumes them, and
## WebSocketPeer.accept_stream() then has nothing left to read the
## handshake from - the connection hangs in STATE_CONNECTING forever.
## StreamPeerTCP has no way to peek without consuming, and
## accept_stream() has no way to accept pre-read bytes. Splitting into
## two ports sidesteps the problem entirely: accept_stream() always
## gets a fresh, untouched connection.

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal message_received(peer_id: int, message: Dictionary)

var _http_server := TCPServer.new()
var _ws_server := TCPServer.new()
var _pending_http: Array[StreamPeerTCP] = []
var _sockets: Dictionary[int, WebSocketPeer] = {}
## Peer ids whose handshake has reached STATE_OPEN and had
## client_connected emitted for them - see _poll_sockets(). Needed
## because accept_stream() only starts the handshake; a peer isn't
## really "connected" (able to receive a send()) until the socket
## reports STATE_OPEN, which takes a few more polls.
var _handshake_complete: Dictionary[int, bool] = {}
var _next_peer_id: int = 1

func start(http_port: int, ws_port: int) -> Error:
	var err := _http_server.listen(http_port)
	if err != OK:
		return err
	return _ws_server.listen(ws_port)

func stop() -> void:
	_http_server.stop()
	_ws_server.stop()
	for peer_id: int in _sockets:
		_sockets[peer_id].close()
	_sockets.clear()
	_handshake_complete.clear()
	_pending_http.clear()

func _process(_delta: float) -> void:
	while _ws_server.is_connection_available():
		_accept_websocket(_ws_server.take_connection())

	while _http_server.is_connection_available():
		_pending_http.append(_http_server.take_connection())
	_poll_pending_http()
	_poll_sockets()

func _poll_pending_http() -> void:
	var still_pending: Array[StreamPeerTCP] = []
	for connection in _pending_http:
		connection.poll()
		if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		if connection.get_available_bytes() <= 0:
			still_pending.append(connection)
		else:
			_serve_static_file(connection, connection.get_utf8_string(connection.get_available_bytes()))
	_pending_http = still_pending

func _accept_websocket(connection: StreamPeerTCP) -> void:
	var socket := WebSocketPeer.new()
	var err := socket.accept_stream(connection)
	if err != OK:
		push_error("NetServer: failed to accept websocket stream (%s)" % err)
		return
	var peer_id := _next_peer_id
	_next_peer_id += 1
	_sockets[peer_id] = socket

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
				if not _handshake_complete.has(peer_id):
					_handshake_complete[peer_id] = true
					client_connected.emit(peer_id)
				while socket.get_available_packet_count() > 0:
					var message := NetMessage.decode(socket.get_packet().get_string_from_utf8())
					if not message.is_empty():
						message_received.emit(peer_id, message)
			WebSocketPeer.STATE_CLOSED:
				_sockets.erase(peer_id)
				var was_connected := _handshake_complete.has(peer_id)
				_handshake_complete.erase(peer_id)
				if was_connected:
					client_disconnected.emit(peer_id)

func send(peer_id: int, message: Dictionary) -> void:
	if _sockets.has(peer_id):
		_sockets[peer_id].send_text(NetMessage.encode(message))

func broadcast(message: Dictionary) -> void:
	var text := NetMessage.encode(message)
	for peer_id: int in _sockets:
		_sockets[peer_id].send_text(text)
