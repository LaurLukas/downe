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

## Null except during an active attack - CLAUDE.md constraint 3: Wolf
## Attacks stay a physical gathering, so this only exists when the host
## has actually started one, and goes away the moment they end it.
var wolf_attack: WolfAttack = null

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
	turn_manager.advanced.connect(_on_advanced)
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
	star_systems[system.letter] = system
	system.changed.connect(mutated.emit)
	mutated.emit()

func get_star_system(letter: String) -> StarSystem:
	return star_systems.get(letter)

func start_wolf_attack(round_number: int = 1) -> WolfAttack:
	wolf_attack = WolfAttack.new(turn_manager.turn_number, round_number)
	wolf_attack.changed.connect(mutated.emit)
	mutated.emit()
	return wolf_attack

## The host ends the attack when the physical gathering is done -
## never automatic. See CLAUDE.md constraint 3.
func end_wolf_attack() -> void:
	wolf_attack = null
	mutated.emit()

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
		ship.clear_maintenance_steps()
	for craft_id: String in craft:
		craft[craft_id].clear_turn_state()

## Pursuit +2 per turn - open_questions_answered.md §5.4. Connected to
## TurnManager.advanced, not phase_changed - see that signal's own
## comment for why. Fires only on a genuine advance() into a new Team
## Phase, never on force_set() (crash-recovery restore, or a host
## correction), and never on the game's very first Team Phase (turn 1
## starts there without ever calling advance() - same "no advance
## event yet" boundary the console-charge/craft-fuel clearing sweep
## above already relies on).
func _on_advanced(_turn: int, phase: TurnManager.Phase) -> void:
	if phase != TurnManager.Phase.TEAM:
		return
	pursuit_track.rise(2)

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
	var star_system_dict := {}
	for letter: String in star_systems:
		star_system_dict[letter] = star_systems[letter].to_dict()
	return {
		"pursuit_track": pursuit_track.to_dict(),
		"turn": turn_manager.to_dict(),
		"rng_seed": rng.seed,
		"ships": ship_dict,
		"craft": craft_dict,
		"announcement_log": announcement_log.to_dict(),
		"players": player_dict,
		"wolf_attack": wolf_attack.to_dict() if wolf_attack != null else null,
		"star_systems": star_system_dict,
	}

## What gets broadcast to every connected client - everything except
## per-player secret data (suspicion, clues), and with wolf_attack
## replaced by its redacted view rather than the raw object.
##
## Two separate secrets, two separate reasons: a player's suspicion and
## clues are not public knowledge in the fiction at all, so they're cut
## entirely (see player_to_dict() and ui/main.gd's per-player send).
## Wolf ship targeting *is* public once revealed - the raw
## WolfAttack.to_dict() just isn't safe to hand out before that, since
## every ship's target is pre-rolled and stored the moment it's added
## (wolf_attack_tv_display.md §2/§6: the view handed to clients during
## the pre-attack state must not *contain* the targets, not merely
## avoid drawing them). WolfAttackView.build() is the one function that
## already knows how to redact that correctly - reusing it here means
## the network payload can't leak what the TV already refuses to draw,
## instead of relying on every future renderer to remember not to.
func to_public_dict() -> Dictionary:
	var public_dict := to_dict()
	public_dict.erase("players")
	if wolf_attack != null:
		public_dict["wolf_attack"] = WolfAttackView.build(self)
	else:
		public_dict.erase("wolf_attack")
	# star_systems isn't broadcast at all yet - system K's
	# hidden_difficulty must never reach a player ("your UI must be
	# able to show an unknown difficulty without leaking the rolled
	# value" - open_questions_answered.md §1.2), and there's no away-
	# mission UI yet to justify building a partial-redaction view for
	# it the way WolfAttackView exists for targeting. Full exclusion
	# until that UI exists, same treatment as players.
	public_dict.erase("star_systems")
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

	var wolf_attack_data: Variant = data.get("wolf_attack")
	if wolf_attack_data is Dictionary:
		state.wolf_attack = WolfAttack.from_dict(wolf_attack_data)
		state.wolf_attack.changed.connect(state.mutated.emit)

	var star_system_dict_data: Dictionary = data.get("star_systems", {})
	for letter: String in star_system_dict_data:
		state.add_star_system(StarSystem.from_dict(star_system_dict_data[letter]))

	return state
