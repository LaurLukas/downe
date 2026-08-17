extends TestCase

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return rng

func test_add_wolf_ship_generates_stable_incrementing_ids() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var first := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, rng)
	var second := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, rng)
	assert_eq(first.id, "cr_1", "the first cruiser should get a predictable id")
	assert_eq(second.id, "cr_2", "the second cruiser should get a different, incrementing id")
	assert_true(first.id != second.id, "ids must be unique so the TV can animate a specific token")

func test_add_wolf_ship_pre_rolls_a_target() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	assert_true(ship.target_die >= 1 and ship.target_die <= 6, "a new wolf ship should be pre-rolled with a valid target die immediately, not left at 0")

func test_reroll_target_changes_the_die() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, rng)
	var original := ship.target_die
	# Re-roll enough times that a changed value is overwhelmingly likely,
	# without depending on one specific rng outcome.
	var changed := false
	for i in 20:
		attack.reroll_target(ship.id, rng)
		if ship.target_die != original:
			changed = true
			break
	assert_true(changed, "reroll_target should be able to produce a different die value")

func test_shift_target_wraps() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	ship.set_target_die(6)
	attack.shift_target(ship.id, 1)
	assert_eq(ship.target_die, 1, "shifting past 6 should wrap to 1")
	attack.shift_target(ship.id, -1)
	assert_eq(ship.target_die, 6, "shifting past 1 downward should wrap to 6")

func test_force_target_sets_the_die_for_that_ship_id() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	attack.force_target(ship.id, "aegis")
	assert_eq(ship.target_ship_id(), "aegis", "force_target should set the target to the given ship")

func test_phase_advances_in_order_and_stops_at_resolution() -> void:
	var attack := WolfAttack.new()
	assert_eq(attack.phase, WolfAttack.Phase.INCOMING, "a new attack should start in INCOMING")
	attack.advance_phase()
	assert_eq(attack.phase, WolfAttack.Phase.TARGETING, "the first advance should reach TARGETING")
	attack.advance_phase()
	assert_eq(attack.phase, WolfAttack.Phase.RANGE_LONG, "the second advance should reach RANGE_LONG")
	attack.advance_phase()
	attack.advance_phase()
	attack.advance_phase()
	attack.advance_phase()
	assert_eq(attack.phase, WolfAttack.Phase.RESOLUTION, "six advances from INCOMING should land on RESOLUTION")
	attack.advance_phase()
	assert_eq(attack.phase, WolfAttack.Phase.RESOLUTION, "advancing past RESOLUTION should do nothing")

func test_phase_can_retreat() -> void:
	var attack := WolfAttack.new()
	attack.advance_phase()
	attack.advance_phase()
	assert_eq(attack.phase, WolfAttack.Phase.RANGE_LONG, "two advances should reach RANGE_LONG")
	attack.retreat_phase()
	assert_eq(attack.phase, WolfAttack.Phase.TARGETING, "the host must be able to move backwards")

func test_phase_cannot_retreat_past_incoming() -> void:
	var attack := WolfAttack.new()
	attack.retreat_phase()
	assert_eq(attack.phase, WolfAttack.Phase.INCOMING, "retreating from INCOMING should do nothing")

func test_add_damage_auto_destroys_at_capacity() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.DESTROYER, _rng())  # capacity 2
	attack.phase = WolfAttack.Phase.RANGE_LONG
	attack.add_damage(ship.id, 2)
	assert_true(ship.is_destroyed(), "damage reaching capacity should auto-destroy")
	assert_eq(ship.destroyed_at_phase, WolfShipDefinitions.RangePhase.LONG, "destruction should record the phase it happened in")

func test_add_damage_can_be_undone() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.DESTROYER, _rng())
	attack.phase = WolfAttack.Phase.RANGE_LONG
	attack.add_damage(ship.id, 2)
	assert_true(ship.is_destroyed(), "damage at capacity should have destroyed it")
	attack.add_damage(ship.id, -1)
	assert_true(not ship.is_destroyed(), "undoing damage below capacity should un-destroy it")
	assert_eq(ship.destroyed_at_phase, -1, "un-destroying should clear the recorded destruction phase")

func test_add_damage_refuses_immune_class_this_phase() -> void:
	var attack := WolfAttack.new()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.BATTLESTATION, _rng())
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.add_damage(ship.id, 3)
	assert_eq(ship.damage_taken, 0, "a Battlestation cannot be damaged at Short Range")

