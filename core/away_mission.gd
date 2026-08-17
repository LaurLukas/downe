class_name AwayMissionOpportunity
extends RefCounted

## Card assignment stays a human negotiation between the Mission Leader
## and the team - this class only automates the scoring arithmetic once
## cards have been assigned. Never pick or assign cards here.
## See CLAUDE.md constraint 2.

enum Skill { EXPLORATION, MINING, SALVAGE, SCIENCE, ENGINEERING, SEARCH_AND_RESCUE }

## Which skills satisfy this opportunity - almost always exactly one,
## but system C's "20 mining and exploration" opportunity accepts
## either (open_questions_answered.md §1.2).
var skills: Array[Skill] = []

## "Difficulty written X/Y means X = success threshold, Y = critical
## threshold. A single number means that opportunity has no critical
## tier" - source doc §1.2. critical_threshold of -1 means no crit tier.
var difficulty: int
var critical_threshold: int = -1

var reward_description: String = ""
var critical_reward_description: String = ""

## True only for system K's opportunity: its difficulty is secretly
## rolled at runtime and never disclosed to players - see
## StarSystem.roll_hidden_difficulty(). difficulty/critical_threshold
## are meaningless on the definition itself when this is set; the real
## values live on the per-game StarSystem instance once rolled.
var hidden_until_rolled: bool = false

func _init(mission_skills: Array[Skill], mission_difficulty: int, crit: int = -1, reward: String = "", critical_reward: String = "", hidden: bool = false) -> void:
	skills = mission_skills
	difficulty = mission_difficulty
	critical_threshold = crit
	reward_description = reward
	critical_reward_description = critical_reward
	hidden_until_rolled = hidden

func accepts_skill(skill: Skill) -> bool:
	return skill in skills

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

static func is_success(mission_score: int, mission_difficulty: int) -> bool:
	return mission_score >= mission_difficulty

## A critical_threshold of -1 (no critical tier) is never met, however
## high the score.
static func is_critical(mission_score: int, mission_critical_threshold: int) -> bool:
	return mission_critical_threshold >= 0 and mission_score >= mission_critical_threshold
