# Task: implement the shuttle layer in `res://core/`

Implement every small craft in DoWNE as data plus a shared ability system. Do not
write a separate hand-rolled class per shuttle, and do not write one giant
`match` over shuttle names. Read the whole brief before writing code.

---

## 1. Architecture requirements

- All of this lives in `res://core/`. Pure GDScript. No `Node`, no scene tree, no
  `get_node`, no signals to UI. The rules engine must be runnable headless.
- Shuttle IDs are lowercase `snake_case` (`black_sheep`, `fighter_wing_alpha`,
  `refinery_124`). Display names (`R.S.S. "Black Sheep"`) come from the existing
  display-name lookup table. Never hardcode a display string inside logic.
- No `print()`. Use the existing logging helper.
- Every mutation goes through the existing state mutation path so the JSON crash
  dump stays accurate.
- Write tests in `res://tests/` for everything you add here.

### Suggested shape (deviate if you have a better reason, and say why)

```
res://core/craft/craft_definitions.gd   # static data: the roster below
res://core/craft/craft_state.gd         # per-craft mutable state
res://core/craft/abilities/             # one small file per ability
res://core/craft/ability_registry.gd    # ability_id -> ability instance
```

Each ability implements the same two methods:

```gdscript
func can_execute(game_state, craft_id, params) -> AbilityCheck
func execute(game_state, craft_id, params) -> AbilityResult
```

`can_execute` returns *why* it failed, not just a bool — the terminal UI needs to
show the player the reason ("not fuelled", "not docked", "insufficient
materials"). Abilities must be pure with respect to randomness: take a seeded RNG
from game state, never call `randi()` directly, so games are reproducible from
the JSON dump.

Definitions are data. A craft is:

```gdscript
{
    "id": "highwall",
    "class": CraftClass.MINING_SHUTTLE,
    "operator_role": "icebreaker_miner",
    "home_ship": "icebreaker",
    "cargo_types": ["materials", "strytium_ore"],
    "abilities": ["cargo_transfer", "mining_operations", "highwall_combat"],
    "away_mission_bonuses": {"mining": 3, "engineering": 2},
    "damage_track": null,
}
```

---

## 2. Shared mechanics (apply to all craft unless stated)

**Fuelling.** Each craft has a boolean `fuelled` flag. A ship's Shuttle Bay
console, during Team Phase Maintenance Step 6, may spend 1 strytium fuel to
refuel one docked shuttle. A damaged Shuttle Bay cannot refuel. The AEGIS has two
bays (Zeta and Omega) and can therefore fuel two shuttles per turn, one per bay.
Any shuttle can fuel in any bay it is docked at. **Unused fuel is lost at end of
turn** — clear the flag in end-of-turn processing whether or not it was spent.
Abilities marked `requires_fuel` are unavailable when the flag is false.

**Docking.** A craft is docked at exactly one ship at a time. Cargo transfer and
most abilities target the docked ship.

**Storage console damage.** When a ship's Storage console is damaged, half its
resources are discarded, *including resources sitting on docked shuttles*. Round
losses down (5 food becomes 3 food — note: this rounds the *remaining* amount up;
implement exactly as the sheet states and add a test for the value 5).

**Cargo transfer.** Moves the craft's permitted `cargo_types` to and from the ship
it is docked at, during the Coordination Phase. Types vary per craft — see the
roster. Security teams count as a transferable type.

**Scout taxi.** A scouting craft may spend one scouting use to ferry up to 2
players between separated parts of the fleet (one use covers the round trip), or
to carry up to 2 strytium fuel instead — each unit of fuel occupies one player
slot.

**Evacuation.** Any craft with cargo transfer can move 5,000 survivors per turn.
No ship may exceed its starting survivor capacity.

---

## 3. Ability catalogue

Implement these once and attach them by ID.

| Ability | Phase | Rules |
|---|---|---|
| `cargo_transfer` | Coordination | Move permitted cargo types to/from the docked ship. |
| `boarding_support` | Wolf Attack, Boarding Action | The docked ship may use its Security Teams to help repel boarders. |
| `boarding_support_elite` | Wolf Attack, Boarding Action | As above, plus re-roll up to 3 dice. Pallas only. |
| `redeploy` | Wolf Attack, start of Boarding Action | `requires_fuel`. Move to any ship of the operator's choice. Pallas and Chepu. |
| `repair` | Coordination | Repair up to 2 consoles on 1 ship, 4 materials each. Alternatively *damage* a console to gain 3 materials — this requires the consent of at least one of that ship's players, so it must be a two-party confirmation in the UI, not a unilateral action. `requires_fuel` extends this to a second ship. |
| `recharge` | Coordination | `requires_fuel`. Charge one console. Consoles whose effect normally triggers in the maintenance cycle trigger immediately instead. |
| `scout_system` | Coordination | Range and uses vary per craft — see roster. |
| `console_upgrade` | Coordination | Upgrade 2 consoles per turn, paying the leftmost unlocked cost in materials from the *target* ship's hold. `requires_fuel` adds 2 more. Endeavour only. |
| `mining_operations` | Coordination | Up to 2 operations. Each operation: roll 1d6 and gain that many materials; roll 3d6 and gain that many strytium ore. `requires_fuel` adds a third operation. **See open question 1.** |
| `resource_harvesting` | Coordination | `requires_fuel`. Roll 2d6. The operator picks one die as food, the other as water. |
| `away_mission` | Away Mission | The craft may join an away mission and contributes its skill bonuses. |
| `combat_table` | Wolf Attack | Per-craft combat profile, below. |

### Combat profiles

**Maliades (Escort Fighter).** Damage track 0–3; destroyed at 3 damage.
- Medium range: shift one Wolf Ship's target number by +1 or −1 (values wrap — a 0
  hits Refinery 124, a 7 hits the AEGIS). May also roll up to 1 die: 1 damage on
  4+, assigned to different targets; takes 1 damage for each roll of 1, 2 or 3.
