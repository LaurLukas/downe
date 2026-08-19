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
	JumpResolver.resolve(ship, track, 2, -1)
	assert_eq(ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL), 3, "fuel should be deducted by fuel_cost")
	assert_true(not ship.drive_charged, "drive should discharge after a jump")

func test_resolve_falls_pursuit_track_by_the_given_delta() -> void:
	var ship := Ship.new("refinery_124")
	var track := PursuitTrack.new()
	track.set_value(5)
	JumpResolver.resolve(ship, track, 0, -1)
	assert_eq(track.value, 4, "pursuit track should fall by the caller-supplied delta")

func test_resolve_rises_pursuit_track_by_the_given_delta() -> void:
	var ship := Ship.new("refinery_124")
	var track := PursuitTrack.new()
	track.set_value(5)
	JumpResolver.resolve(ship, track, 0, 1)
	assert_eq(track.value, 6, "pursuit track should rise by the caller-supplied delta")

func test_resolve_falls_pursuit_track_by_the_full_cumulative_tier_magnitude() -> void:
	# The confirmed reading (star_map_tv_display.md's "top blocker",
	# resolved as cumulative per tier, not flat -1 per jump): a jump to
	# a tier-4 destination falls pursuit by the tier's full -4, looked
	# up via StarChart.pursuit_reduction_at() by whoever adjudicates the
	# jump - JumpResolver itself never computes this from typed text.
	var ship := Ship.new("refinery_124")
	var track := PursuitTrack.new()
	track.set_value(8)
	var destination := "1096" # tier 4, -4 band
	JumpResolver.resolve(ship, track, 0, StarChart.pursuit_reduction_at(destination))
	assert_eq(track.value, 4, "pursuit track should fall by the destination's full cumulative tier reduction")
