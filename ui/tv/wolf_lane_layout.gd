class_name WolfLaneLayout
extends RefCounted

## Pure derivations for the Wolf Attack v3 lane layout - see
## ui/design_handoff_wolf_attack_lanes/wolf_attack_tv_display_v3_lanes.md.
## No Node/scene access anywhere in this file, so it's testable the same
## headless way core/ is (tests/ui/wolf_lane_layout_test.gd), even though
## it lives in ui/ rather than core/ - it's still view-layer derivation
## from WolfAttackView's flat snapshot (lane grouping, tier selection,
## ordering, projected damage), which the spec's own §11 explicitly says
## belongs outside core/, not inside it.
##
## Staging pool key: a wolf with no "target" key, or an empty "target"
## string, groups under STAGING_POOL_KEY. In this project's actual
## WolfAttack state machine (core/combat/wolf_attack.gd), every wolf's
## target is pre-rolled the instant it's added and revealed in full the
## moment the attack leaves Phase.INCOMING - there is no incremental
## "resolving one at a time" targeting flow, so in practice no wolf ever
## reaches the "targeting" phase with an empty target_ship_id. The staging
## pool render path below is still implemented correctly (defensively) for
## a wolf that genuinely has none, but it will not be exercised by this
## game's real target-reveal mechanics - see TODO.md.
const STAGING_POOL_KEY := ""

const TIERS: Array[Dictionary] = [
	{"min": 1, "max": 3, "name": "A", "form": "full", "height": 100.0, "gap": 10.0, "cols": 1, "capacity": 3},
	{"min": 4, "max": 8, "name": "B", "form": "compact", "height": 34.0, "gap": 6.0, "cols": 1, "capacity": 8},
	{"min": 9, "max": 16, "name": "C", "form": "compact", "height": 30.0, "gap": 5.0, "cols": 2, "capacity": 16},
	{"min": 17, "max": 24, "name": "D", "form": "compact", "height": 26.0, "gap": 4.0, "cols": 3, "capacity": 24},
	{"min": 25, "max": -1, "name": "D+", "form": "compact", "height": 26.0, "gap": 4.0, "cols": 3, "capacity": 23},
]

const CONTENT_WIDTH := 1730.0
const LANE_GAP := 18.0
const CAPPED_LANE_WIDTH_N_MAX := 4
const CAPPED_LANE_WIDTH := 380.0

## Damage capacity used for the descending-capacity sort - matches
## core/combat/wolf_ship_definitions.gd's CAPACITY table exactly (kept as
## a local mirror so this file needs only the class-name string, not a
## core/ import, though core/ is already safe to reference from ui/).
const HULL_CAPACITY: Dictionary[String, int] = {
	"battlestation": 6, "strikecarrier": 5, "cruiser": 3,
	"assault_transport": 2, "destroyer": 2, "fighter_wing": 1,
}

## Orders fleet ships left-to-right by the Wolf Attack Sheet's own
## targeting-die order (1 AEGIS, 2 Dione, 3 Icebreaker, 4 Quellon,
## 5 Shepherd, 6 Refinery 124), not ShipRegistry's display order - those
## two orders disagree (ShipRegistry lists Shepherd before Quellon, for
## its own reasons elsewhere in the project), and this v3 layout's whole
## point is that lane position IS the ship, so a lane sitting in the
## wrong slot relative to its own printed index number is a real bug,
## not a cosmetic one - the fleet card would show a truthful index number
## sitting in the wrong physical position. Bug found from real use, not
## synthetic testing (TODO.md).
static func sort_fleet_ships_by_targeting_order(fleet_ships: Array) -> Array:
	var sorted: Array = fleet_ships.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _targeting_index(a["id"]) < _targeting_index(b["id"]))
	return sorted

static func _targeting_index(ship_id: String) -> int:
	var key: Variant = WolfShipDefinitions.TARGETING_TABLE.find_key(ship_id)
	return key if key != null else 999

## Groups wolves by target_ship_id. Every id in fleet_ship_ids gets an
## entry, even if empty, so empty lanes still render (§3: "who is safe is
## information"). Untargeted wolves (empty/missing "target") collect under
## STAGING_POOL_KEY.
static func group_by_lane(wolf_ships: Array, fleet_ship_ids: Array) -> Dictionary:
	var lanes: Dictionary = {STAGING_POOL_KEY: []}
	for ship_id in fleet_ship_ids:
		lanes[ship_id] = []
	for wolf: Dictionary in wolf_ships:
		var target: String = wolf.get("target", "")
		if target.is_empty() or not lanes.has(target):
			lanes[STAGING_POOL_KEY].append(wolf)
		else:
			lanes[target].append(wolf)
	return lanes

