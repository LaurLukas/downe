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

func test_roll_request_for_maintenance_riot_rolls_and_marks_step_complete() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("dione"))
	var router := MessageRouter.new(state)

	router.route(NetMessage.make("roll_request", {"ship": "dione", "reason": "maintenance_riot"}))

	assert_eq(state.roll_log.entries.size(), 1, "routing a maintenance_riot roll_request should produce exactly one roll")
	assert_eq(state.roll_log.entries[0]["reason"], "maintenance_riot", "the logged roll should carry the requested reason key")
	assert_true(state.get_ship("dione").is_maintenance_step_complete(MaintenanceCycle.Step.RIOT_ROLL), "a client-triggered riot roll should mark the same checklist step the host console marks")

func test_roll_request_for_an_unwired_reason_is_ignored_not_crashed() -> void:
	# maintenance_unrest and weapon_fire are deliberately not wired yet -
	# see the router's own comment. A request for either must be a
	# silent no-op, not a crash or a wrongly-parameterized roll.
	var state := GameState.new()
	state.add_ship(Ship.new("aegis"))
	var router := MessageRouter.new(state)

	router.route(NetMessage.make("roll_request", {"ship": "aegis", "reason": "maintenance_unrest"}))

	assert_eq(state.roll_log.entries.size(), 0, "an unwired reason key should not roll anything")

func test_roll_request_for_unknown_ship_is_ignored_not_crashed() -> void:
	var state := GameState.new()
	var router := MessageRouter.new(state)
	router.route(NetMessage.make("roll_request", {"ship": "no_such_ship", "reason": "maintenance_riot"}))
	assert_eq(state.roll_log.entries.size(), 0, "a roll_request for a nonexistent ship should not roll anything")

func test_unhandled_type_emits_signal() -> void:
	var state := GameState.new()
	var router := MessageRouter.new(state)
	var received: Array[Dictionary] = []
	router.unhandled_message.connect(func(message: Dictionary) -> void: received.append(message))

	router.route(NetMessage.make("something_unrouted", {"foo": "bar"}))

	assert_eq(received.size(), 1, "an unrecognized message type should emit unhandled_message")
