class_name StarSystemDefinitions
extends RefCounted

## The fixed roster of 16 star systems (A-P), transcribed from
## open_questions_answered.md §1.2's table. Never one hand-rolled class
## per system - all built from the same StarSystemDefinition shape.
##
## One deliberate departure from the source: system E's third
## opportunity reward reads "explore 2 wolf star systems (code W1 or
## W2)" in the source table, but no W1/W2 system exists anywhere in the
## charts or data - the source doc itself flags this and says "ask
## before modelling it." Resolved directly with the user: replaced with
## a reward pointing at real data (the two actual Wolf systems, L and
## M) instead of the broken reference, keeping the same "reveal Wolf
## territory" flavor. See _RAW_ROSTER's "e" entry.

static func _opp(skills: Array[AwayMissionOpportunity.Skill], difficulty: int, crit: int = -1, reward: String = "", crit_reward: String = "") -> AwayMissionOpportunity:
	return AwayMissionOpportunity.new(skills, difficulty, crit, reward, crit_reward)

## Built as its own function (rather than inline in the roster
## dictionary below) to keep the AwayMissionOpportunity.Skill enum path
## from having to be repeated at every reference - Skill is aliased
## locally once instead.
static func _opportunities_by_letter() -> Dictionary[String, Array]:
	const Skill = AwayMissionOpportunity.Skill
	return {
		"A": [
			_opp([Skill.EXPLORATION], 17, -1, "8 food"),
			_opp([Skill.MINING], 24, -1, "3 strytium ore"),
		],
		"B": [
			_opp([Skill.EXPLORATION], 17, -1, "6 water"),
			_opp([Skill.MINING], 24, 30, "8 water", "1 material"),
		],
		"C": [
			_opp([Skill.MINING, Skill.EXPLORATION], 20, -1, "2 materials"),
			_opp([Skill.SCIENCE], 25, -1, "Endeavour crosses out 1 research box of choice"),
		],
		"D": [
			_opp([Skill.SALVAGE], 14, 20, "10 food", "8 water"),
			_opp([Skill.SALVAGE], 14, 20, "6 strytium ore", "3 material"),
			_opp([Skill.SCIENCE], 24, -1, "explore 2 star systems"),
		],
		"E": [
			_opp([Skill.SEARCH_AND_RESCUE], 8, 15, "750 survivors", "+500 survivors"),
			_opp([Skill.SALVAGE], 14, 25, "4 materials", "+3 materials"),
			# Replaces the source's broken "explore 2 wolf star systems
			# (code W1 or W2)" - see class comment.
			_opp([Skill.SCIENCE], 24, -1, "reveals the location of the Active Wolf systems (L and M)"),
		],
		"F": [
			_opp([Skill.ENGINEERING], 8, -1, "10 strytium fuel"),
			_opp([Skill.SALVAGE], 14, 25, "7 strytium ore", "+4 strytium ore"),
			_opp([Skill.SCIENCE], 14, -1, "upgrade 1 or repair 2 consoles on Refinery 124"),
		],
		"G": [
			_opp([Skill.SEARCH_AND_RESCUE], 17, -1, "20 food"),
			_opp([Skill.ENGINEERING], 17, -1, "20 water"),
			_opp([Skill.SALVAGE], 24, 30, "6 materials", "upgrade 1 console"),
		],
		"H": [
			_opp([Skill.SALVAGE], 17, -1, "6 materials and 4 strytium fuel"),
			_opp([Skill.SCIENCE], 17, -1, "Endeavour crosses out 2 research boxes"),
			_opp([Skill.SCIENCE], 28, -1, "fully unlock 1 research"),
		],
		"I": [
			_opp([Skill.ENGINEERING], 17, -1, "fleet no longer takes nebula damage"),
			_opp([Skill.ENGINEERING], 17, -1, "ships don't consume fuel jumping out"),
			_opp([Skill.SCIENCE], 28, -1, "unlock ECM and Jump Drive research"),
		],
		"J": [
			_opp([Skill.MINING], 14, 25, "12 strytium ore", "+10 strytium ore"),
		],
		"K": [
			# hidden_until_rolled=true - difficulty is secretly rolled at
			# runtime (1d6 = X; difficulty 5X, critical 5X+10) and never
			# shown to players. See StarSystem.roll_hidden_difficulty().
			AwayMissionOpportunity.new([Skill.SEARCH_AND_RESCUE], 0, -1, "2X food, 2X water, 2X strytium fuel, X materials (X = secretly rolled 1d6)", "", true),
		],
		"L": [
			_opp([Skill.SALVAGE], 15, 20, "10 materials", "+5 materials"),
			_opp([Skill.SEARCH_AND_RESCUE], 15, 20, "10 strytium ore", "+5 strytium ore"),
			_opp([Skill.SCIENCE], 25, -1, "upgrade 2 weapon consoles"),
		],
		"M": [
			_opp([Skill.SALVAGE], 15, 20, "12 materials", "+6 materials"),
			_opp([Skill.SEARCH_AND_RESCUE], 15, 20, "12 strytium ore", "+6 strytium ore"),
			_opp([Skill.SCIENCE], 25, -1, "upgrade 3 weapon consoles"),
		],
	}

