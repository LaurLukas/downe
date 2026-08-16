extends TestCase

func test_make_sets_type_and_fields() -> void:
	var message := NetMessage.make("ping", {"ship_id": "dione"})
	assert_eq(message.get("type"), "ping", "make() should set the type field")
	assert_eq(message.get("ship_id"), "dione", "make() should include extra fields")

func test_encode_decode_round_trip() -> void:
	var original := NetMessage.make("set_jump_coordinates", {"ship_id": "quellon", "coordinates": "3,7,2"})
	var decoded := NetMessage.decode(NetMessage.encode(original))
	assert_eq(decoded.get("type"), "set_jump_coordinates", "round trip should preserve type")
	assert_eq(decoded.get("coordinates"), "3,7,2", "round trip should preserve fields")

func test_decode_rejects_invalid_json() -> void:
	assert_eq(NetMessage.decode("not json"), {}, "invalid JSON should decode to {}")

func test_decode_rejects_missing_type() -> void:
	assert_eq(NetMessage.decode('{"ship_id": "dione"}'), {}, "a message with no type field should decode to {}")

func test_decode_rejects_non_object_json() -> void:
	assert_eq(NetMessage.decode("[1, 2, 3]"), {}, "a JSON array is not a valid message envelope")
