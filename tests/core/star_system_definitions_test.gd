extends TestCase

func test_all_sixteen_letters_present() -> void:
	var letters := StarSystemDefinitions.all_letters()
	assert_eq(letters.size(), 16, "there should be 16 systems, A through P")
	for letter in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]:
		assert_true(letter in letters, "system %s should be in the roster" % letter)

func test_card_systems_have_opportunities() -> void:
	for letter in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"]:
		var definition := StarSystemDefinitions.get_definition(letter)
		assert_true(definition.opportunities.size() > 0, "system %s should have at least one opportunity" % letter)

func test_new_eden_candidates_have_no_card_opportunities_but_have_descriptions() -> void:
	for letter in ["N", "O", "P"]:
		var definition := StarSystemDefinitions.get_definition(letter)
		assert_true(definition.is_new_eden_candidate, "%s should be flagged as a New Eden candidate" % letter)
		assert_eq(definition.opportunities.size(), 0, "%s should have no card-based opportunities (bespoke mechanics, not modeled yet)" % letter)
		assert_true(not definition.new_eden_description.is_empty(), "%s should have a description of its bespoke condition" % letter)

func test_system_c_accepts_either_mining_or_exploration() -> void:
	var definition := StarSystemDefinitions.get_definition("C")
	var first_opportunity := definition.opportunities[0]
	assert_true(first_opportunity.accepts_skill(AwayMissionOpportunity.Skill.MINING), "system C's first opportunity should accept mining")
	assert_true(first_opportunity.accepts_skill(AwayMissionOpportunity.Skill.EXPLORATION), "system C's first opportunity should accept exploration")

func test_system_g_suppresses_pursuit_reduction() -> void:
	assert_true(StarSystemDefinitions.get_definition("G").suppresses_pursuit_reduction, "G should not reduce pursuit on arrival")
	assert_true(not StarSystemDefinitions.get_definition("A").suppresses_pursuit_reduction, "most systems should reduce pursuit normally")

func test_system_i_suppresses_pursuit_rise_and_has_maintenance_damage() -> void:
	var definition := StarSystemDefinitions.get_definition("I")
	assert_true(definition.suppresses_pursuit_rise_while_present, "I should not raise pursuit while present")
	assert_eq(definition.maintenance_damage_threshold, 3, "I's ships take damage on a 3+ during maintenance")

func test_system_j_has_maintenance_damage_and_repeats() -> void:
	var definition := StarSystemDefinitions.get_definition("J")
	assert_eq(definition.maintenance_damage_threshold, 4, "J's ships take damage on a 4+ during maintenance")
	assert_true(definition.repeatable_each_turn, "J's opportunity repeats every turn")

func test_system_k_has_hidden_difficulty_and_repeats() -> void:
	var definition := StarSystemDefinitions.get_definition("K")
	assert_true(definition.has_hidden_difficulty, "K's difficulty should be flagged as hidden")
	assert_true(definition.repeatable_each_turn, "K's opportunity repeats every turn")
	assert_true(definition.opportunities[0].hidden_until_rolled, "K's opportunity itself should be flagged hidden_until_rolled")
	assert_true(definition.triggers_wolf_attack_unless_critical, "K should trigger a Wolf Attack unless the mission crits")
	assert_true(not definition.triggers_wolf_attack_on_arrival, "K's trigger is on mission completion, not arrival")

func test_systems_l_and_m_block_away_mission_while_base_operational() -> void:
	for letter in ["L", "M"]:
		var definition := StarSystemDefinitions.get_definition(letter)
		assert_true(definition.away_mission_blocked_while_wolf_base_operational, "%s's away mission should be blocked while its Wolf base is operational" % letter)
		assert_true(definition.triggers_wolf_attack_on_arrival, "%s should trigger a Wolf Attack on arrival" % letter)

func test_system_l_wolf_attack_minimums() -> void:
	var definition := StarSystemDefinitions.get_definition("L")
	assert_eq(definition.wolf_attack_min_battlestations, 1, "L requires at least 1 battlestation")
	assert_eq(definition.wolf_attack_min_capacity, 20, "L requires at least 20 damage capacity")

func test_system_m_wolf_attack_minimums_are_larger_than_l() -> void:
	var l := StarSystemDefinitions.get_definition("L")
	var m := StarSystemDefinitions.get_definition("M")
	assert_true(m.wolf_attack_min_battlestations > l.wolf_attack_min_battlestations, "M should require more battlestations than L")
	assert_true(m.wolf_attack_min_capacity > l.wolf_attack_min_capacity, "M should require more capacity than L")

func test_system_p_triggers_wolf_attack_on_arrival() -> void:
	var definition := StarSystemDefinitions.get_definition("P")
	assert_true(definition.triggers_wolf_attack_on_arrival, "P should trigger a Wolf Attack on arrival")
	assert_eq(definition.wolf_attack_min_battlestations, 1, "P requires at least 1 battlestation")
	assert_eq(definition.wolf_attack_min_capacity, 20, "P requires at least 20 damage capacity")

func test_system_e_reward_replaces_broken_w1_w2_reference() -> void:
	# The source table's third opportunity reward for E references
	# "wolf star systems (code W1 or W2)", which don't exist anywhere
	# in the data - resolved with the user by replacing it with a
	# reward pointing at the two real Wolf systems instead. This test
	# guards that the replacement stayed in, not the broken original.
	var definition := StarSystemDefinitions.get_definition("E")
	var third_reward: String = definition.opportunities[2].reward_description
	assert_true(third_reward.findn("W1") == -1 and third_reward.findn("W2") == -1, "the replaced reward should not reference the nonexistent W1/W2 codes")
	assert_true(third_reward.findn("L") != -1 and third_reward.findn("M") != -1, "the replacement reward should reference the real Wolf systems L and M")

func test_ratings_match_source_for_poor_systems() -> void:
	for letter in ["A", "B", "C"]:
		assert_eq(StarSystemDefinitions.get_definition(letter).rating, "Poor", "%s should be rated Poor" % letter)

func test_rating_neutral_for_d() -> void:
	assert_eq(StarSystemDefinitions.get_definition("D").rating, "Neutral", "D should be rated Neutral")

func test_no_minerals_resource_type_appears_anywhere() -> void:
	# "The system card says '2 minerals'. There is no such resource. It
	# means materials. Do not add a minerals type." - source doc §1.2.
	for letter: String in StarSystemDefinitions.all_letters():
		for opportunity: AwayMissionOpportunity in StarSystemDefinitions.get_definition(letter).opportunities:
			assert_true(opportunity.reward_description.findn("mineral") == -1, "%s should never mention 'minerals' - that's materials, per the source doc" % letter)
