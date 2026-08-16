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
