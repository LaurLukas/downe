extends TestCase

## Cross-checks the damage ladder against wolf_ship_definitions.gd's
## already-verified constants (which are themselves cross-checked against
## the real printed Wolf Ship cards - see TODO.md), plus the Strikecarrier/
## Fighter-Wing bonus resolution documented in wolf_damage.gd's own file
## header.

const C := WolfShipDefinitions.Class
const P := WolfShipDefinitions.RangePhase

func test_ladder_matches_the_printed_cards_per_hull() -> void:
	assert_eq(WolfDamage.ladder(C.CRUISER), [0, 1, 2, 3], "Cruiser: rising/decaying shape")
	assert_eq(WolfDamage.ladder(C.FIGHTER_WING), [0, 0, 1, 1], "Fighter Wing: rising/decaying shape")
	assert_eq(WolfDamage.ladder(C.DESTROYER), [1, 1, 1, 2], "Destroyer: flat shape")
	assert_eq(WolfDamage.ladder(C.STRIKECARRIER), [2, 2, 2, 2], "Strikecarrier: flat shape, no live-count baked into the static ladder")
	assert_eq(WolfDamage.ladder(C.ASSAULT_TRANSPORT), [0, 0, 0, 0], "Assault Transport deals 0 direct damage - it contributes boarding parties instead")
	assert_eq(WolfDamage.ladder(C.BATTLESTATION), [3, 3, null, 3], "Battlestation: deadline shape, Short cell is null (cannot be damaged), not 0")

func test_damage_if_destroyed_now_returns_null_when_immune() -> void:
	assert_eq(WolfDamage.damage_if_destroyed_now(C.BATTLESTATION, P.SHORT), null, "Battlestation cannot be destroyed at Short - must be null, not 0, so the token renders '—' not a number")
	assert_eq(WolfDamage.damage_if_destroyed_now(C.BATTLESTATION, P.LONG), 3, "Battlestation deals 3 if destroyed at Long")

func test_damage_if_survives_strikecarrier_is_always_flat() -> void:
	assert_eq(WolfDamage.damage_if_survives(C.STRIKECARRIER, 0), 2, "Strikecarrier's own ceiling with no live Fighter Wings")
	assert_eq(WolfDamage.damage_if_survives(C.STRIKECARRIER, 5), 2, "Strikecarrier's own ceiling must NOT change with live Fighter Wing count - the bonus belongs to the Fighter Wings, not to it")

func test_damage_if_survives_fighter_wing_rises_with_live_strikecarriers() -> void:
	assert_eq(WolfDamage.damage_if_survives(C.FIGHTER_WING, 0), 1, "no live Strikecarrier: base value only")
	assert_eq(WolfDamage.damage_if_survives(C.FIGHTER_WING, 1), 2, "one live Strikecarrier: +1 bonus")
	assert_eq(WolfDamage.damage_if_survives(C.FIGHTER_WING, 3), 4, "three live Strikecarriers: +3 bonus (1 per surviving Strikecarrier)")

func test_damage_if_survives_other_hulls_ignore_the_strikecarrier_count() -> void:
	assert_eq(WolfDamage.damage_if_survives(C.CRUISER, 5), 3, "Cruiser's ceiling is unaffected by live Strikecarriers")
	assert_eq(WolfDamage.damage_if_survives(C.DESTROYER, 5), 2, "Destroyer's ceiling is unaffected by live Strikecarriers")
	assert_eq(WolfDamage.damage_if_survives(C.ASSAULT_TRANSPORT, 5), 0, "Assault Transport's direct-damage ceiling is unaffected (its contribution is boarding parties)")
	assert_eq(WolfDamage.damage_if_survives(C.BATTLESTATION, 5), 3, "Battlestation's ceiling is unaffected by live Strikecarriers")
