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

func test_resource_summary_lists_every_kind() -> void:
	var stock := ResourceStock.new()
	stock.set_amount(ResourceStock.Kind.FOOD, 8)
	stock.set_amount(ResourceStock.Kind.STRYTIUM_FUEL, 4)
	assert_eq(DisplayFormat.resource_summary(stock), "Ore 0 | Fuel 4 | Food 8 | Water 0 | Materials 0 | Security 0", "resource_summary should list every kind in a fixed order")

func test_ship_status_line_shows_uncharged_and_no_coordinates() -> void:
	var ship := Ship.new("aegis")
	assert_eq(DisplayFormat.ship_status_line(ship), "Drive: uncharged | Jump: (none) | Unrest: 0 | Ore 0 | Fuel 0 | Food 0 | Water 0 | Materials 0 | Security 0", "a fresh ship should show uncharged and (none) for jump coordinates")

func test_ship_status_line_shows_charged_and_coordinates() -> void:
	var ship := Ship.new("aegis")
	ship.set_drive_charged(true)
	ship.set_jump_coordinates("3,7,2")
	ship.set_unrest(4)
	assert_eq(DisplayFormat.ship_status_line(ship), "Drive: charged | Jump: 3,7,2 | Unrest: 4 | Ore 0 | Fuel 0 | Food 0 | Water 0 | Materials 0 | Security 0", "ship_status_line should reflect drive charge, coordinates, and unrest")

func test_announcement_line_formats_a_jump_report() -> void:
	var entry := {"kind": "jump", "source_id": "aegis", "text": "3,7,2", "turn_number": 2}
	assert_eq(DisplayFormat.announcement_line(entry), "Turn 2 - Jump coordinates (AEGIS): 3,7,2", "a jump announcement should show the ship's display name")

func test_announcement_line_formats_a_scout_report() -> void:
	var entry := {"kind": "scout", "source_id": "philia", "text": "nothing but rock", "turn_number": 1}
	assert_eq(DisplayFormat.announcement_line(entry), "Turn 1 - Scout report (F.S. \"Philia\"): nothing but rock", "a scout announcement should show the craft's display name")
