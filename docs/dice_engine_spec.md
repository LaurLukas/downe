# DoWNE — Digital Dice Engine

**Status:** specification, not yet implemented
**Audience:** a coding agent with no prior context on this project
**Depends on:** `res://core/` rules engine, `res://net/` WebSocket transport
**Blocks:** maintenance cycle automation, jump resolution, Wolf Attack weapon resolution

---

## 1. Why this exists

DoWNE is a physical megagame for ~20 players run by a single facilitator. Every
die in the tabletop original is a d6. Across six capital ships, six small ships,
and eight turns, the host currently supervises several hundred physical rolls per
session, most of them buried inside a per-ship maintenance cycle that nobody else
at the table is watching.

Physical dice are being retired **as the default** because they are the largest
remaining source of administrative drag. They may be reintroduced later as a
per-roll option (see §10), so the engine must not assume it is the only source of
truth about a roll's outcome.

### The thing that will go wrong if this is built carelessly

Some players in this game are secret Wolf agents. The social texture of the game
is accusation and suspicion. **The moment a player rolls badly, they will accuse
the software of cheating**, and unlike a physical die there is no shared object on
the table to point at.

This is not a paranoid edge case, it is the expected failure mode. Every design
decision below that looks like unnecessary ceremony — showing individual die
faces, printing the arithmetic, keeping an append-only log, marking host
overrides visibly — exists to defuse it. Do not simplify these away in the name of
a cleaner UI. A dice engine that produces correct numbers but that players do not
trust has failed at its actual job.

---

## 2. Hard constraints

1. **All randomness is server-side.** The Godot host laptop rolls. Clients never
   call `Math.random()`. A browser terminal is a page a player controls; a player
   who can reroll from devtools is a player who will.
2. **Every roll is d6.** There are no other die types anywhere in DoWNE. Do not
   build a generic dice notation parser. If a future rule needs d10, add it then.
3. **Individual faces are always transmitted and always displayed.** Never send
   only a total or only an outcome.
4. **The arithmetic is shown, not just the answer.** `4 + 2 = 6, +9 rations = 15`.
   The engine's purpose is removing the burden of arithmetic, not hiding it.
5. **The host can override any roll**, and an overridden roll is visibly marked as
   overridden. The software never silently misreports a result.
6. **No CDN, no external assets.** The game runs on an offline travel router. Dice
   faces are inline SVG. No dice libraries, no web fonts, no sprite sheets.
7. **`core/` stays pure.** The dice module is `RefCounted`. No `Node`, no
   `get_tree()`, no `Engine`, no scene references. It must run under
   `godot --headless`.
8. **RNG state is serialised with game state.** See §6.

---

## 3. The three roll shapes

Every roll in DoWNE reduces to one of three shapes. The dice module implements
exactly these and nothing more.

### 3.1 `roll(n)` — the primitive

Returns `n` face values. The caller interprets them. Used where the rule is a
simple comparison the rules module already owns.

### 3.2 `sum_band(n, modifier, thresholds)` — sum against ordered bands

Roll `n` dice, add `modifier`, classify the total into a band. `thresholds` is an
ascending array of cut points; the returned `band` is the index of the first
threshold the total falls under, or `thresholds.size()` if it exceeds them all.

Used only by the unrest roll, but that is the single most frequent roll in the
game, so it earns its own function.

### 3.3 `count_successes(n, target)` — count faces at or above a target

Roll `n` dice, count how many are `>= target`. Used by Wolf Attack weapons and
salvage.

---

## 4. Roll catalogue

Every roll currently known to exist. Ship-specific numbers vary; the values below
are shapes, not constants. Anything marked ⚠ is an open question, see §10.

| Reason key | Shape | Dice | Detail |
|---|---|---|---|
| `maintenance_unrest` | `sum_band` | 2 | Modifier is food ration bonus **plus** water ration bonus (both apply, additively). Thresholds `[12, 20]`. Band 0 → gain 2 unrest, band 1 → gain 1 unrest, band 2 → gain nothing. |
| `maintenance_riot` | `roll` | 1 | Face **strictly less than** current unrest → riot. Capital ships take 1 damage. Small/extra ships lose population equal to the face value and skip the charging step this turn. |
| `jump_attempt` | `roll` | 1 | Damaged jump drive fails on 1–3. Damaged **and** upgraded fails only on 1. ⚠ Whether an undamaged drive rolls at all is unresolved. |
| `weapon_fire` | `count_successes` | varies | e.g. Laser Cannon: 2 dice, each 1 damage on 4+. Fires separately at medium and at short range — two distinct rolls, two distinct phases, never batched. |
| `salvage_drones` | `count_successes` | varies | R.S.S. Warrior, after a Wolf Attack. One die per point of damage dealt **by either side** during the attack. Each 5+ yields 1 material. Requires the Wolf Attack module to expose a combined damage total. |

