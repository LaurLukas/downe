extends TestCase

func test_maintenance_unrest_describes_gain_from_band() -> void:
	# Reads the generic "band" field, not a caller-stamped "unrest_gain" -
	# see RollText's own comment on why: an overridden roll's recomputed
	# dict only ever has band, never a reason-specific extra.
	assert_eq(RollText.describe({"reason": "maintenance_unrest", "band": 0}), "+2 unrest", "band 0 (under 12) should describe a +2 gain")
	assert_eq(RollText.describe({"reason": "maintenance_unrest", "band": 1}), "+1 unrest", "band 1 (12-19) should describe a +1 gain")
	assert_eq(RollText.describe({"reason": "maintenance_unrest", "band": 2}), "no unrest gained", "band 2 (20+) should say no gain")

func test_maintenance_riot_describes_hit_or_miss() -> void:
	assert_eq(RollText.describe({"reason": "maintenance_riot", "damaged": true}), "riot - draw a card and mark that console damaged", "a hit should tell the host what to do next")
	assert_eq(RollText.describe({"reason": "maintenance_riot", "damaged": false}), "no riot damage", "a miss should say so plainly")

func test_weapon_fire_describes_hit_count_with_correct_pluralization() -> void:
	# Reads "successes" (always present for a count_successes-shaped
	# roll, rolled or overridden), not a caller-stamped "hits" extra.
	assert_eq(RollText.describe({"reason": "weapon_fire", "successes": 0}), "0 hits", "zero hits should pluralize")
	assert_eq(RollText.describe({"reason": "weapon_fire", "successes": 1}), "1 hit", "exactly one hit should not pluralize")
	assert_eq(RollText.describe({"reason": "weapon_fire", "successes": 3}), "3 hits", "multiple hits should pluralize")

func test_describes_an_overridden_maintenance_unrest_roll_correctly() -> void:
	# Integration check: override_roll()'s recomputed dict only ever has
	# generic Dice.classify_sum_band() fields (faces/modifier/total/
	# band), never a reason-specific "unrest_gain" - RollText must still
	# describe it correctly from band alone.
	var service := RollService.new(Dice.new(1), RollLog.new())
	var original := service.roll_sum_band("maintenance_unrest", "aegis", 1, 2, 0, [12, 20])
	var overridden := service.override_roll(original["id"], [6, 6])  # total 12 -> band 1
	assert_eq(RollText.describe(overridden), "+1 unrest", "an overridden roll landing in band 1 should describe a +1 gain, same as a fresh roll would")

func test_unknown_reason_returns_empty_string() -> void:
	assert_eq(RollText.describe({"reason": "something_new"}), "", "an unrecognized reason key should not crash, just say nothing")
