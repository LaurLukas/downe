class_name GameState
extends RefCounted

## Root of the rules engine. Holds everything the host's persistence
## layer (net/) dumps to user:// on every mutation - see CLAUDE.md's
## Persistence section. This class stays pure data + rules; it never
## touches FileAccess, Node, or the scene tree.

signal mutated()

var ships: Dictionary[String, Ship] = {}
var craft: Dictionary[String, CraftState] = {}
var star_systems: Dictionary[String, StarSystem] = {}
var players: Dictionary[String, Player] = {}
var pursuit_track := PursuitTrack.new()
var turn_manager := TurnManager.new()
var announcement_log := AnnouncementLog.new()

const _PLAYER_ID_ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"

## Player ids are embedded in that player's phone-page URL/QR code, so
## they need to be hard to stumble onto by guessing, not just unique -
## see HostConsole's Players section. Rolled from the same seeded rng
## as everything else (CLAUDE.md: never randi()/randf() directly), so
## even this is reproducible from a saved seed.
func generate_player_id() -> String:
	var id := ""
	while id.is_empty() or players.has(id):
		id = ""
		for i in range(8):
			id += _PLAYER_ID_ALPHABET[rng.randi_range(0, _PLAYER_ID_ALPHABET.length() - 1)]
	return id

## Abilities and other rules that need randomness must roll against
## this, never call randi()/randf() directly, so a game is reproducible
## from its JSON dump (downe_shuttle_implementation_prompt.md §1). The
## seed is persisted; the stream's current position is not - reloading
## a save resumes with a fresh stream from the same seed, not the exact
## roll sequence in progress.
var rng := RandomNumberGenerator.new()

func _init() -> void:
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.phase_changed.connect(func(_turn: int, _phase: TurnManager.Phase) -> void: mutated.emit())
	pursuit_track.changed.connect(func(_new_value: int) -> void: mutated.emit())
	announcement_log.entry_added.connect(func(_entry: Dictionary) -> void: mutated.emit())

func add_ship(ship: Ship) -> void:
	ships[ship.id] = ship
	ship.changed.connect(mutated.emit)
	ship.jump_coordinates_set.connect(func(text: String) -> void: announcement_log.add("jump", ship.id, text, turn_manager.turn_number))
	mutated.emit()

func get_ship(ship_id: String) -> Ship:
	return ships.get(ship_id)

func add_craft(craft_state: CraftState) -> void:
	craft[craft_state.id] = craft_state
	craft_state.changed.connect(mutated.emit)
	craft_state.scout_report_set.connect(func(text: String) -> void: announcement_log.add("scout", craft_state.id, text, turn_manager.turn_number))
	mutated.emit()

func get_craft(craft_id: String) -> CraftState:
	return craft.get(craft_id)

func add_player(player: Player) -> void:
	players[player.id] = player
	player.changed.connect(mutated.emit)
	mutated.emit()

func get_player(player_id: String) -> Player:
	return players.get(player_id)

func add_star_system(system: StarSystem) -> void:
	star_systems[system.id] = system
	mutated.emit()

func get_star_system(system_id: String) -> StarSystem:
	return star_systems.get(system_id)

## Unused console charge and unused craft fuel/per-turn ability uses are
## lost at the end of every turn, whether or not they were spent - see
## downe_shuttle_implementation_prompt.md §2 "Fuelling" and
## open_questions_answered.md §5.3. The boundary is "a new Team Phase
## started", since Team Phase is always turn N+1's first phase.
func _on_phase_changed(_turn: int, phase: TurnManager.Phase) -> void:
	if phase != TurnManager.Phase.TEAM:
		return
	for ship_id: String in ships:
		var ship: Ship = ships[ship_id]
		for console_id: String in ship.consoles:
			ship.consoles[console_id].set_charged(false)
	for craft_id: String in craft:
		craft[craft_id].clear_turn_state()

func to_dict() -> Dictionary:
	var ship_dict := {}
	for ship_id: String in ships:
		ship_dict[ship_id] = ships[ship_id].to_dict()
	var craft_dict := {}
	for craft_id: String in craft:
		craft_dict[craft_id] = craft[craft_id].to_dict()
	var player_dict := {}
	for player_id: String in players:
		player_dict[player_id] = players[player_id].to_dict()
	return {
		"pursuit_track": pursuit_track.to_dict(),
		"turn": turn_manager.to_dict(),
		"rng_seed": rng.seed,
		"ships": ship_dict,
		"craft": craft_dict,
		"announcement_log": announcement_log.to_dict(),
		"players": player_dict,
	}

## What gets broadcast to every connected client - everything except
## per-player secret data (suspicion, clues). Ships/craft/pursuit/turn
## are public knowledge in the fiction; a player's suspicion and clues
## are not, and broadcasting them to every socket would let anyone
## inspecting their browser's network traffic read what was meant for
## one specific player's phone. See player_to_dict() and
## ui/main.gd's per-player send.
func to_public_dict() -> Dictionary:
	var public_dict := to_dict()
	public_dict.erase("players")
	return public_dict

## The one player-specific slice that's safe to send to that player's
## own connection - see to_public_dict()'s comment.
func player_to_dict(player_id: String) -> Dictionary:
	var player := get_player(player_id)
	return player.to_dict() if player != null else {}

## Rebuilds a GameState from Persistence.load_dict()'s output - crash
## recovery, so the host can restart mid-game without the room standing
## around. See CLAUDE.md's Persistence section.
##
## turn_manager is restored before any ship/craft is added, deliberately:
## TurnManager.force_set() emits phase_changed the same as advance()
## does, which GameState._on_phase_changed() reacts to by clearing
## console charge and craft fuel/uses on every new Team Phase. Emitting
## that against empty ships/craft dicts makes it a no-op instead of
## wiping the very state this method is about to load.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.rng.seed = int(data.get("rng_seed", state.rng.seed))
	state.pursuit_track.load_from_dict(data.get("pursuit_track", {}))
	state.announcement_log.load_from_dict(data.get("announcement_log", {}))

	var turn_data: Dictionary = data.get("turn", {})
	state.turn_manager.force_set(
		int(turn_data.get("turn_number", 1)),
		TurnManager.Phase[turn_data.get("phase", "TEAM")]
	)

	var ship_dict_data: Dictionary = data.get("ships", {})
	for ship_id: String in ship_dict_data:
		state.add_ship(Ship.from_dict(ship_dict_data[ship_id]))

	var craft_dict_data: Dictionary = data.get("craft", {})
	for craft_id: String in craft_dict_data:
		state.add_craft(CraftState.from_dict(craft_dict_data[craft_id]))

	var player_dict_data: Dictionary = data.get("players", {})
	for player_id: String in player_dict_data:
		state.add_player(Player.from_dict(player_dict_data[player_id]))

	return state
