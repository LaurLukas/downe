extends TestCase

func test_add_appends_and_emits() -> void:
	var log := RollLog.new()
	var seen: Array[Dictionary] = []
	log.entry_added.connect(func(entry: Dictionary) -> void: seen.append(entry))

	log.add({"id": 1, "faces": [3, 4]})

	assert_eq(log.entries.size(), 1, "add() should append to entries")
	assert_eq(seen.size(), 1, "add() should emit entry_added")

func test_add_does_not_cap_or_reorder() -> void:
	var log := RollLog.new()
	for i in 40:
		log.add({"id": i})
	assert_eq(log.entries.size(), 40, "the audit log must not be capped like AnnouncementLog - it's the whole append-only point")
	assert_eq(log.entries[0]["id"], 0, "entries stay in append order, oldest first")

func test_find_by_id_returns_empty_dict_when_missing() -> void:
	var log := RollLog.new()
	log.add({"id": 1})
	assert_true(log.find_by_id(999).is_empty(), "an id that was never added should resolve to an empty dict")

func test_to_dict_from_dict_round_trip() -> void:
	var log := RollLog.new()
	log.add({"id": 1, "faces": [1, 2]})
	log.add({"id": 2, "faces": [5, 6]})

	var restored := RollLog.new()
	restored.load_from_dict(log.to_dict())

	assert_eq(restored.entries.size(), 2, "round-tripping should preserve every entry")
	assert_eq(restored.entries[1]["id"], 2, "round-tripping should preserve entry order and content")
