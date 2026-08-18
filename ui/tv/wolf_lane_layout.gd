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

## Tier A splits in two for the damage ladder redesign
## (docs/wolf_attack_damage_ladder.md §4), per the user's explicit call to
## follow the handoff README's deviation from the spec's own literal §4
## (which would have moved the whole A/B boundary to ≤2 - see TODO.md):
## - "A" (≤2): full 118px token, ladder cells WITH `L M S ✕` headers -
##   the extra 34px (100→118) is exactly the header row's height.
## - "A2" (exactly 3): stays 100px like the original v3 tier A (unchanged
##   arithmetic: 3×100 + 2×10 = 320 ≤ 332), ladder cells with NO headers,
##   replacing the single ability line in the same vertical budget it used
##   to occupy - "so the common board still looks like the live game."
## B/C/D/D+ are unchanged from v3.
const TIERS: Array[Dictionary] = [
	{"min": 1, "max": 2, "name": "A", "form": "full", "height": 118.0, "gap": 10.0, "cols": 1, "capacity": 2, "ladder_headers": true},
	{"min": 3, "max": 3, "name": "A2", "form": "full", "height": 100.0, "gap": 10.0, "cols": 1, "capacity": 3, "ladder_headers": false},
	{"min": 4, "max": 8, "name": "B", "form": "compact", "height": 34.0, "gap": 6.0, "cols": 1, "capacity": 8, "ladder_headers": false},
	{"min": 9, "max": 16, "name": "C", "form": "compact", "height": 30.0, "gap": 5.0, "cols": 2, "capacity": 16, "ladder_headers": false},
	{"min": 17, "max": 24, "name": "D", "form": "compact", "height": 26.0, "gap": 4.0, "cols": 3, "capacity": 24, "ladder_headers": false},
	{"min": 25, "max": -1, "name": "D+", "form": "compact", "height": 26.0, "gap": 4.0, "cols": 3, "capacity": 23, "ladder_headers": false},
]

## String phase name (as used throughout this ui/ layer, e.g.
## WolfAttackView's "range_long") -> the core/ RangePhase enum the damage
## ladder needs. Only the three range phases index into a ladder; callers
## must check has() before using this for "targeting"/"boarding"/etc.
const RANGE_PHASE_BY_NAME: Dictionary[String, WolfShipDefinitions.RangePhase] = {
	"range_long": WolfShipDefinitions.RangePhase.LONG,
	"range_medium": WolfShipDefinitions.RangePhase.MEDIUM,
	"range_short": WolfShipDefinitions.RangePhase.SHORT,
}

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

## Attack-wide (not lane-scoped) count of still-live Strikecarriers -
## matches core/combat/wolf_attack.gd's compute_damage_tally()'s own
## "surviving_strikecarriers" scope exactly (the Fighter Wing bonus
## applies fleet-wide, not per-lane). Takes the full wolf_ships array from
## the view, not one lane's wolves.
static func live_strikecarrier_count(wolf_ships: Array) -> int:
	var count := 0
	for wolf: Dictionary in wolf_ships:
		if wolf.get("destroyed", false):
			continue
		if String(wolf.get("class", "")) == "strikecarrier":
			count += 1
	return count

## Ceiling: total damage this lane takes if the fleet destroys nothing
## more this phase - sum of WolfDamage.damage_if_survives() for every
## still-live wolf in the lane (§5's "ceiling"; replaces v3's
## incoming_damage_for_lane(), same projection rule: recomputed on every
## push, never stored). live_strikecarrier_count must be the attack-wide
## count from live_strikecarrier_count() above, not this lane's own count -
## the Fighter Wing bonus applies fleet-wide.
static func lane_ceiling(wolves: Array, live_strikecarrier_count: int) -> int:
	var total := 0
	for wolf: Dictionary in wolves:
		if wolf.get("destroyed", false):
			continue
		var wolf_class: WolfShipDefinitions.Class = WolfShipDefinitions.Class.get(String(wolf.get("class", "")).to_upper(), -1)
		total += WolfDamage.damage_if_survives(wolf_class, live_strikecarrier_count)
	return total

## Floor: the best possible outcome even with perfect shooting this phase
## - sum of WolfDamage.damage_if_destroyed_now() for every still-live wolf
## in the lane, at the given (string) phase name. Cannot be reduced
## further this phase; §5's "floor". Wolves immune this phase (Battlestation
## at Short) contribute 0 to the floor - killing them isn't an option this
## phase, so there is no way to realize their damage early. "targeting" has
## no range phase yet (nothing has been shot at), so the floor is always 0
## there - the whole ceiling is still preventable in principle.
static func lane_floor(wolves: Array, phase_name: String) -> int:
	if not RANGE_PHASE_BY_NAME.has(phase_name):
		return 0
	var range_phase: WolfShipDefinitions.RangePhase = RANGE_PHASE_BY_NAME[phase_name]
	var total := 0
	for wolf: Dictionary in wolves:
		if wolf.get("destroyed", false):
			continue
		var wolf_class: WolfShipDefinitions.Class = WolfShipDefinitions.Class.get(String(wolf.get("class", "")).to_upper(), -1)
		var dmg = WolfDamage.damage_if_destroyed_now(wolf_class, range_phase)
		if dmg != null:
			total += dmg
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

