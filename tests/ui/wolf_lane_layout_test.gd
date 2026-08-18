extends TestCase

func _wolf(id: String, cls: String, target: String, destroyed: bool = false, extra: Dictionary = {}) -> Dictionary:
	var w := {"id": id, "class": cls, "target": target, "destroyed": destroyed}
	w.merge(extra)
	return w

func test_group_by_lane_creates_empty_lane_for_every_fleet_ship() -> void:
	var lanes := WolfLaneLayout.group_by_lane([], ["aegis", "dione"])
	assert_eq(lanes.keys().size(), 3, "should have a lane per fleet ship plus the staging pool")
	assert_eq((lanes["aegis"] as Array).size(), 0, "an untargeted ship should still get an empty lane")

func test_group_by_lane_routes_wolves_to_their_target() -> void:
	var wolves := [_wolf("w1", "cruiser", "aegis"), _wolf("w2", "destroyer", "dione")]
	var lanes := WolfLaneLayout.group_by_lane(wolves, ["aegis", "dione"])
	assert_eq((lanes["aegis"] as Array).size(), 1, "w1 should route to aegis")
	assert_eq((lanes["dione"] as Array).size(), 1, "w2 should route to dione")

func test_group_by_lane_routes_untargeted_wolves_to_staging_pool() -> void:
	var wolves := [_wolf("w1", "cruiser", "")]
	var lanes := WolfLaneLayout.group_by_lane(wolves, ["aegis"])
	assert_eq((lanes[WolfLaneLayout.STAGING_POOL_KEY] as Array).size(), 1, "an empty target should route to the staging pool")
	assert_eq((lanes["aegis"] as Array).size(), 0, "aegis's lane should stay empty")

func test_order_lane_sorts_live_wolves_by_descending_capacity() -> void:
	var wolves := [_wolf("fw", "fighter_wing", "aegis"), _wolf("bs", "battlestation", "aegis"), _wolf("cr", "cruiser", "aegis")]
	var ordered := WolfLaneLayout.order_lane(wolves)
	assert_eq(ordered[0]["id"], "bs", "battlestation (cap 6) should sort first")
	assert_eq(ordered[1]["id"], "cr", "cruiser (cap 3) should sort second")
	assert_eq(ordered[2]["id"], "fw", "fighter wing (cap 1) should sort last among live wolves")

func test_order_lane_breaks_ties_by_ascending_uid() -> void:
	var wolves := [_wolf("cr_b", "cruiser", "aegis"), _wolf("cr_a", "cruiser", "aegis")]
	var ordered := WolfLaneLayout.order_lane(wolves)
	assert_eq(ordered[0]["id"], "cr_a", "equal capacity should break the tie by ascending uid")
	assert_eq(ordered[1]["id"], "cr_b", "equal capacity should break the tie by ascending uid")

func test_order_lane_sinks_destroyed_wolves_to_the_top() -> void:
	var wolves := [
		_wolf("dead_bs", "battlestation", "aegis", true),
		_wolf("live_fw", "fighter_wing", "aegis", false),
	]
	var ordered := WolfLaneLayout.order_lane(wolves)
	assert_eq(ordered[0]["id"], "live_fw", "the live wolf should be nearest the card (index 0) even though it has less capacity")
	assert_eq(ordered[1]["id"], "dead_bs", "the destroyed wolf should sink to the top of the stack")

func test_order_lane_is_deterministic_across_identical_pushes() -> void:
	var wolves := [_wolf("w2", "cruiser", "aegis"), _wolf("w1", "cruiser", "aegis"), _wolf("w3", "destroyer", "aegis")]
	var first := WolfLaneLayout.order_lane(wolves.duplicate(true))
	var second := WolfLaneLayout.order_lane(wolves.duplicate(true))
	for i in first.size():
		assert_eq(first[i]["id"], second[i]["id"], "identical input should always produce identical order (tokens must not jump)")

func test_max_stack_ignores_the_staging_pool() -> void:
	var lanes := {
		WolfLaneLayout.STAGING_POOL_KEY: [_wolf("a", "cruiser", ""), _wolf("b", "cruiser", ""), _wolf("c", "cruiser", "")],
		"aegis": [_wolf("d", "cruiser", "aegis")],
	}
	assert_eq(WolfLaneLayout.max_stack(lanes), 1, "the staging pool should never inflate max_stack")

