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
	assert_eq(WolfLaneLayout.tier_for(1)["name"], "A", "1 should be tier A")
	assert_eq(WolfLaneLayout.tier_for(3)["name"], "A", "3 should still be tier A")
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

func test_incoming_damage_sums_live_wolves_only() -> void:
	var wolves := [
		_wolf("live_cr", "cruiser", "aegis"),
		_wolf("dead_cr", "cruiser", "aegis", true),
		_wolf("live_de", "destroyer", "aegis"),
	]
	# cruiser survives-damage = 3, destroyer survives-damage = 2, destroyed wolves contribute nothing
	assert_eq(WolfLaneLayout.incoming_damage_for_lane(wolves), 5, "incoming damage should sum only live wolves' survives-damage")

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

func test_ability_label_full_assault_transport_ignores_core_range_phase_gating() -> void:
	# Regression guard for the exact bug reported from real host-console
	# use: the token's own "PREVENTS N BP" text used to read core's
	# phase-gated "boarders" field directly and printed "PREVENTS 0 BP"
	# during "targeting" for a wolf that already had a real target.
	var wolf := _wolf("at", "assault_transport", "aegis")
	assert_true(not wolf.has("boarders"), "sanity check: the fixture deliberately omits the core-provided boarders field")
	assert_eq(WolfLaneLayout.ability_label_full(wolf), "PREVENTS 4 BP", "the full label must not read 0 just because core hasn't populated boarders yet")
	assert_eq(WolfLaneLayout.ability_abbrev(wolf), "4BP", "the compact abbreviation must not read 0 either")

func test_ability_label_full_destroyed_overrides_everything() -> void:
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "battlestation", "aegis", true)), "DESTROYED", "destroyed should override the hull's normal ability text")

func test_ability_label_full_per_hull() -> void:
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "battlestation", "aegis")), "SIEGE BATTERY", "battlestation should always read SIEGE BATTERY")
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "strikecarrier", "aegis")), "STOPS FW BUFF", "strikecarrier should always read STOPS FW BUFF")
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "assault_transport", "aegis", false, {"boarders": 4})), "PREVENTS 4 BP", "assault transport should read its boarders count")
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "cruiser", "aegis", false, {"prevents": 2})), "PREVENTS 2", "cruiser should read its phase-derived prevents number")

func test_ability_label_full_immune_takes_priority_over_hull_text() -> void:
	assert_eq(WolfLaneLayout.ability_label_full(_wolf("w", "battlestation", "aegis", false, {"immune_this_phase": true})), "IMMUNE", "immune_this_phase should override the hull's normal ability text")

func test_ability_abbrev_matches_the_full_label_meaning() -> void:
	assert_eq(WolfLaneLayout.ability_abbrev(_wolf("w", "battlestation", "aegis", true)), "DEAD", "destroyed compact abbreviation should be DEAD")
	assert_eq(WolfLaneLayout.ability_abbrev(_wolf("w", "battlestation", "aegis")), "SIEGE", "battlestation abbreviation should be SIEGE")
	assert_eq(WolfLaneLayout.ability_abbrev(_wolf("w", "strikecarrier", "aegis")), "FW+", "strikecarrier abbreviation should be FW+")
	assert_eq(WolfLaneLayout.ability_abbrev(_wolf("w", "assault_transport", "aegis", false, {"boarders": 4})), "4BP", "assault transport abbreviation should show its boarders count")
	assert_eq(WolfLaneLayout.ability_abbrev(_wolf("w", "cruiser", "aegis", false, {"prevents": 2})), "P2", "cruiser abbreviation should show its phase-derived prevents number")

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