- Short range: roll up to 2 dice, 1 damage on 2+ to different targets; takes 1
  damage for each roll of 1.
- Repaired for 1 material per damage if fuelled in a Shuttle Bay during Team Phase.

**Highwall (Mining Shuttle).** `requires_fuel` to attend the combat table. At both
medium and short range: roll 1 die, 3 damage to 1 target on 5+.

**Fighter wings.** Track 0–4 fighters (AEGIS Construction Bay builds replacements
at 1 material each up to 4, or 6 when upgraded). Launching requires an undamaged,
charged Fighter Bay — Alpha and Bravo each need one of the AEGIS's two bays;
the P.D.F. wing needs Refinery 124's Fighter Bay. Fighter wings do **not** need a
charged bay to fly away missions. Alpha and Bravo may exchange fighters with each
other during the Coordination Phase.
- Medium range, per fighter, choose one: shift a Wolf Ship's target number ±1
  (same wrap rule), or roll 1 die for 1 damage on 5+.
- Short range: roll up to 1 die per fighter; 1 damage per 3+; 1 fighter destroyed
  per roll of 1 or 2.

---

## 4. The roster

Fourteen shuttles and three fighter wings. Note that several of these differ only
in owner and name — build them from the same ability set, do not duplicate logic.

### Assault shuttles

| ID | Display | Operator | Cargo | Abilities |
|---|---|---|---|---|
| `pallas` | I.C.S.S. "Pallas" | AEGIS Executive Officer | security teams | `cargo_transfer`, `boarding_support_elite`, `redeploy` |
| `chepu` | P.D.S. "Chepu" | Refinery 124 PDF Colonel | security teams | `cargo_transfer`, `boarding_support`, `redeploy` |

### Engineering shuttles — identical abilities, four owners

Cargo: security teams, strytium ore, strytium fuel, food, water, materials.
Abilities: `cargo_transfer`, `boarding_support`, `repair`.

| ID | Display | Operator |
|---|---|---|
| `philia` | F.S. "Philia" | Dione Engineer |
| `chacau` | G.S. "Chacau" | Refinery 124 Engineer |
| `blacksmith` | C.S.S. "Blacksmith" | Icebreaker Engineer |
| `ally` | U.S. "Ally" | Joint Engineering Union Engineer |

### Service shuttles — identical abilities, three owners

Cargo: security teams, strytium ore, strytium fuel, food, water, materials.
Abilities: `cargo_transfer`, `boarding_support`, `recharge`.

| ID | Display | Operator |
|---|---|---|
| `condor` | P.S. "Condor" | Quellon Engineer |
| `black_sheep` | R.S.S. "Black Sheep" | Shepherd Engineer |
| `wobbly` | U.S. "Wobbly" | Joint Engineering Union Engineer |

### Specialist craft — all different