func test_tier_boundaries() -> void:
	# Tier A/A2 split (damage ladder redesign, docs/wolf_attack_damage_ladder.md
	# §4 as deviated by its own README, user-confirmed - see TODO.md): full
	# 118px headed tokens only at <=2 per lane, headerless 100px tokens at
	# exactly 3, matching the original (pre-ladder) v3 tier A arithmetic.
	assert_eq(WolfLaneLayout.tier_for(1)["name"], "A", "1 should be tier A (headed)")
	assert_eq(WolfLaneLayout.tier_for(2)["name"], "A", "2 should still be tier A (headed)")
	assert_eq(WolfLaneLayout.tier_for(3)["name"], "A2", "3 should be the headerless A2 tier, not roll over to B")
	assert_true(WolfLaneLayout.tier_for(1)["ladder_headers"], "tier A shows L M S ✕ headers")
	assert_true(not WolfLaneLayout.tier_for(3)["ladder_headers"], "tier A2 has no headers")
	assert_eq(WolfLaneLayout.tier_for(1)["height"], 118.0, "tier A tokens are 118px to fit the header row")
	assert_eq(WolfLaneLayout.tier_for(3)["height"], 100.0, "tier A2 tokens stay 100px, unchanged from pre-ladder v3")
	assert_eq(WolfLaneLayout.tier_for(4)["name"], "B", "4 should roll over into tier B")
	assert_eq(WolfLaneLayout.tier_for(8)["name"], "B", "8 should still be tier B")
	assert_eq(WolfLaneLayout.tier_for(9)["name"], "C", "9 should roll over into tier C")
	assert_eq(WolfLaneLayout.tier_for(16)["name"], "C", "16 should still be tier C")
	assert_eq(WolfLaneLayout.tier_for(17)["name"], "D", "17 should roll over into tier D")
	assert_eq(WolfLaneLayout.tier_for(24)["name"], "D", "24 should still be tier D")
	assert_eq(WolfLaneLayout.tier_for(25)["name"], "D+", "25 should roll over into the overflow tier")
	assert_eq(WolfLaneLayout.tier_for(100)["name"], "D+", "very high counts should stay in the overflow tier")

func test_tier_applies_uniformly_from_the_busiest_lane() -> void:
	# A 30-wolf attack concentrated on one ship still selects the D+
	# overflow tier globally - every lane uses the same token size.
	var lanes := {
		"aegis": range(30).map(func(i): return _wolf("w%d" % i, "fighter_wing", "aegis")),
		"dione": [_wolf("only", "cruiser", "dione")],
	}
	assert_eq(WolfLaneLayout.tier_for(WolfLaneLayout.max_stack(lanes))["name"], "D+", "tier is chosen from the busiest lane, not per-lane")

func test_lane_width_formula_for_six_lanes() -> void:
	var width := WolfLaneLayout.lane_width_for(6)
	assert_true(is_equal_approx(width, (1730.0 - 5.0 * 18.0) / 6.0), "lane_width should follow the spec's own formula exactly")

func test_lane_width_capped_and_would_be_centred_at_four_lanes() -> void:
	var uncapped := (1730.0 - 3.0 * 18.0) / 4.0
	assert_true(uncapped > 380.0, "sanity check: 4-lane uncapped width should exceed the 380 cap")
	assert_eq(WolfLaneLayout.lane_width_for(4), 380.0, "4 lanes should cap at 380, not stretch")

func test_lane_width_not_capped_above_four_lanes() -> void:
	var width := WolfLaneLayout.lane_width_for(5)
	var uncapped := (1730.0 - 4.0 * 18.0) / 5.0
	assert_true(is_equal_approx(width, uncapped), "5 lanes should use the raw formula, not the 4-lane cap")

func test_stack_zone_geometry_roomy_case_at_low_stack() -> void:
	var geo := WolfLaneLayout.stack_zone_geometry(2)
	assert_eq(geo["impact_y"], 560.0, "max_stack <= 2 should raise the impact line")
	assert_eq(geo["card_height"], 280.0, "max_stack <= 2 should grow the cards")

func test_stack_zone_geometry_normal_case() -> void:
	var geo := WolfLaneLayout.stack_zone_geometry(3)
	assert_eq(geo["impact_y"], 626.0, "max_stack > 2 should use the normal impact line")
	assert_eq(geo["card_height"], 240.0, "max_stack > 2 should use the normal card height")

