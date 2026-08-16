class_name NetMessage
extends RefCounted

## Flat JSON envelope: {"type": "...", ...}. Keep payloads small - the
## ESP32 terminals parse them on limited RAM. See CLAUDE.md's
## Networking section.

static func make(type: String, fields: Dictionary = {}) -> Dictionary:
	var message := {"type": type}
	for key in fields:
		message[key] = fields[key]
	return message

static func encode(message: Dictionary) -> String:
	return JSON.stringify(message)

## Returns {} if text isn't valid JSON, isn't an object, or has no
## "type" field - callers can treat an empty dict as "ignore this".
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type"):
		return {}
	return parsed