### Not dice, do not add dice to these

- **Away missions** resolve by card assignment and player negotiation. Automate the
  scoring arithmetic only. Never add a die.
- **Scouting** produces coordinates typed freely by a player who may be lying.
  Never add a die, a validation, or an accuracy check.

---

## 5. Core API

`res://core/dice.gd`

```gdscript
class_name Dice
extends RefCounted

# --- construction -------------------------------------------------

func _init(seed_value: int = 0) -> void

# --- rolling ------------------------------------------------------

## Roll n six-sided dice. Returns face values in roll order.
func roll(n: int) -> PackedInt32Array

## Roll n dice, add modifier, classify total against ascending thresholds.
## Returns { faces, modifier, total, band }
func sum_band(n: int, modifier: int, thresholds: PackedInt32Array) -> Dictionary

## Roll n dice, count faces >= target.
## Returns { faces, target, successes }
func count_successes(n: int, target: int) -> Dictionary

# --- persistence --------------------------------------------------

func serialise() -> Dictionary        # { seed, state, sequence }
func restore(data: Dictionary) -> void
```

The dice module does **not** know about ships, unrest, damage, or phases. It does
not decide what a band means. It does not write to the log. It returns numbers.

A thin wrapper in the rules layer — `core/roll_service.gd` — owns the
game-meaningful part: it takes a reason key and context, calls `Dice`, stamps the
result with `roll_id` / `turn` / `ship`, appends to the audit log, and emits a
signal the network layer picks up.

Keeping these separate is what lets the dice module be tested with a fixed seed
and no game state at all.

---

## 6. RNG and crash recovery

Use a `RandomNumberGenerator` instance, not the global `randi()`. It is
`RefCounted`, which keeps `core/` pure, and — more importantly — its `seed` and
`state` are both readable and writable.

The project dumps full game state to JSON on every mutation, because the failure
mode being defended against is twenty people standing in a room while the host
restarts something. A roll is a mutation. Therefore:

- `seed` and `state` are both written into every state dump.
- On restore, both are set back. The stream continues where it left off rather
  than restarting.
- **The roll result is persisted before it is broadcast.** A crash between rolling
  and displaying must not produce a different number on recovery.

Without this, a host restart silently rerolls, and a player who lost 1,500
survivors to a riot gets a different answer the second time. That is the single
worst thing this module could do.

Seed at game start from `randomize()`-equivalent entropy and record the seed in
the session log. A fixed seed via a launch flag is useful for testing and should
be supported.

Maintain a monotonic `sequence` integer, incremented on every roll, serialised
alongside. It is the primary key for the audit log and makes gaps visible.

---

## 7. Protocol

Flat JSON with a `type` field, consistent with the rest of the project. Payloads
stay small — the same messages will be parsed by ESP32-S3 terminals on limited
RAM, so no nesting beyond one level and no verbose keys.

### Client → server

```json
{ "type": "roll_request", "ship": "icebreaker", "reason": "maintenance_unrest" }
```

The client never specifies dice count, modifier, or thresholds. Those come from
ship state the server already holds. A client that could specify its own modifier
is a client that can cheat.

### Server → client

```json
{
  "type": "roll_result",
  "id": 47,
  "ship": "icebreaker",
  "reason": "maintenance_unrest",
  "faces": [3, 5],
  "mod": 12,
  "total": 20,
  "band": 2,
  "text": "No unrest gained",
  "over": false
}
```

- `text` is a short human-readable outcome computed server-side, so the ESP32
  firmware does not need to embed rules logic.
- `over` is `true` if the host overrode this roll.
- For `count_successes` rolls, `band` is replaced by `hits` and `target`.

### Host → server

```json
{ "type": "roll_override", "id": 47, "faces": [6, 6] }
```

