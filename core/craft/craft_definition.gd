class_name CraftDefinition
extends RefCounted

## Static description of one craft (shuttle or fighter wing) - data,
## not behavior. Built via from_dict() so the roster in
## craft_definitions.gd can stay close to
## downe_shuttle_implementation_prompt.md §1's example shape.

enum Class {
	ASSAULT_SHUTTLE,
	ENGINEERING_SHUTTLE,
	SERVICE_SHUTTLE,
	EXPLORATION_SHUTTLE,
	SCIENCE_SHUTTLE,
	MINING_SHUTTLE,
	ESCORT_FIGHTER,
	FIGHTER_WING,
}

var id: String = ""
var display_name: String = ""
## Short form for space-constrained displays (the Wolf Attack TV footer's
## "CANNOT BE TARGETED" strip - see wolf_attack_tv_display_v2_gap_spec.md
## §4.9). Defaults to display_name for craft that never need shortening.
var short_name: String = ""
var craft_class: Class = Class.ENGINEERING_SHUTTLE
var home_ship: String = ""
var operator_role: String = ""
var cargo_types: Array[ResourceStock.Kind] = []
var ability_ids: Array[String] = []
var away_mission_bonuses: Dictionary[AwayMissionOpportunity.Skill, int] = {}

## -1 means this craft has no combat damage track (either it doesn't
## fight, or - like the Highwall - it fights without a stated track in
## the source). Fighter wings track losses via max_fighters instead.
var max_combat_damage: int = -1

## -1 means "not a fighter wing".
var max_fighters: int = -1

static func from_dict(data: Dictionary) -> CraftDefinition:
	var definition := CraftDefinition.new()
	definition.id = data["id"]
	definition.display_name = data["display_name"]
	definition.short_name = data.get("short_name", definition.display_name)
	definition.craft_class = data["class"]
	definition.home_ship = data["home_ship"]
	definition.operator_role = data["operator_role"]
	definition.cargo_types.assign(data.get("cargo_types", []))
	definition.ability_ids.assign(data.get("abilities", []))
	for skill: AwayMissionOpportunity.Skill in data.get("away_mission_bonuses", {}):
		definition.away_mission_bonuses[skill] = data["away_mission_bonuses"][skill]
	definition.max_combat_damage = data.get("max_combat_damage", -1)
	definition.max_fighters = data.get("max_fighters", -1)
	return definition