func test_compact_content_level_sheds_by_width() -> void:
	assert_eq(WolfLaneLayout.compact_content_level(268.0), 0, ">=240 should keep everything")
	assert_eq(WolfLaneLayout.compact_content_level(200.0), 1, "180-239 should drop the silhouette")
	assert_eq(WolfLaneLayout.compact_content_level(165.0), 2, "150-179 should drop the ability text too")
	assert_eq(WolfLaneLayout.compact_content_level(100.0), 3, "<150 should fall back to a numeric pip summary")

func test_stack_slot_fills_bottom_up_left_to_right() -> void:
	assert_eq(WolfLaneLayout.stack_slot(0, 3), Vector2i(0, 0), "index 0 should be the bottom row's first column")
	assert_eq(WolfLaneLayout.stack_slot(2, 3), Vector2i(2, 0), "index 2 should fill out the bottom row")
	assert_eq(WolfLaneLayout.stack_slot(3, 3), Vector2i(0, 1), "index 3 should wrap to the next row up")

func test_lane_display_slots_no_overflow_within_capacity() -> void:
	var tier := WolfLaneLayout.tier_for(8)
	var slots := WolfLaneLayout.lane_display_slots(5, tier)
	assert_eq(slots["shown"], 5, "under capacity should show every wolf")
	assert_eq(slots["overflow"], 0, "under capacity should have no overflow chip")

func test_lane_display_slots_overflow_reserves_one_chip_slot() -> void:
	var tier := WolfLaneLayout.tier_for(25)
	var slots := WolfLaneLayout.lane_display_slots(30, tier)
	assert_eq(slots["shown"], 22, "over the 23-slot D+ capacity should show capacity - 1 tokens")
	assert_eq(slots["overflow"], 8, "the remainder should be folded into the +N MORE chip")

func test_lane_ceiling_sums_live_wolves_only() -> void:
	var wolves := [
		_wolf("live_cr", "cruiser", "aegis"),
		_wolf("dead_cr", "cruiser", "aegis", true),
		_wolf("live_de", "destroyer", "aegis"),
	]
	# cruiser survives-damage = 3, destroyer survives-damage = 2, destroyed wolves contribute nothing
	assert_eq(WolfLaneLayout.lane_ceiling(wolves, 0), 5, "ceiling should sum only live wolves' survives-damage")

func test_lane_ceiling_applies_the_strikecarrier_buff_to_fighter_wings_only() -> void:
	var wolves := [_wolf("fw", "fighter_wing", "aegis"), _wolf("sc", "strikecarrier", "aegis")]
	# fighter wing base 1 + 1 live strikecarrier * bonus 1 = 2; strikecarrier itself stays flat 2
	assert_eq(WolfLaneLayout.lane_ceiling(wolves, 1), 4, "fighter wing ceiling should rise with the live strikecarrier count, the strikecarrier's own ceiling should not")

func test_lane_floor_zero_during_targeting() -> void:
	var wolves := [_wolf("cr", "cruiser", "aegis")]
	assert_eq(WolfLaneLayout.lane_floor(wolves, "targeting"), 0, "no range phase has happened yet - the whole ceiling is still preventable")

func test_lane_floor_uses_the_current_range_phase() -> void:
	var wolves := [_wolf("cr", "cruiser", "aegis"), _wolf("de", "destroyer", "aegis")]
	assert_eq(WolfLaneLayout.lane_floor(wolves, "range_long"), 1, "cruiser destroyed-at-long=0, destroyer destroyed-at-long=1")
	assert_eq(WolfLaneLayout.lane_floor(wolves, "range_short"), 3, "cruiser destroyed-at-short=2, destroyer destroyed-at-short=1")

func test_lane_floor_skips_wolves_immune_this_phase() -> void:
	var wolves := [_wolf("bs", "battlestation", "aegis")]
	assert_eq(WolfLaneLayout.lane_floor(wolves, "range_short"), 0, "battlestation cannot be destroyed at short - contributes nothing to the floor there")
	assert_eq(WolfLaneLayout.lane_floor(wolves, "range_long"), 3, "but does contribute at long, where it can be destroyed")

func test_live_strikecarrier_count_is_attack_wide_not_lane_scoped() -> void:
	var wolf_ships := [
		_wolf("sc1", "strikecarrier", "aegis"),
		_wolf("sc2", "strikecarrier", "dione"),
		_wolf("sc3_dead", "strikecarrier", "aegis", true),
		_wolf("cr", "cruiser", "aegis"),
	]
	assert_eq(WolfLaneLayout.live_strikecarrier_count(wolf_ships), 2, "should count live strikecarriers across every lane in the whole attack, not just one")

