extends TestCase

func test_add_prepends_newest_first() -> void:
	var log := AnnouncementLog.new()
	log.add("jump", "aegis", "1,2,3", 1)
	log.add("jump", "aegis", "4,5,6", 2)
	assert_eq(log.entries[0]["text"], "4,5,6", "the most recent entry should be first")
	assert_eq(log.entries[1]["text"], "1,2,3", "older entries should follow")

func test_caps_at_max_entries() -> void:
	var log := AnnouncementLog.new()
	for i in range(AnnouncementLog.MAX_ENTRIES + 5):
		log.add("scout", "philia", "report %d" % i, 1)
	assert_eq(log.entries.size(), AnnouncementLog.MAX_ENTRIES, "the log should not grow past MAX_ENTRIES")
	assert_eq(log.entries[0]["text"], "report %d" % (AnnouncementLog.MAX_ENTRIES + 4), "the newest entry should survive capping")

func test_add_emits_entry_added() -> void:
	var log := AnnouncementLog.new()
	var received: Array[Dictionary] = []
	log.entry_added.connect(func(entry: Dictionary) -> void: received.append(entry))
	log.add("jump", "quellon", "7,8,9", 3)
	assert_eq(received.size(), 1, "adding an entry should emit entry_added")
	assert_eq(received[0]["source_id"], "quellon", "the emitted entry should match what was added")

func test_round_trips_through_dict() -> void:
	var log := AnnouncementLog.new()
	log.add("jump", "aegis", "1,2,3", 1)
	log.add("scout", "philia", "nothing but rock", 2)

	var loaded := AnnouncementLog.new()
	loaded.load_from_dict(log.to_dict())

	assert_eq(loaded.entries.size(), 2, "entries should round-trip")
	assert_eq(loaded.entries[0]["text"], "nothing but rock", "entry order should round-trip")

func test_game_state_logs_jump_coordinates() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("aegis"))
	state.get_ship("aegis").set_jump_coordinates("3,7,2")
	assert_eq(state.announcement_log.entries.size(), 1, "setting jump coordinates on a ship should log an announcement")
	assert_eq(state.announcement_log.entries[0]["kind"], "jump", "the announcement should be tagged as a jump report")
	assert_eq(state.announcement_log.entries[0]["source_id"], "aegis", "the announcement should record which ship reported")

func test_game_state_logs_scout_reports() -> void:
	var state := GameState.new()
	state.add_craft(CraftState.new("philia", "shepherd"))
	state.get_craft("philia").set_scout_report("nothing but rock")
	assert_eq(state.announcement_log.entries.size(), 1, "setting a scout report should log an announcement")
	assert_eq(state.announcement_log.entries[0]["kind"], "scout", "the announcement should be tagged as a scout report")
	assert_eq(state.announcement_log.entries[0]["source_id"], "philia", "the announcement should record which craft reported")

func test_game_state_does_not_log_anything_on_startup() -> void:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	assert_eq(state.announcement_log.entries.size(), 0, "building a starting fleet should not log any announcements - fields are set directly, not via the setters that log")
