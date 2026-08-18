class_name CraftDefinitions
extends RefCounted

## The fixed roster: 14 shuttles + 3 fighter wings, all built from the
## same data shape and the same shared ability set - never one
## hand-rolled class per shuttle. Source:
## downe_shuttle_implementation_prompt.md §4 (abilities, bonuses),
## cross-checked against ships.md's "Small craft index".
##
## Ally and Wobbly's home ships, and Endeavour/Maliades's home ships,
## were open questions in the brief - resolved directly with the user:
## ally -> Quellon, wobbly -> Shepherd, endeavour -> Shepherd,
## maliades -> Dione.

const _ALL_RESOURCES: Array[ResourceStock.Kind] = [
	ResourceStock.Kind.STRYTIUM_ORE, ResourceStock.Kind.STRYTIUM_FUEL,
	ResourceStock.Kind.FOOD, ResourceStock.Kind.WATER,
	ResourceStock.Kind.MATERIALS, ResourceStock.Kind.SECURITY_TEAMS,
]
const _SECURITY_TEAMS_ONLY: Array[ResourceStock.Kind] = [ResourceStock.Kind.SECURITY_TEAMS]

const _RAW_ROSTER: Array[Dictionary] = [
	# --- Assault shuttles ---
	{
		"id": "pallas", "display_name": "I.C.S.S. \"Pallas\"",
		"class": CraftDefinition.Class.ASSAULT_SHUTTLE,
		"home_ship": "aegis", "operator_role": "aegis_executive_officer",
		"cargo_types": _SECURITY_TEAMS_ONLY,
		"abilities": ["cargo_transfer", "boarding_support_elite", "redeploy"],
	},
	{
		"id": "chepu", "display_name": "P.D.S. \"Chepu\"",
		"class": CraftDefinition.Class.ASSAULT_SHUTTLE,
		"home_ship": "refinery_124", "operator_role": "refinery_124_pdf_colonel",
		"cargo_types": _SECURITY_TEAMS_ONLY,
		"abilities": ["cargo_transfer", "boarding_support", "redeploy"],
	},
	# --- Engineering shuttles: identical abilities, four owners ---
	{
		"id": "philia", "display_name": "F.S. \"Philia\"",
		"class": CraftDefinition.Class.ENGINEERING_SHUTTLE,
		"home_ship": "dione", "operator_role": "dione_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "repair"],
	},
	{
		"id": "chacau", "display_name": "G.S. \"Chacau\"",
		"class": CraftDefinition.Class.ENGINEERING_SHUTTLE,
		"home_ship": "refinery_124", "operator_role": "refinery_124_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "repair"],
	},
	{
		"id": "blacksmith", "display_name": "C.S.S. \"Blacksmith\"",
		"class": CraftDefinition.Class.ENGINEERING_SHUTTLE,
		"home_ship": "icebreaker", "operator_role": "icebreaker_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "repair"],
	},
	{
		"id": "ally", "display_name": "U.S. \"Ally\"",
		"class": CraftDefinition.Class.ENGINEERING_SHUTTLE,
		"home_ship": "quellon", "operator_role": "joint_engineering_union_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "repair"],
	},
	# --- Service shuttles: identical abilities, three owners ---
	{
		"id": "condor", "display_name": "P.S. \"Condor\"",
		"class": CraftDefinition.Class.SERVICE_SHUTTLE,
		"home_ship": "quellon", "operator_role": "quellon_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "recharge"],
	},
	{
		"id": "black_sheep", "display_name": "R.S.S. \"Black Sheep\"",
		"class": CraftDefinition.Class.SERVICE_SHUTTLE,
		"home_ship": "shepherd", "operator_role": "shepherd_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "recharge"],
	},
	{
		"id": "wobbly", "display_name": "U.S. \"Wobbly\"",
		"class": CraftDefinition.Class.SERVICE_SHUTTLE,
		"home_ship": "shepherd", "operator_role": "joint_engineering_union_engineer",
		"cargo_types": _ALL_RESOURCES,
		"abilities": ["cargo_transfer", "boarding_support", "recharge"],
	},
	# --- Specialist craft: all different ---
	{
		"id": "starlight", "display_name": "I.C.S.S. \"Starlight\"",
		"class": CraftDefinition.Class.EXPLORATION_SHUTTLE,
		"home_ship": "aegis", "operator_role": "aegis_wing_commander",
		"cargo_types": [],
		"abilities": ["scout_system", "away_mission"],
		"away_mission_bonuses": {
			AwayMissionOpportunity.Skill.EXPLORATION: 3,
			AwayMissionOpportunity.Skill.SALVAGE: 1,
		},
	},
	{
		"id": "hummingbird", "display_name": "P.S. \"Hummingbird\"",
		"class": CraftDefinition.Class.EXPLORATION_SHUTTLE,
		"home_ship": "quellon", "operator_role": "quellon_explorer",
		"cargo_types": [ResourceStock.Kind.FOOD, ResourceStock.Kind.WATER],
		"abilities": ["scout_system", "cargo_transfer", "resource_harvesting", "away_mission"],
		"away_mission_bonuses": {
			AwayMissionOpportunity.Skill.EXPLORATION: 3,
			AwayMissionOpportunity.Skill.MINING: 1,
		},
	},
	{
		"id": "endeavour", "display_name": "R.S.S. \"Endeavour\"",
		"class": CraftDefinition.Class.SCIENCE_SHUTTLE,
		"home_ship": "shepherd", "operator_role": "shepherd_scientist",
		"cargo_types": [],
		"abilities": ["scout_system", "console_upgrade", "away_mission"],
		"away_mission_bonuses": {AwayMissionOpportunity.Skill.SCIENCE: 3},
	},
	{
		"id": "highwall", "display_name": "C.S.S. \"Highwall\"",
		"class": CraftDefinition.Class.MINING_SHUTTLE,
		"home_ship": "icebreaker", "operator_role": "icebreaker_miner",
		"cargo_types": [ResourceStock.Kind.MATERIALS, ResourceStock.Kind.STRYTIUM_ORE],
		"abilities": ["cargo_transfer", "mining_operations", "combat_table", "away_mission"],
		"away_mission_bonuses": {
			AwayMissionOpportunity.Skill.MINING: 3,
			AwayMissionOpportunity.Skill.ENGINEERING: 2,
		},
	},
	{
		"id": "maliades", "display_name": "F.S.F. \"Maliades\"",
		"class": CraftDefinition.Class.ESCORT_FIGHTER,
		"home_ship": "dione", "operator_role": "dione_engineer",
		"cargo_types": [],
		"abilities": ["combat_table"],
		"max_combat_damage": 3,
	},
	# --- Fighter wings ---
	{
		"id": "fighter_wing_alpha", "display_name": "I.C.S.S. Fighter Wing Alpha",
		"short_name": "FW ALPHA",
		"class": CraftDefinition.Class.FIGHTER_WING,
		"home_ship": "aegis", "operator_role": "aegis_wing_commander",
		"cargo_types": [],
		"abilities": ["combat_table", "away_mission"],
		"max_fighters": 4,
	},
	{
		"id": "fighter_wing_bravo", "display_name": "I.C.S.S. Fighter Wing Bravo",
		"short_name": "FW BRAVO",
		"class": CraftDefinition.Class.FIGHTER_WING,
		"home_ship": "aegis", "operator_role": "aegis_wing_commander",
		"cargo_types": [],
		"abilities": ["combat_table", "away_mission"],
		"max_fighters": 4,
	},
	{
		"id": "pdf_escort_wing", "display_name": "P.D.F. Escort Fighter Wing",
		"short_name": "PDF ESCORT",
		"class": CraftDefinition.Class.FIGHTER_WING,
		"home_ship": "refinery_124", "operator_role": "refinery_124_pdf_commander",
		"cargo_types": [],
		"abilities": ["combat_table", "away_mission"],
		"away_mission_bonuses": {
			AwayMissionOpportunity.Skill.SEARCH_AND_RESCUE: 2,
			AwayMissionOpportunity.Skill.SALVAGE: 1,
		},
		"max_fighters": 4,
	},
]

static var _definitions: Dictionary[String, CraftDefinition] = _build_definitions()

static func _build_definitions() -> Dictionary[String, CraftDefinition]:
	var result: Dictionary[String, CraftDefinition] = {}
	for raw: Dictionary in _RAW_ROSTER:
		var definition := CraftDefinition.from_dict(raw)
		result[definition.id] = definition
	return result

static func get_definition(craft_id: String) -> CraftDefinition:
	return _definitions.get(craft_id)

static func all_craft_ids() -> Array[String]:
	return _definitions.keys()
