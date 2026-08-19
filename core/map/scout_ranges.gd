class_name ScoutRanges
extends RefCounted

## Scout craft and their jump ranges - docs/star_map_tv_display.md §6.6.
## Public information (players can count hops on their own paper
## chart), so surfacing it here is not the constraint-1 violation that
## validating a scout's *reported claim* against it would be - see
## core/craft/abilities/scout_system.gd's own comment on that exact
## distinction, which already deliberately leaves these numbers
## unenforced as a rule. This is reference data for the map's optional
## scout-reach overlay only, keyed by craft id.

const SCOUTS: Dictionary[String, Dictionary] = {
	"starlight": {"label": "STARLIGHT", "jumps": 2, "unlimited": false},
	"hummingbird": {"label": "HUMMINGBIRD", "jumps": 3, "unlimited": false},
	"endeavour": {"label": "ENDEAVOUR", "jumps": -1, "unlimited": true},
}

static func all_scout_craft_ids() -> Array[String]:
	return SCOUTS.keys()

static func label_for(craft_id: String) -> String:
	return SCOUTS.get(craft_id, {}).get("label", craft_id.to_upper())

static func jumps_for(craft_id: String) -> int:
	return SCOUTS.get(craft_id, {}).get("jumps", 0)

static func is_unlimited(craft_id: String) -> bool:
	return SCOUTS.get(craft_id, {}).get("unlimited", false)
