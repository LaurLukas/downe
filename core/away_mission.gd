class_name AwayMissionOpportunity
extends RefCounted

## Card assignment stays a human negotiation between the Mission Leader
## and the team - this class only automates the scoring arithmetic once
## cards have been assigned. Never pick or assign cards here.
## See CLAUDE.md constraint 2.

enum Skill { EXPLORATION, MINING, SALVAGE, SCIENCE, ENGINEERING, SEARCH_AND_RESCUE }

var skill: Skill
var difficulty: int

func _init(mission_skill: Skill, mission_difficulty: int) -> void:
	skill = mission_skill
	difficulty = mission_difficulty

## rank is "A", "2".."10", "J", "Q", or "K".
static func card_value(rank: String) -> int:
	match rank:
		"A":
			return 1
		"J", "Q", "K":
			return -5
		_:
			return int(rank)

static func score(cards: Array[String], shuttle_bonus: int = 0) -> int:
	var total := shuttle_bonus
	for rank in cards:
		total += card_value(rank)
	return total
