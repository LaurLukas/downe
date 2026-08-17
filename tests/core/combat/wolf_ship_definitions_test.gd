extends TestCase

## Cross-checks the derived PREVENTS numbers against
## wolf_attack_tv_display.md §5.3's own table, which was built
## independently from open_questions_answered.md §3.1's raw damage
## table. Both sources agreeing is what makes these numbers trustworthy
## rather than guessed.

func _prevents(cls: WolfShipDefinitions.Class, phase: WolfShipDefinitions.RangePhase) -> int:
	return WolfShipDefinitions.damage_if_survives(cls) - WolfShipDefinitions.damage_if_destroyed_at(cls, phase)

func test_battlestation_prevents_nothing_at_long_or_medium() -> void:
	assert_eq(_prevents(WolfShipDefinitions.Class.BATTLESTATION, WolfShipDefinitions.RangePhase.LONG), 0, "Battlestation deals 3 either way - killing it early prevents nothing, only its return")
	assert_eq(_prevents(WolfShipDefinitions.Class.BATTLESTATION, WolfShipDefinitions.RangePhase.MEDIUM), 0, "same at Medium")

func test_battlestation_immune_at_short() -> void:
	assert_true(WolfShipDefinitions.is_immune_at(WolfShipDefinitions.Class.BATTLESTATION, WolfShipDefinitions.RangePhase.SHORT), "Battlestation cannot be damaged at Short Range")
	assert_true(not WolfShipDefinitions.is_immune_at(WolfShipDefinitions.Class.BATTLESTATION, WolfShipDefinitions.RangePhase.LONG), "Battlestation is damageable at Long Range")

func test_battlestation_returns_if_survives() -> void:
	assert_true(WolfShipDefinitions.returns_if_survives(WolfShipDefinitions.Class.BATTLESTATION), "a surviving Battlestation returns next attack")

func test_cruiser_prevents_table() -> void:
	assert_eq(_prevents(WolfShipDefinitions.Class.CRUISER, WolfShipDefinitions.RangePhase.LONG), 3, "Cruiser: full capacity saved by an early kill")
	assert_eq(_prevents(WolfShipDefinitions.Class.CRUISER, WolfShipDefinitions.RangePhase.MEDIUM), 2, "Cruiser at Medium")
	assert_eq(_prevents(WolfShipDefinitions.Class.CRUISER, WolfShipDefinitions.RangePhase.SHORT), 1, "Cruiser at Short")

func test_destroyer_prevents_table() -> void:
	assert_eq(_prevents(WolfShipDefinitions.Class.DESTROYER, WolfShipDefinitions.RangePhase.LONG), 1, "Destroyer at Long")
	assert_eq(_prevents(WolfShipDefinitions.Class.DESTROYER, WolfShipDefinitions.RangePhase.MEDIUM), 1, "Destroyer at Medium")
	assert_eq(_prevents(WolfShipDefinitions.Class.DESTROYER, WolfShipDefinitions.RangePhase.SHORT), 1, "Destroyer at Short")

func test_fighter_wing_prevents_table() -> void:
	assert_eq(_prevents(WolfShipDefinitions.Class.FIGHTER_WING, WolfShipDefinitions.RangePhase.LONG), 1, "Fighter Wing at Long")
	assert_eq(_prevents(WolfShipDefinitions.Class.FIGHTER_WING, WolfShipDefinitions.RangePhase.MEDIUM), 1, "Fighter Wing at Medium")
	assert_eq(_prevents(WolfShipDefinitions.Class.FIGHTER_WING, WolfShipDefinitions.RangePhase.SHORT), 0, "killing a Fighter Wing at Short only stops the hit it would deal that same phase")
	assert_true(WolfShipDefinitions.returns_if_survives(WolfShipDefinitions.Class.FIGHTER_WING), "a surviving Fighter Wing returns next attack")

func test_strikecarrier_deals_same_damage_regardless_of_when_destroyed() -> void:
	# Its PREVENTS value isn't this flat number at all - it's the live
	# fighter wing count (WolfAttack.live_fighter_wing_count()), per
	# the secondary "+1 per surviving fighter wing" effect. Confirmed
	# here so a future edit to the base numbers can't silently make
	# the flat prevents calculation look meaningful again.
	assert_eq(_prevents(WolfShipDefinitions.Class.STRIKECARRIER, WolfShipDefinitions.RangePhase.LONG), 0, "Strikecarrier deals 2 either way by itself")

func test_assault_transport_deals_no_direct_damage() -> void:
	assert_eq(WolfShipDefinitions.damage_if_survives(WolfShipDefinitions.Class.ASSAULT_TRANSPORT), 0, "Assault Transports don't damage ships directly - they contribute boarders")
	assert_eq(WolfShipDefinitions.boarding_parties_if_survives(WolfShipDefinitions.Class.ASSAULT_TRANSPORT), 4, "a surviving Assault Transport contributes 4 boarding parties")

func test_targeting_table_matches_open_questions_answered() -> void:
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[1], "aegis", "1 -> AEGIS")
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[2], "dione", "2 -> Dione")
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[3], "icebreaker", "3 -> Icebreaker")
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[4], "quellon", "4 -> Quellon")
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[5], "shepherd", "5 -> Shepherd")
	assert_eq(WolfShipDefinitions.TARGETING_TABLE[6], "refinery_124", "6 -> Refinery 124")

func test_capacities_match_roster() -> void:
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.BATTLESTATION), 6, "Battlestation capacity")
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.STRIKECARRIER), 5, "Strikecarrier capacity")
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.CRUISER), 3, "Cruiser capacity")
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.DESTROYER), 2, "Destroyer capacity")
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.FIGHTER_WING), 1, "Fighter Wing capacity")
	assert_eq(WolfShipDefinitions.capacity_for(WolfShipDefinitions.Class.ASSAULT_TRANSPORT), 2, "Assault Transport capacity")
