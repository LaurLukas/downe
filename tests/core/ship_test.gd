extends TestCase

func test_ship_with_no_consoles_is_not_damaged() -> void:
	var ship := Ship.new("aegis")
	assert_true(not ship.is_damaged(), "a ship with no consoles at all should not read as damaged")

func test_ship_with_only_ok_consoles_is_not_damaged() -> void:
	var ship := Ship.new("aegis")
	ship.add_console("engines")
	ship.add_console("shields")
	assert_true(not ship.is_damaged(), "a ship whose consoles are all OK should not read as damaged")

func test_ship_with_a_damaged_console_is_damaged() -> void:
	var ship := Ship.new("aegis")
	ship.add_console("engines")
	ship.get_console("engines").damage()
	assert_true(ship.is_damaged(), "a ship with one DAMAGED console should read as damaged")

func test_ship_with_a_destroyed_console_is_damaged() -> void:
	var ship := Ship.new("aegis")
	ship.add_console("engines")
	ship.get_console("engines").destroy()
	assert_true(ship.is_damaged(), "a ship with one DESTROYED console should also read as damaged")

func test_repairing_the_only_damaged_console_clears_damaged() -> void:
	var ship := Ship.new("aegis")
	ship.add_console("engines")
	ship.get_console("engines").damage()
	ship.get_console("engines").repair()
	assert_true(not ship.is_damaged(), "repairing the one damaged console should clear the damaged flag")
