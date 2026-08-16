class_name StarSystem
extends RefCounted

var id: String  ## Letter: "A", "B", "C", ...
var description: String
var away_missions: Array[AwayMissionOpportunity] = []

func _init(system_id: String, system_description: String = "") -> void:
	id = system_id
	description = system_description

func add_mission(opportunity: AwayMissionOpportunity) -> void:
	away_missions.append(opportunity)
