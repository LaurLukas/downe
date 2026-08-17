extends TestCase

## The security boundary here (wolf_attack_tv_display.md §2/§6) is the
## most important thing this class does: while a Wolf Attack is in its
## INCOMING phase, every ship's pre-rolled target must be genuinely
## absent from the built view, not present-but-hidden. These tests
## check the actual dict shape, not just what a renderer would choose
## to draw.

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng

func _build_state() -> GameState:
	var state := FleetSetup.build_starting_fleet()
	CraftSetup.populate_starting_craft(state)
	return state

func test_build_returns_empty_dict_with_no_active_attack() -> void:
	var state := _build_state()
	assert_eq(WolfAttackView.build(state), {}, "build() with no active wolf_attack should return an empty dict")

func test_incoming_phase_omits_target_key_entirely() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)

	var view := WolfAttackView.build(state)

	for wolf_ship: Dictionary in view["wolf_ships"]:
		assert_true(not wolf_ship.has("target"), "the 'target' key must be entirely absent during INCOMING, not present as null - a leak here is a leaked traitor mechanic")

func test_targeting_phase_reveals_targets() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)
	attack.advance_phase()  # -> TARGETING

	var view := WolfAttackView.build(state)

	var found := false
	for wolf_ship: Dictionary in view["wolf_ships"]:
		if wolf_ship["id"] == ship.id:
			assert_true(wolf_ship.has("target"), "target should be present once past INCOMING")
			assert_eq(wolf_ship["target"], ship.target_ship_id(), "the revealed target should match the pre-rolled one")
			found = true
	assert_true(found, "the added ship should appear in the view")

func test_to_public_dict_never_leaks_targets_during_incoming() -> void:
	# The same boundary, checked at the actual network-broadcast path -
	# see GameState.to_public_dict()'s comment on why raw
	# WolfAttack.to_dict() (which always has every target_die) must
	# never be what gets sent there.
	var state := _build_state()
	var attack := state.start_wolf_attack()
	attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)

	var public_dict := state.to_public_dict()

	assert_true(public_dict.has("wolf_attack"), "the public dict should still mention the attack is happening")
	for wolf_ship: Dictionary in public_dict["wolf_attack"]["wolf_ships"]:
		assert_true(not wolf_ship.has("target"), "to_public_dict() must never leak a pre-reveal target, even indirectly")
		assert_true(not wolf_ship.has("target_die"), "to_public_dict() must never include the raw target_die field at all")

func test_to_dict_persistence_keeps_the_raw_target_die() -> void:
	# Unlike to_public_dict(), the host-local save file needs the true
	# pre-rolled value to survive a crash-recovery restart without
	# re-rolling (which would silently change targets the host already
	# announced/laid cards out for).
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)

	var saved := state.to_dict()

	assert_eq(saved["wolf_attack"]["wolf_ships"][ship.id]["target_die"], ship.target_die, "the save file should keep the true pre-rolled target die")

func test_battlestation_shows_zero_prevents_at_long() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.BATTLESTATION, state.rng)
	attack.advance_phase()  # TARGETING
	attack.advance_phase()  # RANGE_LONG

	var view := WolfAttackView.build(state)
	var entry := _find_wolf_ship(view, ship.id)
	assert_eq(entry["prevents"], 0, "a Battlestation's prevents should be 0 at Long Range")

func test_battlestation_shows_immune_at_short() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.BATTLESTATION, state.rng)
	attack.phase = WolfAttack.Phase.RANGE_SHORT

	var view := WolfAttackView.build(state)
	var entry := _find_wolf_ship(view, ship.id)
	assert_true(entry["immune_this_phase"], "a Battlestation should be flagged immune at Short Range")
	assert_eq(entry["prevents"], null, "prevents should be null (not shown) while immune")

func test_assault_transport_shows_boarders_instead_of_prevents() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var ship := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, state.rng)
	attack.phase = WolfAttack.Phase.RANGE_MEDIUM

	var view := WolfAttackView.build(state)
	var entry := _find_wolf_ship(view, ship.id)
	assert_eq(entry["prevents"], null, "Assault Transports don't have a prevents number")
	assert_eq(entry["boarders"], 4, "Assault Transports should show their projected boarding parties instead")

func test_strikecarrier_prevents_is_live_fighter_wing_count() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var strikecarrier := attack.add_wolf_ship(WolfShipDefinitions.Class.STRIKECARRIER, state.rng)
	attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, state.rng)
	attack.add_wolf_ship(WolfShipDefinitions.Class.FIGHTER_WING, state.rng)
	attack.phase = WolfAttack.Phase.RANGE_MEDIUM

	var view := WolfAttackView.build(state)
	var entry := _find_wolf_ship(view, strikecarrier.id)
	assert_eq(entry["prevents"], 2, "a Strikecarrier's prevents should equal the current live fighter wing count")

func test_fleet_ships_cover_all_six_core_ships() -> void:
	var state := _build_state()
	state.start_wolf_attack()
	var view := WolfAttackView.build(state)
	assert_eq(view["fleet_ships"].size(), 6, "the view should include all six core ships")

func test_fleet_ship_critical_flag_when_boarders_exceed_security_teams() -> void:
	var state := _build_state()
	state.get_ship("aegis").resources.set_amount(ResourceStock.Kind.SECURITY_TEAMS, 2)
	var attack := state.start_wolf_attack()
	var transport := attack.add_wolf_ship(WolfShipDefinitions.Class.ASSAULT_TRANSPORT, state.rng)
	attack.force_target(transport.id, "aegis")
	attack.phase = WolfAttack.Phase.RANGE_SHORT
	attack.advance_phase()  # -> BOARDING, boarders_by_ship["aegis"] = 4

	var view := WolfAttackView.build(state)
	var aegis_entry: Dictionary = {}
	for fleet_ship: Dictionary in view["fleet_ships"]:
		if fleet_ship["id"] == "aegis":
			aegis_entry = fleet_ship
	assert_true(aegis_entry["critical"], "4 boarders against 2 security teams should be flagged critical")

func test_resolution_phase_moves_damage_from_incoming_to_this_attack() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	var cruiser := attack.add_wolf_ship(WolfShipDefinitions.Class.CRUISER, state.rng)
	attack.force_target(cruiser.id, "aegis")
	attack.phase = WolfAttack.Phase.RESOLUTION

	var view := WolfAttackView.build(state)
	var aegis_entry: Dictionary = {}
	for fleet_ship: Dictionary in view["fleet_ships"]:
		if fleet_ship["id"] == "aegis":
			aegis_entry = fleet_ship
	assert_eq(aegis_entry["incoming_damage"], 0, "nothing should be 'incoming' once resolution has happened")
	assert_eq(aegis_entry["damage_this_attack"], 3, "the final damage should be reflected in damage_this_attack")

func test_returning_lists_surviving_battlestations() -> void:
	var state := _build_state()
	var attack := state.start_wolf_attack()
	attack.add_wolf_ship(WolfShipDefinitions.Class.BATTLESTATION, state.rng)
	attack.phase = WolfAttack.Phase.RESOLUTION

	var view := WolfAttackView.build(state)

	assert_eq(view["returning"].size(), 1, "a surviving Battlestation should appear in returning")
	assert_eq(view["returning"][0]["class"], "battlestation", "the returning entry should identify the class")
	assert_eq(view["returning"][0]["count"], 1, "the returning entry should count how many")

func _find_wolf_ship(view: Dictionary, id: String) -> Dictionary:
	for wolf_ship: Dictionary in view["wolf_ships"]:
		if wolf_ship["id"] == id:
			return wolf_ship
	return {}
