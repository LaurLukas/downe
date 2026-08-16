class_name AbilityRegistry
extends RefCounted

## ability_id -> Ability instance. The seam between craft definitions
## (which just list ability ids as data) and behavior. Every id a
## CraftDefinition declares must resolve here - see
## tests/core/craft/craft_roster_test.gd for the table-driven check.

static var _instances: Dictionary[String, Ability] = {
	"cargo_transfer": CargoTransferAbility.new(),
	"boarding_support": BoardingSupportAbility.new(),
	"boarding_support_elite": BoardingSupportEliteAbility.new(),
	"redeploy": RedeployAbility.new(),
	"repair": RepairAbility.new(),
	"recharge": RechargeAbility.new(),
	"scout_system": ScoutSystemAbility.new(),
	"console_upgrade": ConsoleUpgradeAbility.new(),
	"mining_operations": MiningOperationsAbility.new(),
	"resource_harvesting": ResourceHarvestingAbility.new(),
	"away_mission": AwayMissionAbility.new(),
	"combat_table": CombatTableAbility.new(),
}

static func get_ability(ability_id: String) -> Ability:
	return _instances.get(ability_id)

static func has_ability(ability_id: String) -> bool:
	return _instances.has(ability_id)
