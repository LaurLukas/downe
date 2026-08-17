extends TestCase

func test_number_cards_score_face_value() -> void:
	assert_eq(AwayMissionOpportunity.card_value("7"), 7, "number card should score its face value")
	assert_eq(AwayMissionOpportunity.card_value("10"), 10, "10 should score 10")

func test_ace_scores_one() -> void:
	assert_eq(AwayMissionOpportunity.card_value("A"), 1, "Ace should score 1")

func test_face_cards_score_negative_five() -> void:
	assert_eq(AwayMissionOpportunity.card_value("J"), -5, "Jack should score -5")
	assert_eq(AwayMissionOpportunity.card_value("Q"), -5, "Queen should score -5")
	assert_eq(AwayMissionOpportunity.card_value("K"), -5, "King should score -5")

func test_score_sums_cards_plus_shuttle_bonus() -> void:
	var total := AwayMissionOpportunity.score(["A", "5", "K"], 2)
	assert_eq(total, 1 + 5 - 5 + 2, "score should sum card values and add the shuttle bonus")

func test_is_success_at_or_above_threshold() -> void:
	assert_true(AwayMissionOpportunity.is_success(17, 17), "meeting the threshold exactly should succeed")
	assert_true(AwayMissionOpportunity.is_success(20, 17), "exceeding the threshold should succeed")
	assert_true(not AwayMissionOpportunity.is_success(16, 17), "falling short should not succeed")

func test_is_critical_requires_a_critical_tier() -> void:
	assert_true(not AwayMissionOpportunity.is_critical(999, -1), "a critical_threshold of -1 (no crit tier) should never be met")

func test_is_critical_at_or_above_threshold() -> void:
	assert_true(AwayMissionOpportunity.is_critical(30, 30), "meeting the critical threshold exactly should crit")
	assert_true(not AwayMissionOpportunity.is_critical(29, 30), "falling short of the critical threshold should not crit")

func test_opportunity_accepts_skill() -> void:
	var opportunity := AwayMissionOpportunity.new([AwayMissionOpportunity.Skill.MINING, AwayMissionOpportunity.Skill.EXPLORATION], 20)
	assert_true(opportunity.accepts_skill(AwayMissionOpportunity.Skill.MINING), "should accept mining")
	assert_true(opportunity.accepts_skill(AwayMissionOpportunity.Skill.EXPLORATION), "should accept exploration")
	assert_true(not opportunity.accepts_skill(AwayMissionOpportunity.Skill.SCIENCE), "should not accept an unlisted skill")

func test_opportunity_stores_difficulty_and_rewards() -> void:
	var opportunity := AwayMissionOpportunity.new([AwayMissionOpportunity.Skill.SALVAGE], 14, 20, "10 food", "crit 8 water")
	assert_eq(opportunity.difficulty, 14, "difficulty should be stored")
	assert_eq(opportunity.critical_threshold, 20, "critical_threshold should be stored")
	assert_eq(opportunity.reward_description, "10 food", "reward_description should be stored")
	assert_eq(opportunity.critical_reward_description, "crit 8 water", "critical_reward_description should be stored")
