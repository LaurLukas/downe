extends TestCase

func test_publish_claim_stores_verbatim_text() -> void:
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "G - Level 5 Survivable Planet", "STARLIGHT", 3)
	var claims := reveal.claims_at("3068")
	assert_eq(claims.size(), 1, "should store one claim")
	assert_eq(claims[0]["text"], "G - Level 5 Survivable Planet", "the claim text should be stored byte-for-byte")
	assert_eq(claims[0]["source"], "STARLIGHT", "should record the reporting role")
	assert_eq(claims[0]["turn"], 3, "should record the turn")

func test_contradicting_claims_both_stack() -> void:
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "G - Level 5 Survivable Planet", "STARLIGHT", 3)
	reveal.publish_claim("3068", "looked like a fortress to me", "HUMMINGBIRD", 3)
	var claims := reveal.claims_at("3068")
	assert_eq(claims.size(), 2, "contradicting claims should both be kept, not resolved")

func test_retract_claim_removes_by_index() -> void:
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "first claim", "STARLIGHT", 1)
	reveal.publish_claim("3068", "second claim", "HUMMINGBIRD", 2)
	reveal.retract_claim("3068", 0)
	var claims := reveal.claims_at("3068")
	assert_eq(claims.size(), 1, "should have one claim left")
	assert_eq(claims[0]["text"], "second claim", "the remaining claim should be the one not retracted")

func test_retracting_the_last_claim_clears_the_coordinate() -> void:
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "only claim", "STARLIGHT", 1)
	reveal.retract_claim("3068", 0)
	assert_true(reveal.claims_at("3068").is_empty(), "should have no claims left")
	assert_true(not reveal.claims.has("3068"), "the coordinate key itself should be cleared, not left as an empty array")

func test_forced_state_set_and_cleared() -> void:
	var reveal := RevealState.new()
	reveal.set_forced_state("1096", "destination")
	assert_eq(reveal.forced_states.get("1096", ""), "destination", "should store the forced state")
	reveal.clear_forced_state("1096")
	assert_true(not reveal.forced_states.has("1096"), "clearing should remove the override entirely")

func test_to_dict_and_from_dict_round_trip() -> void:
	var reveal := RevealState.new()
	reveal.publish_claim("3068", "a claim", "STARLIGHT", 3)
	reveal.set_forced_state("1096", "unknown")

	var restored := RevealState.from_dict(reveal.to_dict())
	assert_eq(restored.claims_at("3068").size(), 1, "claims should round-trip")
	assert_eq(restored.claims_at("3068")[0]["text"], "a claim", "claim text should round-trip")
	assert_eq(restored.forced_states.get("1096", ""), "unknown", "forced states should round-trip")