Recomputes the outcome from the supplied faces and rebroadcasts with
`"over": true`. The original result stays in the audit log; overrides append,
never overwrite.

---

## 8. Client rendering

Applies to the browser terminal (`res://web/`) and, in simplified form, to the
ESP32 terminals.

### Sequence

1. Player taps the roll control. Control disables immediately to prevent
   double-fire.
2. `roll_request` goes out. Server responds, typically within a few milliseconds
   on the local router.
3. **The client already knows the true result before the animation starts.** It
   animates toward a known answer. It does not animate and then find out.
4. Tumble for **600–800 ms**: swap each die through random faces at roughly 12 fps.
   Long enough to register as an event, short enough that six ships doing it in
   parallel does not stall the turn.
5. Settle on true faces. Brief highlight on successes where the roll shape has
   them.
6. Print the arithmetic below the dice, always:
   `3 + 5 = 8` then `+12 rations` then `= 20` then the outcome sentence.

### Rendering

- Faces are inline SVG. Seven pip positions, standard d6 layout, per-face pip
  subset. This is about thirty lines of JS and has no dependencies.
- Dice are white with dark pips **regardless of ship colour**. In this project
  colour is identity, not decoration, and red belongs exclusively to the Wolves.
  Never tint a die with a ship's signature colour and never render a red die.
- Honour `prefers-reduced-motion`: skip the tumble, show the result.
- On a settled result, an "overridden by host" marker appears if `over` is true.
  Small, unmissable, not apologetic.

### Roll log

A scrollable list on each terminal showing that ship's last ~20 rolls: sequence
number, reason, faces, outcome. This is the artefact a suspicious player is
pointed at. It costs almost nothing to build and it is the entire reason the
"software is cheating" argument dies quickly.

### Wolf Attack rolls go to the TV

Weapon rolls happen during a physical gathering at the battle map. Those results
mirror to the Wolf Attack TV display as well as the originating terminal.
A roll nobody watching the TV can see is a roll that did not happen, as far as the
spectacle is concerned.

---

## 9. Testing

Run headless: `godot --headless --script res://tests/run_tests.gd`

- Fixed seed produces an identical sequence across runs.
- `serialise()` → `restore()` → next roll matches the uninterrupted sequence.
- Uniformity: 60,000 rolls, each face within a reasonable tolerance of 10,000.
  This is a smoke test against a broken range, not a serious RNG audit.
- Band classification at every boundary: totals of 11, 12, 19, 20 land in the
  expected bands. Off-by-one here silently distorts the whole economy.
- `count_successes` with target 4 and target 5, including all-fail and all-hit.
- Override recomputes the outcome and preserves the original log entry.

---

## 10. Open questions

Flagged rather than guessed at. Each needs a human decision before the dependent
code is written.

1. **Does an undamaged jump drive roll at all?** The console text only specifies
   failure ranges for the damaged state. If undamaged jumps are automatic, the
   roll should be skipped entirely rather than rolled and discarded.
2. **At unrest 0, the riot roll can never trigger.** Skip it, or roll anyway so
   players can see the system is not quietly deciding things for them? Leaning
   toward rolling anyway — the ceremony is cheap and the transparency is not.
3. **Should players see that the host overrode a roll?** The spec above says yes
   and marks it visibly. The counter-argument is that visible overrides undermine
   the host's ability to quietly fix a mistake. Worth a decision.
4. **Survivor loss per point of damage** is still unresolved project-wide and
   blocks the riot outcome text on small ships.
5. **Who triggers a Wolf Attack weapon roll** — the ship's own terminal, or the
   host at the battle map? Affects whether `roll_request` needs an authorisation
   check on that reason key.
6. **Salvage Drones needs a combined damage total** from the Wolf Attack module,
   counting both sides. Confirm that module exposes one.
7. **Reintroducing physical dice per-roll.** If a table wants to roll the unrest
   dice by hand, the terminal needs a "enter result manually" path. Design the
   `roll_result` message now so a manually entered roll is representable — most
   likely a `source` field with values `engine` / `manual` / `override` — even if
   the UI for it is not built yet. Retrofitting this later means touching the
   ESP32 firmware.

---

## 11. Design note for whoever implements this

The temptation with a dice module is to make it clever: weighted fairness
correction, streak breaking, "feels random" adjustment. **Do none of it.** This is
a game about players lying to each other. The one thing in the room that must be
provably not lying is the die.
