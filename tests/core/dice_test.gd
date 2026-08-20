extends TestCase

## Covers docs/dice_engine_spec.md §9's testing checklist for the
## primitive: determinism, serialise/restore continuity, uniformity,
## band boundaries, count_successes edges.

func test_roll_returns_n_faces_all_within_1_to_6() -> void:
	var dice := Dice.new(1)
	var faces := dice.roll(20)
	assert_eq(faces.size(), 20, "should return exactly n faces")
	for face in faces:
		assert_true(face >= 1 and face <= 6, "every face should be a valid d6 value")

func test_fixed_seed_produces_identical_sequence() -> void:
	var a := Dice.new(12345)
	var b := Dice.new(12345)
	for i in 50:
		assert_eq(a.roll(1)[0], b.roll(1)[0], "same-seeded dice should roll identically at step %d" % i)

func test_serialise_restore_continues_the_same_stream() -> void:
	var a := Dice.new(777)
	for i in 10:
		a.roll(1)
	var snapshot := a.serialise()

	var expected := Dice.new(0)
	expected.restore(snapshot)
	var expected_next := expected.roll(5)

	var restored := Dice.new(0)
	restored.restore(snapshot)
	var restored_next := restored.roll(5)

	assert_eq(restored_next, expected_next, "restoring the same snapshot twice should continue identically")

	# The real regression this guards: restoring must NOT replay from
	# the seed's start - a's own next roll (continuing live, no
	# restore) must match a fresh restore from the snapshot taken right
	# before it.
	var a_next := a.roll(5)
	assert_eq(restored_next, a_next, "restore() should resume the stream, not restart it from the seed")

func test_uniformity_smoke_test() -> void:
	# Not a serious RNG audit (spec §9's own words) - just a guard
	# against a broken range (e.g. 0-5 instead of 1-6, or a biased
	# modulo). 60,000 rolls, each face within 10% of the expected 10,000.
	var dice := Dice.new(42)
	var counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	for face in dice.roll(60000):
		counts[face] += 1
	for face in counts:
		assert_true(absi(counts[face] - 10000) < 1000, "face %d landed %d times, expected ~10000" % [face, counts[face]])

func test_sum_band_boundaries() -> void:
	var thresholds: PackedInt32Array = [12, 20]
	assert_eq(Dice.classify_sum_band([5, 5], 1, thresholds)["band"], 0, "total 11 should land in band 0 (under 12)")
	assert_eq(Dice.classify_sum_band([6, 5], 1, thresholds)["band"], 1, "total 12 should land in band 1, not band 0")
	assert_eq(Dice.classify_sum_band([6, 6], 7, thresholds)["band"], 1, "total 19 should land in band 1 (under 20)")
	assert_eq(Dice.classify_sum_band([6, 6], 8, thresholds)["band"], 2, "total 20 should land in band 2 (meets the last threshold)")

func test_sum_band_reports_faces_modifier_and_total() -> void:
	var result := Dice.classify_sum_band([3, 5], 2, [12, 20])
	assert_eq(result["faces"], PackedInt32Array([3, 5]), "faces should be reported verbatim")
	assert_eq(result["modifier"], 2, "modifier should be reported verbatim")
	assert_eq(result["total"], 10, "total should be faces summed plus modifier")

func test_count_successes_target_4() -> void:
	var all_fail := Dice.classify_count_successes([1, 2, 3, 3], 4)
	assert_eq(all_fail["successes"], 0, "no face >= 4 should mean zero successes")
	var mixed := Dice.classify_count_successes([1, 4, 5, 3], 4)
	assert_eq(mixed["successes"], 2, "exactly the faces >= 4 should count")
	var all_hit := Dice.classify_count_successes([4, 5, 6, 4], 4)
	assert_eq(all_hit["successes"], 4, "every face >= 4 should count")

func test_count_successes_target_5() -> void:
	var all_fail := Dice.classify_count_successes([1, 2, 3, 4], 5)
	assert_eq(all_fail["successes"], 0, "no face >= 5 should mean zero successes")
	var all_hit := Dice.classify_count_successes([5, 6, 5, 6], 5)
	assert_eq(all_hit["successes"], 4, "every face >= 5 should count")
	assert_eq(all_hit["target"], 5, "target should be reported verbatim")
