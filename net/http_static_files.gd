class_name HttpStaticFiles
extends RefCounted

## Pure request-path and content-type helpers for serving res://web/ over
## HTTP. No socket I/O here - that lives in server.gd. Kept pure so it
## can be unit tested without a live TCP connection.

const WEB_ROOT := "res://web/"

const CONTENT_TYPES: Dictionary[String, String] = {
	"html": "text/html; charset=utf-8",
	"htm": "text/html; charset=utf-8",
	"css": "text/css; charset=utf-8",
	"js": "text/javascript; charset=utf-8",
	"json": "application/json; charset=utf-8",
	"png": "image/png",
	"jpg": "image/jpeg",
	"jpeg": "image/jpeg",
	"svg": "image/svg+xml",
	"ico": "image/x-icon",
}

const DEFAULT_CONTENT_TYPE := "application/octet-stream"

static func content_type_for(path: String) -> String:
	var extension := path.get_extension().to_lower()
	return CONTENT_TYPES.get(extension, DEFAULT_CONTENT_TYPE)

## Resolves an HTTP request path (e.g. "/", "/app.js") to a res://web/
## path, or "" if the request is malformed or would escape the web
## root. Never trust the raw request path - phones and ESP32s on this
## network are untrusted clients.
static func resolve_path(request_path: String) -> String:
	var clean := request_path.split("?")[0]
	if clean.is_empty() or clean == "/":
		clean = "/index.html"
	if not clean.begins_with("/"):
		return ""
	for segment in clean.split("/"):
		if segment == "..":
			return ""
	return WEB_ROOT.trim_suffix("/") + clean

static func build_response_header(status_code: int, status_text: String, content_type: String, content_length: int) -> String:
	return "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status_code, status_text, content_type, content_length]