static func _build_definitions() -> Dictionary[String, StarSystemDefinition]:
	var opportunities_by_letter := _opportunities_by_letter()

	var raw: Dictionary[String, Dictionary] = {
		"A": {"letter": "A", "display_name": "Lichen-Covered Asteroids", "rating": "Poor", "cards_dealt": 6},
		"B": {"letter": "B", "display_name": "Ice Asteroids", "rating": "Poor", "cards_dealt": 6},
		"C": {"letter": "C", "display_name": "Rare Element Moon", "rating": "Poor", "cards_dealt": 6},
		"D": {"letter": "D", "display_name": "Abandoned Explorer Outpost", "rating": "Neutral", "cards_dealt": 6},
		"E": {"letter": "E", "display_name": "I.C.S.S. Athena Survivors", "cards_dealt": 6},
		"F": {"letter": "F", "display_name": "Abandoned Refuelling Station", "cards_dealt": 6},
		"G": {
			"letter": "G", "display_name": "Level 5 Survivable Planet", "cards_dealt": 8,
			"suppresses_pursuit_reduction": true,
		},
		"H": {"letter": "H", "display_name": "Derelict Research Vessel", "cards_dealt": 8},
		"I": {
			"letter": "I", "display_name": "Ion Nebula", "cards_dealt": 8,
			"suppresses_pursuit_rise_while_present": true,
			"maintenance_damage_threshold": 3,
		},
		"J": {
			"letter": "J", "display_name": "Unstable Star", "cards_dealt": 3,
			"repeatable_each_turn": true,
			"maintenance_damage_threshold": 4,
		},
		"K": {
			"letter": "K", "display_name": "Abandoned Wolf Supply Outpost", "cards_dealt": 3,
			"repeatable_each_turn": true,
			"has_hidden_difficulty": true,
			"triggers_wolf_attack_unless_critical": true,
		},
		"L": {
			"letter": "L", "display_name": "Active Wolf Outpost", "cards_dealt": 6,
			"triggers_wolf_attack_on_arrival": true,
			"wolf_attack_min_battlestations": 1, "wolf_attack_min_capacity": 20,
			"away_mission_blocked_while_wolf_base_operational": true,
		},
		"M": {
			"letter": "M", "display_name": "Active Wolf Fortress", "cards_dealt": 6,
			"triggers_wolf_attack_on_arrival": true,
			"wolf_attack_min_battlestations": 2, "wolf_attack_min_capacity": 25,
			"away_mission_blocked_while_wolf_base_operational": true,
		},
		# N, O, P: "New Eden candidates" - bespoke non-card completion
		# conditions, not the standard opportunity system. Data/topology
		# only for this pass; see new_eden_description and TODO.md.
		"N": {
			"letter": "N", "display_name": "Ancient Jump Ring", "is_new_eden_candidate": true,
			"new_eden_description": "Repair: 10 materials, an Engineering Shuttle, and 5 different console upgrades or science devices on the Endeavour research lab, each with 4 crosses. Fuel: 5 strytium fuel per ship passing through. The ring can then be sabotaged from the far side to stop the Wolf fleet following.",
		},
		"O": {
			"letter": "O", "display_name": "Deep Nebula", "is_new_eden_candidate": true,
			"new_eden_description": "Scout missions can be launched into the nebula if in range; each raises the success chance. To settle, each ship performs a long jump and rolls 1d6 +1 per scouting mission performed here. 9 or more = New Eden reached; otherwise that ship is lost, and each lost ship adds +1 to subsequent ships' rolls. The accumulated bonus must never be shown to players - a Wolf Agent can lie about having scanned the nebula.",
		},
		"P": {
			"letter": "P", "display_name": "Ancient Space Station", "is_new_eden_candidate": true,
			"triggers_wolf_attack_on_arrival": true,
			"wolf_attack_min_battlestations": 1, "wolf_attack_min_capacity": 20,
			"new_eden_description": "On arrival, trigger a Wolf attack with at least 1 battlestation and 20 damage capacity; surviving wolves attack again repeatedly until destroyed. Liberate: defeat all Wolf forces. Power: cannibalise ships with Reactor consoles supplying at least 18 consoles' worth of power.",
		},
	}

	var definitions: Dictionary[String, StarSystemDefinition] = {}
	for letter: String in raw:
		var data := raw[letter].duplicate()
		data["opportunities"] = opportunities_by_letter.get(letter, [])
		definitions[letter] = StarSystemDefinition.from_dict(data)
	return definitions

static var _definitions: Dictionary[String, StarSystemDefinition] = _build_definitions()

static func get_definition(letter: String) -> StarSystemDefinition:
	return _definitions.get(letter)

static func all_letters() -> Array[String]:
	return _definitions.keys()