func test_incoming_bp_only_counts_live_assault_transports() -> void:
	var wolves := [
		_wolf("at1", "assault_transport", "aegis"),
		_wolf("at2_dead", "assault_transport", "aegis", true),
		_wolf("cr", "cruiser", "aegis"),
	]
	assert_eq(WolfLaneLayout.incoming_bp_for_lane(wolves), 4, "only the one live assault transport should contribute boarding parties")

func test_incoming_bp_ignores_core_range_phase_gating() -> void:
	# Regression guard: WolfAttackView only populates a wolf's "boarders"
	## field during a live range phase, but incoming_bp_for_lane derives
	## from the hull class directly, so it must still read 4 even when the
	## dict has no "boarders" key at all (i.e. during "targeting").
	var wolves := [_wolf("at", "assault_transport", "aegis")]
	assert_true(not wolves[0].has("boarders"), "sanity check: the fixture deliberately omits the core-provided boarders field")
	assert_eq(WolfLaneLayout.incoming_bp_for_lane(wolves), 4, "boarding parties should be derivable even without core's phase-gated field")

func test_badge_returns_only_for_battlestation_and_fighter_wing() -> void:
	assert_true(WolfLaneLayout.badge_returns(_wolf("w", "battlestation", "aegis")), "battlestation returns")
	assert_true(WolfLaneLayout.badge_returns(_wolf("w", "fighter_wing", "aegis")), "fighter wing returns")
	assert_true(not WolfLaneLayout.badge_returns(_wolf("w", "cruiser", "aegis")), "cruiser does not return")
	assert_true(not WolfLaneLayout.badge_returns(_wolf("w", "battlestation", "aegis", true)), "a destroyed ship is not returning")

func test_badge_boarding_parties_only_for_live_assault_transport() -> void:
	assert_eq(WolfLaneLayout.badge_boarding_parties(_wolf("w", "assault_transport", "aegis")), 4, "assault transport contributes 4 boarding parties")
	assert_eq(WolfLaneLayout.badge_boarding_parties(_wolf("w", "assault_transport", "aegis", true)), 0, "a destroyed assault transport contributes none")
	assert_eq(WolfLaneLayout.badge_boarding_parties(_wolf("w", "cruiser", "aegis")), 0, "not an assault transport")

func test_badge_fw_buff_only_for_live_strikecarrier_and_reflects_the_live_count() -> void:
	assert_eq(WolfLaneLayout.badge_fw_buff(_wolf("w", "strikecarrier", "aegis"), 3), 3, "shows the current live fighter wing count")
	assert_eq(WolfLaneLayout.badge_fw_buff(_wolf("w", "strikecarrier", "aegis"), 0), 0, "zero live fighter wings means no buff to show")
	assert_eq(WolfLaneLayout.badge_fw_buff(_wolf("w", "strikecarrier", "aegis", true), 3), 0, "a destroyed strikecarrier is not buffing anything")
	assert_eq(WolfLaneLayout.badge_fw_buff(_wolf("w", "cruiser", "aegis"), 3), 0, "not a strikecarrier")

func test_badge_cannot_be_damaged_at_short_only_for_live_battlestation() -> void:
	assert_true(WolfLaneLayout.badge_cannot_be_damaged_at_short(_wolf("w", "battlestation", "aegis")), "battlestation cannot be damaged at short")
	assert_true(not WolfLaneLayout.badge_cannot_be_damaged_at_short(_wolf("w", "battlestation", "aegis", true)), "already destroyed - the badge no longer applies")
	assert_true(not WolfLaneLayout.badge_cannot_be_damaged_at_short(_wolf("w", "cruiser", "aegis")), "not a battlestation")

func test_sort_fleet_ships_by_targeting_order_fixes_shepherd_quellon_swap() -> void:
	# Regression guard for the exact bug reported from real use: lanes
	# built from ShipRegistry's own display order put Shepherd (targeting
	# index 5) before Quellon (targeting index 4), so a lane's physical
	# left-to-right position no longer matched the index number printed
	# on its own fleet card.
	var fleet_ships := [
		{"id": "aegis"}, {"id": "dione"}, {"id": "icebreaker"},
		{"id": "shepherd"}, {"id": "quellon"}, {"id": "refinery_124"},
	]
	var sorted := WolfLaneLayout.sort_fleet_ships_by_targeting_order(fleet_ships)
	var ids: Array = sorted.map(func(f: Dictionary): return f["id"])
	assert_eq(ids, ["aegis", "dione", "icebreaker", "quellon", "shepherd", "refinery_124"], "lane order must follow the Wolf Attack Sheet's targeting-die order, not ShipRegistry's display order")