## Bottom-to-top order within one lane (index 0 = nearest the card):
## live wolves by descending capacity then ascending uid (a fully
## deterministic secondary key, so identical snapshots always produce the
## identical order - "stably" per the spec, not re-shuffled between
## pushes), then destroyed wolves the same way, at the top.
static func order_lane(wolves: Array) -> Array:
	var live: Array = []
	var destroyed: Array = []
	for wolf: Dictionary in wolves:
		if wolf.get("destroyed", false):
			destroyed.append(wolf)
		else:
			live.append(wolf)
	live.sort_custom(_capacity_then_uid)
	destroyed.sort_custom(_capacity_then_uid)
	var out: Array = []
	out.append_array(live)
	out.append_array(destroyed)
	return out

static func _capacity_then_uid(a: Dictionary, b: Dictionary) -> bool:
	var cap_a: int = HULL_CAPACITY.get(a.get("class", ""), 0)
	var cap_b: int = HULL_CAPACITY.get(b.get("class", ""), 0)
	if cap_a != cap_b:
		return cap_a > cap_b
	return String(a.get("id", "")) < String(b.get("id", ""))

## The busiest real fleet-ship lane, excluding the staging pool - the
## tier is chosen from this single number and applied to every lane.
static func max_stack(lanes: Dictionary) -> int:
	var highest := 0
	for ship_id in lanes:
		if ship_id == STAGING_POOL_KEY:
			continue
		highest = maxi(highest, (lanes[ship_id] as Array).size())
	return highest

static func tier_for(stack: int) -> Dictionary:
	for tier: Dictionary in TIERS:
		if stack >= tier["min"] and (tier["max"] == -1 or stack <= tier["max"]):
			return tier
	return TIERS[0]

## §3: lane_width = (1730 - (n-1)*18) / n, capped at 380 and centred when
## n_lanes <= 4 (the cap/centre-instead-of-stretch rule from §5.2 - the
## caller does the centring, this just returns the width to use). This
## project's real Wolf Attack targeting table only ever produces exactly
## 6 lanes (TODO.md - small ships are never valid targets), so the n<=4/
## n>=8 branches here are defensive per the spec's own "build for N, tune
## for 6" instruction rather than something real play will exercise.
static func lane_width_for(n_lanes: int) -> float:
	if n_lanes <= 0:
		return CAPPED_LANE_WIDTH
	var width: float = (CONTENT_WIDTH - float(n_lanes - 1) * LANE_GAP) / float(n_lanes)
	if n_lanes <= CAPPED_LANE_WIDTH_N_MAX:
		width = minf(width, CAPPED_LANE_WIDTH)
	return width

## §2/§5.2: the roomy case. At max_stack <= 2 the impact line rises and
## cards grow, so a lane with one or two full-form tokens doesn't read as
## a bug - a lot of empty air with nothing to fill it.
static func stack_zone_geometry(stack: int) -> Dictionary:
	if stack <= 2:
		return {"impact_y": 560.0, "card_top": 626.0, "card_height": 280.0}
	return {"impact_y": 626.0, "card_top": 666.0, "card_height": 240.0}

## Content-shedding level for the compact token form, independent of
## height tier (§4.3): 0 = silhouette+code+pips+ability, 1 = code+pips+
## ability, 2 = code+pips only, 3 = code + numeric "taken/capacity".
static func compact_content_level(lane_width: float) -> int:
	if lane_width >= 240.0:
		return 0
	if lane_width >= 180.0:
		return 1
	if lane_width >= 150.0:
		return 2
	return 3

## Column-major bottom-up-left-to-right slot for stack index k (0 =
## bottom-most / nearest the card): row = k / cols, col = k % cols. The
## caller turns (col, row) into a pixel offset from the lane's bottom-left.
static func stack_slot(k: int, cols: int) -> Vector2i:
	var safe_cols := maxi(cols, 1)
	return Vector2i(k % safe_cols, k / safe_cols)

