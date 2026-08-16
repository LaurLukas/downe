extends TestCase

func test_rise_increments_value() -> void:
	var track := PursuitTrack.new()
	track.rise()
	assert_eq(track.value, 1, "rise() should increment by 1 by default")

func test_clamps_to_max() -> void:
	var track := PursuitTrack.new()
	track.rise(50)
	assert_eq(track.value, PursuitTrack.MAX_VALUE, "value should clamp to MAX_VALUE")

func test_clamps_to_min() -> void:
	var track := PursuitTrack.new()
	track.fall(50)
	assert_eq(track.value, PursuitTrack.MIN_VALUE, "value should clamp to MIN_VALUE")

func test_reached_max_signal_fires_at_max() -> void:
	var track := PursuitTrack.new()
	# GDScript lambdas capture outer locals by value, not reference, so a
	# plain bool reassigned inside the lambda would never be seen out here.
	# Wrap it in an Array so the lambda mutates the referenced object instead.
	var fired := [false]
	track.reached_max.connect(func() -> void: fired[0] = true)
	track.set_value(PursuitTrack.MAX_VALUE)
	assert_true(fired[0], "reached_max should fire when value hits MAX_VALUE")

func test_host_can_force_any_value_within_range() -> void:
	var track := PursuitTrack.new()
	track.set_value(4)
	assert_eq(track.value, 4, "host should be able to set the track directly")
