extends TestCase

## Players carry secret data (suspicion, facilitator clues) that must
## never be broadcast to every connected client - see
## GameState.to_public_dict()'s comment and open_questions_answered.md
## §4.3/§4.5. These tests guard that boundary directly, since a
## regression here would leak one player's suspicion/clues to every
## phone on the network.

func test_to_dict_includes_players() -> void:
	var state := GameState.new()
	state.add_player(Player.new("p1", "Alex"))
	assert_true(state.to_dict().has("players"), "to_dict() (used for the host-local save file) should include players")
	assert_true(state.to_dict()["players"].has("p1"), "to_dict() should include the added player")

func test_to_public_dict_excludes_players() -> void:
	var state := GameState.new()
	state.add_player(Player.new("p1", "Alex"))
	assert_true(not state.to_public_dict().has("players"), "to_public_dict() (used for the broadcast to every client) must not include players")

func test_to_public_dict_still_includes_public_state() -> void:
	var state := GameState.new()
	state.add_ship(Ship.new("aegis"))
	var public_dict := state.to_public_dict()
	assert_true(public_dict.has("ships"), "to_public_dict() should still include ships")
	assert_true(public_dict.has("pursuit_track"), "to_public_dict() should still include the pursuit track")
	assert_true(public_dict.has("announcement_log"), "to_public_dict() should still include the announcement log")

func test_player_to_dict_returns_only_that_player() -> void:
	var state := GameState.new()
	var alex := Player.new("p1", "Alex")
	alex.set_suspicion(9)
	var sam := Player.new("p2", "Sam")
	sam.set_suspicion(2)
	state.add_player(alex)
	state.add_player(sam)

	var slice := state.player_to_dict("p1")

	assert_eq(slice.get("name"), "Alex", "player_to_dict should return the requested player's own data")
	assert_eq(slice.get("suspicion"), 9, "player_to_dict should return the requested player's own suspicion")
	assert_true(not slice.has("p2"), "player_to_dict must not include any other player's data")

func test_player_to_dict_on_unknown_id_returns_empty() -> void:
	var state := GameState.new()
	assert_eq(state.player_to_dict("no-such-player"), {}, "an unknown player id should return {}, not crash or leak arbitrary data")

func test_generate_player_id_produces_unique_ids() -> void:
	var state := GameState.new()
	var seen: Dictionary[String, bool] = {}
	for i in range(50):
		var id := state.generate_player_id()
		assert_true(not seen.has(id), "generate_player_id should never repeat an id within a game")
		seen[id] = true
		state.add_player(Player.new(id, "Player %d" % i))

func test_round_trips_players_through_persistence() -> void:
	var state := GameState.new()
	var alex := Player.new("p1", "Alex")
	alex.set_suspicion(6)
	alex.add_clue("Someone's asking odd questions.", 2)
	state.add_player(alex)

	var loaded := GameState.from_dict(state.to_dict())

	var loaded_alex := loaded.get_player("p1")
	assert_true(loaded_alex != null, "the player should round-trip")
	assert_eq(loaded_alex.suspicion, 6, "suspicion should round-trip")
	assert_eq(loaded_alex.clues.size(), 1, "clues should round-trip")

func test_rehydrated_player_mutations_still_bubble_to_mutated() -> void:
	var state := GameState.new()
	state.add_player(Player.new("p1", "Alex"))
	var loaded := GameState.from_dict(state.to_dict())
	var count: Array[int] = [0]
	loaded.mutated.connect(func() -> void: count[0] += 1)

	loaded.get_player("p1").set_suspicion(3)

	assert_true(count[0] > 0, "mutating a rehydrated player should still reach GameState.mutated")