| ID | Display | Operator | Cargo | Abilities and parameters |
|---|---|---|---|---|
| `starlight` | I.C.S.S. "Starlight" | AEGIS Wing Commander | — | `scout_system` (within 2 jumps of the AEGIS's position; `requires_fuel` for a second system), `away_mission` (+3 explore, +1 salvage) |
| `hummingbird` | P.S. "Hummingbird" | Quellon Explorer | food, water | `scout_system` (1/turn, within 3 jumps of the Quellon's position), `cargo_transfer`, `resource_harvesting`, `away_mission` (+3 explore, +1 mining) |
| `endeavour` | R.S.S. "Endeavour" | Shepherd Scientist | — | `scout_system` (1/turn, **any** system regardless of range), `console_upgrade`, `away_mission` (+3 science) |
| `highwall` | C.S.S. "Highwall" | Icebreaker Miner | materials, strytium ore | `cargo_transfer`, `mining_operations`, `combat_table` (Highwall profile), `away_mission` (+3 mining, +2 engineering) |
| `maliades` | F.S.F. "Maliades" | Dione Engineer | — | `combat_table` (Maliades profile), damage track 0–3 |

### Fighter wings

| ID | Display | Operator | Launch requires | Notes |
|---|---|---|---|---|
| `fighter_wing_alpha` | I.C.S.S. Fighter Wing Alpha | AEGIS Wing Commander | AEGIS Fighter Bay Alpha or Bravo, charged and undamaged | 0–4 fighters, exchangeable with Bravo |
| `fighter_wing_bravo` | I.C.S.S. Fighter Wing Bravo | AEGIS Wing Commander | AEGIS Fighter Bay Alpha or Bravo, charged and undamaged | 0–4 fighters, exchangeable with Alpha |
| `pdf_escort_wing` | P.D.F. Escort Fighter Wing | Refinery 124 PDF Commander | Refinery 124 Fighter Bay, charged and undamaged | 0–4 fighters, `away_mission` (+2 search & rescue, +1 salvage). Replacements built only at the AEGIS. |

---

## 5. Hard constraints — do not violate these

- **Scout coordinates are never validated.** The scouting abilities accept
  arbitrary typed input. A Wolf agent operating a scout craft must be able to
  report coordinates that are wrong, and the system must record and display them
  as given. Do not add range checks, plausibility checks, autocomplete, or
  warnings on the coordinate entry path. This is deliberate game design. If you
  think you have found a bug there, you have not.
- **Away missions stay social.** Implement only the arithmetic: card values (A–10
  = +1 to +10, face cards = −5), the shuttle skill bonuses above, and the total.
  Do not implement card dealing, discarding, assignment, or leader selection —
  those happen physically at the table.
- **Wolf attacks stay physical.** Combat profiles are reference data the terminal
  displays and, at most, arithmetic helpers. Do not build an automated combat
  resolver that removes the need for players to gather at the battle table.
- **Host override.** Every value this layer owns — fuel flag, docking, fighter
  count, Maliades damage, cargo contents — must be settable directly by the host
  admin console, bypassing all ability preconditions.

---

## 6. Tests

In `res://tests/`, cover at minimum:

- Fuel flag clears at end of turn whether or not it was consumed.
- A `requires_fuel` ability fails `can_execute` with the correct reason when unfuelled.
- Repair costs 4 materials per console and caps at 2 consoles on 1 ship, 2 ships when fuelled.
- Damaging a console for materials cannot execute without the consent flag set.
- Storage damage halves resources on docked shuttles as well as the ship.
- Cargo transfer rejects a resource type not in the craft's `cargo_types`
  (Hummingbird cannot move materials; Pallas cannot move food).
- Fighter wing cannot launch when its bay is uncharged or damaged, but can still
  join an away mission.
- Maliades is destroyed at exactly 3 damage.
- Every craft in the roster resolves every ability ID it declares against the
  registry — a table-driven test that fails loudly on a typo'd ability name.

---

## 7. Open questions — ask, do not guess

Stop and ask before implementing any of these:

1. **Mining operations.** The card lists two bullets under one operation: roll 1d6
   for materials, and roll 3d6 for strytium ore. It is not clear whether one
   operation yields both, or whether the operator picks one. Ask which.
2. **Cargo and hold capacities.** The printed shuttle resource sheets have tick
   tracks, but the maximum per resource type is not recorded in my source. Ask for
   the per-craft caps and the starting loadouts before writing the storage model;
   use `-1` for "uncapped" as a placeholder in the meantime and leave a `TODO`.
3. **`ally` and `wobbly` home ship.** Both are operated by the Joint Engineering
   Union Engineer. Their starting dock is not specified. Ask.
4. **`endeavour` and `maliades` bay assignment.** Both are shuttles operated by
   crew of ships whose sheets I have, but their home bay is not stated. Ask.

Do not invent numbers for any of the above. A wrong constant that looks plausible
is worse here than a blocking question, because it will survive into playtest and
be mistaken for a rules decision.