## How many tokens to actually draw vs. fold into a "+N MORE" chip. Only
## the 25+ tier's capacity (23, one slot short of tier D's 24) can ever
## trigger this in practice, but it's evaluated generically per lane so a
## single overloaded lane inside an otherwise-quiet attack still folds
## correctly rather than overflowing its own column budget.
static func lane_display_slots(wolf_count: int, tier: Dictionary) -> Dictionary:
	var capacity: int = tier.get("capacity", wolf_count)
	if wolf_count <= capacity:
		return {"shown": wolf_count, "overflow": 0}
	var shown: int = maxi(capacity - 1, 0)
	return {"shown": shown, "overflow": wolf_count - shown}

## Projected damage this lane takes if the fleet destroys nothing more
## this phase - sum of DAMAGE_IF_SURVIVES for every still-live wolf in the
## lane, phase-independent by design (survives-damage is a hull constant,
## not a per-range value - only "prevents" varies by phase, and that's a
## different number shown on the token itself, not here). A projection,
## never a committed fact - recomputed on every push, never stored.
static func incoming_damage_for_lane(wolves: Array) -> int:
	var total := 0
	for wolf: Dictionary in wolves:
		if wolf.get("destroyed", false):
			continue
		total += WolfShipDefinitions.DAMAGE_IF_SURVIVES.get(
			WolfShipDefinitions.Class.get(String(wolf.get("class", "")).to_upper(), -1), 0)
	return total

## Projected boarding parties, same projection rule, derived from hull
## class directly rather than core's WolfAttackView "boarders" field -
## that field is only populated once attack.phase is one of the three
## range phases (WolfAttackView._build_wolf_ships' in_range_phase gate),
## so during "targeting" it always reads 0 even for an Assault Transport
## that already has a target. Deriving from the hull constant instead
## (Assault Transport always contributes 4 if it survives) makes the
## incoming line correct at every STANDING phase, targeting included -
## the same class of fix TODO.md already records once for the v2 fleet
## card's boarding chip (wrong field name there; here it's the right
## field read at a phase where core hasn't populated it yet).
static func incoming_bp_for_lane(wolves: Array) -> int:
	var total := 0
	for wolf: Dictionary in wolves:
		if wolf.get("destroyed", false):
			continue
		if String(wolf.get("class", "")) != "assault_transport":
			continue
		total += _assault_transport_boarders()
	return total

## The boarding-party count an Assault Transport contributes if it
## survives to the end of the attack - a fixed hull constant (4), not a
## per-attack value, so it never needs a WolfShipState to look up.
static func _assault_transport_boarders() -> int:
	return WolfShipDefinitions.BOARDING_PARTIES_IF_SURVIVES.get(
		WolfShipDefinitions.Class.ASSAULT_TRANSPORT, 0)

## Full-form ability text, mirroring the v2 wolf-item logic exactly (same
## "prevents"/"immune_this_phase" fields core already computes per
## current range phase) - not a hardcoded per-hull string, since e.g. a
## Cruiser's real "PREVENTS N" number changes across Long/Medium/Short.
## Assault Transport's boarding-party count is the one exception: it's
## derived from the hull constant (_assault_transport_boarders()), not
## read from core's own "boarders" field - that field is only populated
## once attack.phase is one of the three range phases
## (WolfAttackView._build_wolf_ships' in_range_phase gate), so reading it
## directly would print "PREVENTS 0 BP" during "targeting" for a wolf
## that already has a real target and a real (always-4) boarding count.
## Same class of fix as incoming_bp_for_lane() above, applied here too.
static func ability_label_full(wolf: Dictionary) -> String:
	if wolf.get("destroyed", false):
		return "DESTROYED"
	if wolf.get("immune_this_phase", false):
		return "IMMUNE"
	match String(wolf.get("class", "")):
		"battlestation":
			return "SIEGE BATTERY"
		"strikecarrier":
			return "STOPS FW BUFF"
		"assault_transport":
			return "PREVENTS %d BP" % _assault_transport_boarders()
		_:
			var prevents = wolf.get("prevents")
			return "PREVENTS %d" % prevents if prevents != null else ""

## Compact-form abbreviation of the same label (§4.2's table).
static func ability_abbrev(wolf: Dictionary) -> String:
	if wolf.get("destroyed", false):
		return "DEAD"
	if wolf.get("immune_this_phase", false):
		return "IMM"
	match String(wolf.get("class", "")):
		"battlestation":
			return "SIEGE"
		"strikecarrier":
			return "FW+"
		"assault_transport":
			return "%dBP" % _assault_transport_boarders()
		_:
			var prevents = wolf.get("prevents")
			return "P%d" % prevents if prevents != null else ""
