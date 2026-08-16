extends TestCase

func test_phase_label_team() -> void:
	assert_eq(DisplayFormat.phase_label(TurnManager.Phase.TEAM), "Team Phase", "TEAM should format as Team Phase")

func test_phase_label_coordination() -> void:
	assert_eq(DisplayFormat.phase_label(TurnManager.Phase.COORDINATION), "Coordination Phase", "COORDINATION should format as Coordination Phase")

func test_turn_label_combines_turn_and_phase() -> void:
	var turn_manager := TurnManager.new()
	assert_eq(DisplayFormat.turn_label(turn_manager), "Turn 1 - Team Phase", "turn_label should combine turn number and phase")

func test_pursuit_bar_empty() -> void:
	var track := PursuitTrack.new()
	assert_eq(DisplayFormat.pursuit_bar(track, 10), "[----------] 0/10", "an empty track should render as all dashes")

func test_pursuit_bar_full() -> void:
	var track := PursuitTrack.new()
	track.set_value(PursuitTrack.MAX_VALUE)
	assert_eq(DisplayFormat.pursuit_bar(track, 10), "[##########] 10/10", "a full track should render as all hashes")

func test_pursuit_bar_half() -> void:
	var track := PursuitTrack.new()
	track.set_value(5)
	assert_eq(DisplayFormat.pursuit_bar(track, 10), "[#####-----] 5/10", "a half-full track should render half hashes")

func test_console_state_label() -> void:
	assert_eq(DisplayFormat.console_state_label(Console.State.OK), "OK", "OK should format as OK")
	assert_eq(DisplayFormat.console_state_label(Console.State.DAMAGED), "DAMAGED", "DAMAGED should format as DAMAGED")
	assert_eq(DisplayFormat.console_state_label(Console.State.DESTROYED), "DESTROYED", "DESTROYED should format as DESTROYED")
