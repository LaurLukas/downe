extends TestCase

## Covers the rules-layer wrapper: stamping, the audit log, and the
## override path from docs/dice_engine_spec.md §7/§9 ("override
## recomputes the outcome and preserves the original log entry").

func _build_service(seed_value: int = 1) -> RollService:
	return RollService.new(Dice.new(seed_value), RollLog.new())

func test_roll_sum_band_stamps_id_reason_ship_turn() -> void:
	var service := _build_service()
	var result := service.roll_sum_band("maintenance_unrest", "aegis", 3, 2, 0, [12, 20])
	assert_eq(result["id"], 1, "the first roll should get sequence id 1")
	assert_eq(result["reason"], "maintenance_unrest", "reason should be stamped verbatim")
	assert_eq(result["ship"], "aegis", "ship should be stamped verbatim")
	assert_eq(result["turn"], 3, "turn should be stamped verbatim")
	assert_true(not result["over"], "a fresh roll should never be marked overridden")

func test_sequence_increments_across_reasons() -> void:
	var service := _build_service()
	var first := service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var second := service.roll_count_successes("weapon_fire", "maliades", 1, 1, 4)
	assert_eq(first["id"], 1, "first roll should be sequence 1")
	assert_eq(second["id"], 2, "second roll should be sequence 2, regardless of shape")
	assert_eq(service.sequence(), 2, "sequence() should reflect the running total")

func test_every_roll_is_appended_to_the_log() -> void:
	var service := _build_service()
	service.roll_raw("maintenance_riot", "dione", 1, 1)
	service.roll_count_successes("weapon_fire", "highwall", 1, 1, 5)
	assert_eq(service.log.entries.size(), 2, "both rolls should land in the audit log")

func test_override_recomputes_from_supplied_faces_without_rerolling() -> void:
	var service := _build_service()
	var original := service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var forced_faces: PackedInt32Array = [6, 6]

	var overridden := service.override_roll(original["id"], forced_faces)

	assert_eq(overridden["faces"], forced_faces, "override should use the host-supplied faces, not roll new ones")
	assert_eq(overridden["total"], 12, "override should recompute the total from the supplied faces")
	assert_eq(overridden["band"], 1, "override should reclassify the band from the recomputed total")
	assert_true(overridden["over"], "an overridden roll should be marked over")
	assert_eq(overridden["id"], original["id"], "override should keep the original roll's id, not mint a new one")

func test_override_preserves_the_original_log_entry() -> void:
	var service := _build_service()
	var original := service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var original_faces: PackedInt32Array = original["faces"]

	service.override_roll(original["id"], [6, 6])

	assert_eq(service.log.entries.size(), 2, "the override should append, never overwrite, the log")
	var stored_original: Dictionary = service.log.entries[0]
	assert_eq(stored_original["faces"], original_faces, "the original log entry's faces must be untouched by a later override")
	assert_true(not stored_original["over"], "the original log entry must never retroactively become marked over")

func test_override_of_count_successes_reclassifies_target() -> void:
	var service := _build_service()
	var original := service.roll_count_successes("weapon_fire", "highwall", 1, 1, 5)

	var overridden := service.override_roll(original["id"], [6])

	assert_eq(overridden["successes"], 1, "a forced 6 should always succeed against target 5")
	assert_eq(overridden["target"], 5, "override should reuse the original target")

func test_augment_runs_before_the_roll_is_logged() -> void:
	# The real bug this guards against: a caller adding game-specific
	# fields (e.g. MaintenanceCycle's "damaged") AFTER roll_sum_band()/
	# roll_raw() returns would be too late - the roll is already
	# logged/broadcast by then. augment() must run first so those
	# fields are present in the log entry itself, not just the
	# caller's local copy.
	var service := _build_service()
	service.roll_raw("maintenance_riot", "aegis", 1, 1, func(result: Dictionary) -> void:
		result["custom_field"] = "present at log time"
	)
	assert_eq(service.log.entries[0]["custom_field"], "present at log time", "augment's additions must already be in the logged entry")

func test_augment_runs_before_the_rolled_signal_fires() -> void:
	var service := _build_service()
	var seen: Array[Dictionary] = []
	service.rolled.connect(func(result: Dictionary) -> void: seen.append(result))

	service.roll_raw("maintenance_riot", "aegis", 1, 1, func(result: Dictionary) -> void:
		result["custom_field"] = "present at broadcast time"
	)

	assert_eq(seen[0]["custom_field"], "present at broadcast time", "augment's additions must already be present when rolled fires, not added afterward")

func test_override_can_also_augment() -> void:
	var service := _build_service()
	var original := service.roll_raw("maintenance_riot", "aegis", 1, 1)

	var overridden := service.override_roll(original["id"], [6], func(result: Dictionary) -> void:
		result["custom_field"] = "recomputed"
	)

	assert_eq(overridden["custom_field"], "recomputed", "override_roll should also support augmenting before it logs/broadcasts")

func test_override_of_unknown_id_returns_empty() -> void:
	var service := _build_service()
	service.roll_raw("maintenance_riot", "dione", 1, 1)
	var result := service.override_roll(999, [1])
	assert_true(result.is_empty(), "overriding a roll id that was never made should be a no-op")

func test_find_by_id_returns_the_oldest_match_even_after_an_override() -> void:
	var service := _build_service()
	var original := service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	service.override_roll(original["id"], [6, 6])
	service.override_roll(original["id"], [1, 1])

	var found := service.log.find_by_id(original["id"])
	assert_eq(found["faces"], original["faces"], "find_by_id should still resolve to the true original, not the latest override")
