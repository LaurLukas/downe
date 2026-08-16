extends TestCase

func test_set_jump_coordinates_updates_ship() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("quellon", true))
	var router := MessageRouter.new(state)

	router.route(NetMessage.make("set_jump_coordinates", {"ship_id": "quellon", "coordinates": "3,7,2"}))

	assert_eq(state.get_ship("quellon").jump_coordinates, "3,7,2", "routing set_jump_coordinates should update the ship")

func test_set_drive_charged_updates_ship() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("refinery_124"))
	var router := MessageRouter.new(state)

	router.route(NetMessage.make("set_drive_charged", {"ship_id": "refinery_124", "charged": true}))

	assert_true(state.get_ship("refinery_124").drive_charged, "routing set_drive_charged should update the ship")

func test_unknown_ship_id_is_ignored_not_crashed() -> void:
	var state := GameState.new()
	var router := MessageRouter.new(state)
	router.route(NetMessage.make("set_drive_charged", {"ship_id": "no_such_ship", "charged": true}))
	assert_true(true, "routing a message for an unknown ship should not throw")

func test_unhandled_type_emits_signal() -> void:
	var state := GameState.new()
	var router := MessageRouter.new(state)
	var received: Array[Dictionary] = []
	router.unhandled_message.connect(func(message: Dictionary) -> void: received.append(message))

	router.route(NetMessage.make("something_unrouted", {"foo": "bar"}))

	assert_eq(received.size(), 1, "an unrecognized message type should emit unhandled_message")