func test_ladder_cell_values_matches_the_printed_cards() -> void:
	assert_eq(WolfLaneLayout.ladder_cell_values(_wolf("w", "cruiser", "aegis"), 0), [0, 1, 2, 3], "cruiser: rising shape")
	assert_eq(WolfLaneLayout.ladder_cell_values(_wolf("w", "battlestation", "aegis"), 0), [3, 3, null, 3], "battlestation: null (not 0) at short")

func test_ladder_cell_values_survives_cell_reflects_live_strikecarrier_count() -> void:
	assert_eq(WolfLaneLayout.ladder_cell_values(_wolf("w", "fighter_wing", "aegis"), 0)[3], 1, "no live strikecarrier: base value")
	assert_eq(WolfLaneLayout.ladder_cell_values(_wolf("w", "fighter_wing", "aegis"), 2)[3], 3, "two live strikecarriers: +2 bonus")
	assert_eq(WolfLaneLayout.ladder_cell_values(_wolf("w", "strikecarrier", "aegis"), 5)[3], 2, "a strikecarrier's own survives cell never changes")

func test_current_cell_index_matches_the_active_range_phase() -> void:
	assert_eq(WolfLaneLayout.current_cell_index("targeting"), -1, "nothing committed yet during targeting")
	assert_eq(WolfLaneLayout.current_cell_index("range_long"), 0, "long range is index 0")
	assert_eq(WolfLaneLayout.current_cell_index("range_medium"), 1, "medium range is index 1")
	assert_eq(WolfLaneLayout.current_cell_index("range_short"), 2, "short range is index 2")
	assert_eq(WolfLaneLayout.current_cell_index("boarding"), -1, "not a range phase")

func test_ladder_cell_states_during_targeting_nothing_is_boxed() -> void:
	var states := WolfLaneLayout.ladder_cell_states(_wolf("w", "cruiser", "aegis"), "targeting")
	assert_eq(states, [WolfLaneLayout.CellState.FUTURE, WolfLaneLayout.CellState.FUTURE, WolfLaneLayout.CellState.FUTURE, WolfLaneLayout.CellState.SURVIVES_LIVE], "no cell should be boxed as current during targeting")

func test_ladder_cell_states_at_medium_boxes_the_current_cell() -> void:
	var states := WolfLaneLayout.ladder_cell_states(_wolf("w", "cruiser", "aegis"), "range_medium")
	assert_eq(states[0], WolfLaneLayout.CellState.PASSED, "long has passed")
	assert_eq(states[1], WolfLaneLayout.CellState.CURRENT, "medium is current")
	assert_eq(states[2], WolfLaneLayout.CellState.FUTURE, "short hasn't happened yet")
	assert_eq(states[3], WolfLaneLayout.CellState.SURVIVES_LIVE, "survives stays live-coloured while the wolf is alive")

func test_ladder_cell_states_destroyed_shows_the_realised_cell() -> void:
	var wolf := _wolf("w", "cruiser", "aegis", true, {"destroyed_at_phase": 1})
	var states := WolfLaneLayout.ladder_cell_states(wolf, "range_short")
	assert_eq(states, [WolfLaneLayout.CellState.GHOSTED, WolfLaneLayout.CellState.REALISED, WolfLaneLayout.CellState.GHOSTED, WolfLaneLayout.CellState.SURVIVES_GHOSTED], "the phase it actually died in is realised, everything else (including survives, which didn't happen) is ghosted - regardless of what phase is current now")

func test_ladder_cell_states_destroyed_outside_a_range_phase_ghosts_everything() -> void:
	var wolf := _wolf("w", "cruiser", "aegis", true)  # destroyed_at_phase defaults to -1
	var states := WolfLaneLayout.ladder_cell_states(wolf, "range_short")
	assert_eq(states, [WolfLaneLayout.CellState.GHOSTED, WolfLaneLayout.CellState.GHOSTED, WolfLaneLayout.CellState.GHOSTED, WolfLaneLayout.CellState.SURVIVES_GHOSTED], "no specific cell to realise - a rare host-override edge case, stay safe rather than boxing the wrong thing")
