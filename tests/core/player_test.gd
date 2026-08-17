extends TestCase

func test_set_suspicion_clamps_at_zero() -> void:
	var player := Player.new("p1", "Alex")
	player.set_suspicion(-5)
	assert_eq(player.suspicion, 0, "suspicion should never go negative")

func test_add_suspicion_accumulates() -> void:
	var player := Player.new("p1", "Alex")
	player.set_suspicion(5)
	player.add_suspicion(3)
	assert_eq(player.suspicion, 8, "add_suspicion should add to the current value")

func test_add_clue_appends_and_emits() -> void:
	var player := Player.new("p1", "Alex")
	var received: Array[Dictionary] = []
	player.clue_added.connect(func(entry: Dictionary) -> void: received.append(entry))

	player.add_clue("Someone's been asking odd questions about the reactor.", 3)

	assert_eq(player.clues.size(), 1, "add_clue should append to the clue list")
	assert_eq(player.clues[0]["text"], "Someone's been asking odd questions about the reactor.", "the stored clue should match what was sent")
	assert_eq(received.size(), 1, "add_clue should emit clue_added")

func test_suspicion_and_clue_changes_bubble_to_changed() -> void:
	# GDScript lambdas capture local variables by value, not by
	# reference - use a 1-element array as the counter so the
	# increment is visible outside the closure.
	var player := Player.new("p1", "Alex")
	var count: Array[int] = [0]
	player.changed.connect(func() -> void: count[0] += 1)
	player.set_suspicion(4)
	player.add_clue("hint", 1)
	assert_eq(count[0], 2, "both suspicion changes and clues added should bubble to changed")

func test_round_trips_through_dict() -> void:
	var player := Player.new("p1", "Alex")
	player.set_suspicion(7)
	player.add_clue("hint", 2)

	var loaded := Player.from_dict(player.to_dict())

	assert_eq(loaded.id, "p1", "id should round-trip")
	assert_eq(loaded.name, "Alex", "name should round-trip")
	assert_eq(loaded.suspicion, 7, "suspicion should round-trip")
	assert_eq(loaded.clues.size(), 1, "clues should round-trip")
	assert_eq(loaded.clues[0]["text"], "hint", "clue text should round-trip")

## FG's formula: 6 including the accuser, minus 1 per 5 suspicion on
## the target, plus 1 per stander. See open_questions_answered.md §4.3.
func test_posse_size_at_zero_suspicion() -> void:
	assert_eq(Player.posse_size_required(0, 0), 6, "zero suspicion, no standers, should need the full 6")

func test_posse_size_drops_per_five_suspicion() -> void:
	assert_eq(Player.posse_size_required(5, 0), 5, "5 suspicion should reduce the requirement by 1")
	assert_eq(Player.posse_size_required(9, 0), 5, "suspicion under the next multiple of 5 should not reduce further")
	assert_eq(Player.posse_size_required(10, 0), 4, "10 suspicion should reduce the requirement by 2")

func test_posse_size_rises_per_stander() -> void:
	assert_eq(Player.posse_size_required(0, 3), 9, "each stander should raise the requirement by 1")

func test_posse_size_never_drops_below_one() -> void:
	assert_eq(Player.posse_size_required(100, 0), 1, "posse size should never drop below 1 no matter how high suspicion is")
