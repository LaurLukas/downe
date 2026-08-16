extends TestCase

func test_cannot_jump_without_charged_drive() -> void:
	var ship := Ship.new("refinery_124")
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	ship.set_jump_coordinates("3,7,2")
	assert_true(not JumpResolver.can_jump(ship, 2), "should not be able to jump with an uncharged drive")

func test_cannot_jump_without_enough_fuel() -> void:
	var ship := Ship.new("refinery_124")
	ship.set_drive_charged(true)
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 1)
	ship.set_jump_coordinates("3,7,2")
	assert_true(not JumpResolver.can_jump(ship, 2), "should not be able to jump without enough fuel")

func test_cannot_jump_without_coordinates() -> void:
	var ship := Ship.new("refinery_124")
	ship.set_drive_charged(true)
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	assert_true(not JumpResolver.can_jump(ship, 2), "should not be able to jump without coordinates written down")

func test_can_jump_when_all_conditions_met() -> void:
	var ship := Ship.new("refinery_124")
	ship.set_drive_charged(true)
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	ship.set_jump_coordinates("3,7,2")
	assert_true(JumpResolver.can_jump(ship, 2), "should be able to jump when drive, fuel, and coordinates are all set")

func test_resolve_deducts_fuel_and_discharges_drive() -> void:
	var ship := Ship.new("refinery_124")
	ship.set_drive_charged(true)
	ship.resources.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 5)
	ship.set_jump_coordinates("3,7,2")
	var track := PursuitTrack.new()
	JumpResolver.resolve(ship, track, 2, true)
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL), 3, "fuel should be deducted by fuel_cost")
	assert_true(not ship.drive_charged, "drive should discharge after a jump")

func test_resolve_falls_pursuit_track_when_moving_away() -> void:
	var ship := Ship.new("refinery_124")
	var track := PursuitTrack.new()
	track.set_value(5)
	JumpResolver.resolve(ship, track, 0, true)
	assert_eq(track.value, 4, "pursuit track should fall when jumping away from Wolf space")

func test_resolve_rises_pursuit_track_when_not_moving_away() -> void:
	var ship := Ship.new("refinery_124")
	var track := PursuitTrack.new()
	track.set_value(5)
	JumpResolver.resolve(ship, track, 0, false)
	assert_eq(track.value, 6, "pursuit track should rise when not jumping away from Wolf space")
