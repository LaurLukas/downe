extends TestCase

func test_is_destroyed_at_capacity() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.set_damage(2)
	assert_true(not ship.is_destroyed(), "2 damage on a 3-capacity ship should not destroy it")
	ship.set_damage(3)
	assert_true(ship.is_destroyed(), "damage at capacity should destroy it")

func test_damage_clamps_between_zero_and_capacity() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.add_damage(-5)
	assert_eq(ship.damage_taken, 0, "damage should not go negative")
	ship.add_damage(99)
	assert_eq(ship.damage_taken, ship.capacity(), "damage should clamp at capacity")

func test_target_die_resolves_to_ship_id() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.set_target_die(3)
	assert_eq(ship.target_ship_id(), "icebreaker", "die 3 should resolve to icebreaker")

func test_target_die_wraps_above_six() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.set_target_die(7)
	assert_eq(ship.target_die, 1, "a die of 7 should wrap to 1 (hits the AEGIS)")

func test_target_die_wraps_below_one() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.set_target_die(0)
	assert_eq(ship.target_die, 6, "a die of 0 should wrap to 6 (hits Refinery 124)")

func test_untargeted_ship_has_no_target_ship_id() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	assert_eq(ship.target_ship_id(), "", "a ship that hasn't been targeted yet should have no target ship id")

func test_changes_bubble_to_changed_signal() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	var count: Array[int] = [0]
	ship.changed.connect(func() -> void: count[0] += 1)
	ship.set_damage(1)
	ship.set_target_die(2)
	assert_eq(count[0], 2, "both damage and target changes should bubble to changed")

func test_round_trips_through_dict() -> void:
	var ship := WolfShipState.new("cruiser_1", WolfShipDefinitions.Class.CRUISER)
	ship.set_damage(2)
	ship.set_target_die(4)
	ship.destroyed_at_phase = WolfShipDefinitions.RangePhase.MEDIUM

	var loaded := WolfShipState.from_dict(ship.to_dict())

	assert_eq(loaded.id, "cruiser_1", "id should round-trip")
	assert_eq(loaded.wolf_class, WolfShipDefinitions.Class.CRUISER, "class should round-trip")
	assert_eq(loaded.damage_taken, 2, "damage should round-trip")
	assert_eq(loaded.target_die, 4, "target die should round-trip")
	assert_eq(loaded.destroyed_at_phase, WolfShipDefinitions.RangePhase.MEDIUM, "destroyed_at_phase should round-trip")