func test_boarding_populates_from_surviving_transports() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var transport := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, rng)
	attack.force_target(transport.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.advance_phase()  # -> BOARDING, should populate boarders_by_ship
	assert_eq(attack.boarders_by_ship.get("aegis", 0), 4, "a surviving Assault Transport should contribute 4 boarding parties to its target")

func test_boarding_excludes_destroyed_transports() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var transport := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, rng)
	attack.force_target(transport.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.add_damage(transport.id, 2)  # destroy it (capacity 2)
	attack.advance_phase()  # -> BOARDING
	assert_eq(attack.boarders_by_ship.get("aegis", 0), 0, "a destroyed Assault Transport should not contribute boarders")

func test_decrement_boarders_clamps_at_zero() -> void:
	var attack := WolfAttack.new()
	var transport := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, _rng())
	attack.force_target(transport.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.advance_phase()
	attack.decrement_boarders("aegis", 10)
	assert_eq(attack.boarders_by_ship["aegis"], 0, "decrementing past zero should clamp at zero")

func test_wolf_commander_leading_boarding_adds_two_once() -> void:
	var attack := WolfAttack.new()
	var transport := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, _rng())
	attack.force_target(transport.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.advance_phase()
	attack.lead_boarding_with_commander("aegis")
	assert_eq(attack.boarders_by_ship["aegis"], 6, "4 from the transport plus 2 from the Wolf Commander")
	attack.lead_boarding_with_commander("aegis")
	assert_eq(attack.boarders_by_ship["aegis"], 6, "leading a boarding action should only apply once per attack")

func test_compute_damage_tally_uses_dying_blow_for_ships_destroyed_mid_attack() -> void:
	var attack := WolfAttack.new()
	var cruiser := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	attack.force_target(cruiser.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_MEDIUM
	attack.add_damage(cruiser.id, 3)  # destroys it at Medium (capacity 3)
	var tally: Dictionary = attack.compute_damage_tally()["damage_by_ship"]
	assert_eq(tally.get("aegis", 0), 1, "a Cruiser destroyed at Medium should deal its Medium dying-blow damage (1), not its full 3")

func test_compute_damage_tally_uses_full_damage_for_survivors() -> void:
	var attack := WolfAttack.new()
	var cruiser := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	attack.force_target(cruiser.id, "aegis")
	var tally: Dictionary = attack.compute_damage_tally()["damage_by_ship"]
	assert_eq(tally.get("aegis", 0), 3, "a Cruiser that's still alive should be projected for its full survive-damage (3)")

func test_compute_damage_tally_applies_strikecarrier_bonus_to_surviving_fighter_wings() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var strikecarrier := attack.add_wolf_ship(WolfShipDefinitions.Class.STRIKECARRIER, rng)
	var fighter := attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, rng)
	attack.force_target(strikecarrier.id, "dione")
	attack.force_target(fighter.id, "aegis")

	var tally: Dictionary = attack.compute_damage_tally()["damage_by_ship"]
	# Fighter Wing alone deals 1; +1 from the surviving Strikecarrier = 2.
	assert_eq(tally.get("aegis", 0), 2, "a surviving Strikecarrier should add +1 to each surviving Fighter Wing's damage")

func test_compute_damage_tally_no_strikecarrier_bonus_if_it_was_destroyed() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var strikecarrier := attack.add_wolf_ship(WolfShipDefinitions.Class.STRIKECARRIER, rng)
	var fighter := attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, rng)
	attack.force_target(strikecarrier.id, "dione")
	attack.force_target(fighter.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_LONG
	attack.add_damage(strikecarrier.id, 5)  # destroy it (capacity 5)

	var tally: Dictionary = attack.compute_damage_tally()["damage_by_ship"]
	assert_eq(tally.get("aegis", 0), 1, "no bonus once the Strikecarrier granting it is destroyed")

func test_compute_damage_tally_tracks_returning_classes() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var battlestation := attack.add_wolf_ship(WolfShipDefinitions.Class.BATTLESTATION, rng)
	attack.force_target(battlestation.id, "aegis")
	var result: Dictionary = attack.compute_damage_tally()
	var returning: Dictionary = result["returning_counts"]
	assert_eq(returning.get(WolfShipDefinitions.Class.BATTLESTATION, 0), 1, "a surviving Battlestation should be counted as returning")

func test_live_fighter_wing_count_excludes_destroyed() -> void:
	var attack := WolfAttack.new()
	var rng := _rng()
	var a := attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, rng)
	attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, rng)
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.add_damage(a.id, 1)  # destroy it (capacity 1)
	assert_eq(attack.live_fighter_wing_count(), 1, "a destroyed fighter wing should not count as live")

func test_round_trips_through_dict() -> void:
	var attack := WolfAttack.new(3, 2)
	var rng := _rng()
	var cruiser := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, rng)
	attack.force_target(cruiser.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_MEDIUM
	attack.add_damage(cruiser.id, 1)
	attack.boarders_by_ship["dione"] = 4
	attack.wolf_commander_leading_boarding = true
	attack.wolf_commander_leading_boarding_ship_id = "dione"

	var loaded := WolfAttack.from_dict(attack.to_dict())

	assert_eq(loaded.turn_number, 3, "turn_number should round-trip")
	assert_eq(loaded.round_number, 2, "round_number should round-trip")
	assert_eq(loaded.phase, WolfAttack.Phase.RANGE_MEDIUM, "phase should round-trip")
	assert_true(loaded.wolf_ships.has(cruiser.id), "wolf ships should round-trip")
	assert_eq(loaded.wolf_ships[cruiser.id].damage_taken, 1, "wolf ship damage should round-trip")
	assert_eq(loaded.boarders_by_ship.get("dione", 0), 4, "boarders_by_ship should round-trip")
	assert_true(loaded.wolf_commander_leading_boarding, "wolf_commander_leading_boarding should round-trip")

	# Adding another ship after loading should continue the id
	# sequence rather than colliding with the restored ship.
	var second := loaded.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, rng)
	assert_true(second.id != cruiser.id, "ids generated after a reload must not collide with restored ones")

func test_rehydrated_wolf_ship_mutations_still_bubble_to_changed() -> void:
	var attack := WolfAttack.new()
	var cruiser := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, _rng())
	var loaded := WolfAttack.from_dict(attack.to_dict())
	var count: Array[int] = [0]
	loaded.changed.connect(func() -> void: count[0] += 1)

	loaded.get_wolf_ship(cruiser.id).set_damage(1)

	assert_true(count[0] > 0, "mutating a rehydrated wolf ship should still reach WolfAttack.changed")