## §3.3 badges, replacing the old PREVENTS-N ability line entirely. Each
## is a small pure query on one wolf dict (plus, for the Strikecarrier
## buff, the attack-wide live Fighter Wing count) - the caller decides how
## to render them, this file just says which apply and what number to show.

## ↻ - returns in the next Wolf Attack if it survives this one. Never
## shown once destroyed (a destroyed ship isn't returning).
static func badge_returns(wolf: Dictionary) -> bool:
	if wolf.get("destroyed", false):
		return false
	return WolfShipDefinitions.returns_if_survives(
		WolfShipDefinitions.Class.get(String(wolf.get("class", "")).to_upper(), -1))

## 4BP - Assault Transport's boarding parties if it survives. 0 (falsy)
## for every other hull or once destroyed.
static func badge_boarding_parties(wolf: Dictionary) -> int:
	if wolf.get("destroyed", false):
		return 0
	if String(wolf.get("class", "")) != "assault_transport":
		return 0
	return _assault_transport_boarders()

## +N - Strikecarrier only, live (not stored) count of undestroyed Wolf
## Fighter Wings across the whole attack right now - "the number is live"
## per spec §3.3. 0 for every other hull or once destroyed (a destroyed
## Strikecarrier isn't buffing anything).
static func badge_fw_buff(wolf: Dictionary, live_fighter_wing_count: int) -> int:
	if wolf.get("destroyed", false):
		return 0
	if String(wolf.get("class", "")) != "strikecarrier":
		return 0
	return live_fighter_wing_count

## ⊘S - Battlestation cannot be damaged at Short range. Redundant with the
## ladder's own Short cell already showing "—" (spec says show only at
## Tier A, where there's room for the extra badge).
static func badge_cannot_be_damaged_at_short(wolf: Dictionary) -> bool:
	if wolf.get("destroyed", false):
		return false
	return String(wolf.get("class", "")) == "battlestation"

## --- damage ladder (spec §3) ----------------------------------------

## The 4 cell VALUES for one wolf: [long, medium, short, survives].
## long/medium/short are Variant (int or null - null means "cannot be
## destroyed this phase", render as "—"). survives is the live-adjusted
## int - see core/wolf_damage.gd's file header for why only that cell
## needs live_strikecarrier_count and the other three never do.
static func ladder_cell_values(wolf: Dictionary, live_strikecarrier_count: int) -> Array:
	var wolf_class: WolfShipDefinitions.Class = WolfShipDefinitions.Class.get(String(wolf.get("class", "")).to_upper(), -1)
	var cells: Array = []
	for phase in [WolfShipDefinitions.RangePhase.LONG, WolfShipDefinitions.RangePhase.MEDIUM, WolfShipDefinitions.RangePhase.SHORT]:
		cells.append(WolfDamage.damage_if_destroyed_now(wolf_class, phase))
	cells.append(WolfDamage.damage_if_survives(wolf_class, live_strikecarrier_count))
	return cells

## Which ladder cell index is "current" (to box in CYAN) for a still-live
## wolf at this phase - -1 during "targeting" or any non-range phase,
## since nothing is committed yet (spec §6).
static func current_cell_index(phase_name: String) -> int:
	match phase_name:
		"range_long":
			return 0
		"range_medium":
			return 1
		"range_short":
			return 2
		_:
			return -1

enum CellState { PASSED, CURRENT, FUTURE, REALISED, GHOSTED, SURVIVES_LIVE, SURVIVES_GHOSTED }

## Per-cell render STATE (not colour - that's the caller's job, this file
## stays free of any WolfAttackTokens/visual dependency) for a wolf's
## 4-cell ladder, given the current phase name. Array[CellState] of
## length 4 (long, medium, short, survives).
##
## Once a wolf is destroyed its outcome is locked in regardless of what
## phase is current NOW - it shows its actual realised cell (REALISED),
## every other cell GHOSTED, survives SURVIVES_GHOSTED (it didn't survive).
## This is spec §6's "resolve" treatment, extended here to any phase a
## wolf is already destroyed in, not just the final resolution phase -
## see wolf_attack_display.gd's file header for why this project's actual
## "resolve" phase doesn't render lanes at all yet (a pre-existing v3
## scope gap, not something this pass expands).
static func ladder_cell_states(wolf: Dictionary, phase_name: String) -> Array:
	var destroyed: bool = wolf.get("destroyed", false)
	var destroyed_at: int = wolf.get("destroyed_at_phase", -1)
	var states: Array = []

	if destroyed:
		for i in 3:
			states.append(CellState.REALISED if i == destroyed_at else CellState.GHOSTED)
		states.append(CellState.SURVIVES_GHOSTED)
		return states

	var current := current_cell_index(phase_name)
	for i in 3:
		if current == -1 or i > current:
			states.append(CellState.FUTURE)
		elif i == current:
			states.append(CellState.CURRENT)
		else:
			states.append(CellState.PASSED)
	states.append(CellState.SURVIVES_LIVE)
	return states
