extends TestCase

func test_starts_with_no_steps_complete() -> void:
	var ship := Ship.new("aegis")
	assert_true(not ship.is_maintenance_step_complete(MaintenanceCycle.Step.STORAGE), "should start with nothing marked")

func test_mark_maintenance_step_complete() -> void:
	var ship := Ship.new("aegis")
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.RATIONS)
	assert_true(ship.is_maintenance_step_complete(MaintenanceCycle.Step.RATIONS), "should be marked complete")
	assert_true(not ship.is_maintenance_step_complete(MaintenanceCycle.Step.STORAGE), "marking one step should not mark others")

func test_marking_the_same_step_twice_does_not_duplicate() -> void:
	var ship := Ship.new("aegis")
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
	assert_eq(ship.completed_maintenance_steps.size(), 1, "marking the same step twice should not duplicate it")

func test_clear_maintenance_steps() -> void:
	var ship := Ship.new("aegis")
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
	ship.clear_maintenance_steps()
	assert_true(not ship.is_maintenance_step_complete(MaintenanceCycle.Step.STORAGE), "clearing should reset the checklist")

func test_marking_a_step_bubbles_to_changed() -> void:
	var ship := Ship.new("aegis")
	var count: Array[int] = [0]
	ship.changed.connect(func() -> void: count[0] += 1)
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
	assert_true(count[0] > 0, "marking a step complete should bubble to changed")

func test_round_trips_through_dict() -> void:
	var ship := Ship.new("aegis")
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.STORAGE)
	ship.mark_maintenance_step_complete(MaintenanceCycle.Step.RATIONS)

	var loaded := Ship.from_dict(ship.to_dict())

	assert_true(loaded.is_maintenance_step_complete(MaintenanceCycle.Step.STORAGE), "completed steps should round-trip")
	assert_true(loaded.is_maintenance_step_complete(MaintenanceCycle.Step.RATIONS), "completed steps should round-trip")
	assert_true(not loaded.is_maintenance_step_complete(MaintenanceCycle.Step.REACTOR), "uncompleted steps should stay uncompleted")
