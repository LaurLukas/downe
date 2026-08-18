# Wolf Attack — Damage Ladder

**Addendum to** `wolf_attack_tv_display_v3_lanes.md`.
**Replaces:** the `PREVENTS N` ability line (v2 §4.5 step 8, v3 §4.1–4.3) and the lane incoming
line (v3 §3 item 3).

Everything else in v2 and v3 — tokens, tiers, lanes, palette, typography — is unchanged.

---

## 1. The problem with `PREVENTS N`

`PREVENTS N` is derived per phase, so the same wolf ship shows a different number at Long, Medium
and Short. That is arithmetically correct and tactically useless, because it collapses three
genuinely different threat shapes into one number whose meaning silently changes underfoot.

A player looking at `PREVENTS 1` cannot tell whether they are looking at:

- a **Cruiser at Short range**, which was worth 3 at Long and has already lost most of its value, or
- a **Destroyer at any range**, which will still be worth exactly 1 next phase and can safely wait

Those two ships demand opposite decisions and currently render identically.

The information players actually need is *when* a kill pays off, not *how much* it pays off right
now. That is a curve, not a scalar.

---

## 2. The real damage curves

Read directly off the A4 Double Sided wolf cards. This table is the source of everything below.

| Hull | Kill @ Long | Kill @ Medium | Kill @ Short | Survives | Shape |
|---|---|---|---|---|---|
| `CR` Cruiser | 0 | 1 | 2 | 3 | **Decaying** |
| `FW` Fighter Wing | 0 | 0 | 1 | 1 + returns | **Decaying** |
| `BS` Battlestation | 3 | 3 | *cannot be damaged* | 3 + returns | **Deadline** |
| `SC` Strikecarrier | 2 | 2 | 2 | 2 + (1 × each live FW) | **Flat + conditional** |
| `DE` Destroyer | 1 | 1 | 1 | 2 | **Flat** |
| `AT` Assault Transport | 0 | 0 | 0 | 4 BP | **Flat** |

Three shapes, three different decisions:

- **Decaying** (`CR`, `FW`) — value bleeds away each phase. Kill early or don't bother.
  Note `FW`: killing it at Short range prevents **zero** damage. It only stops the return.
  At Long or Medium it prevents the full point. This is invisible under `PREVENTS N` and is
  probably the single most valuable thing this screen can teach.
- **Deadline** (`BS`) — damage is 3 no matter what you do. Killing it never reduces damage; it
  only prevents the return. And it cannot be damaged at Short at all, so the opportunity expires.
- **Flat** (`SC`, `DE`, `AT`) — worth the same in every phase. These are the ships that can safely
  be left until later, and nothing on the current screen says so.

---

## 3. The ladder

Replace the single red ability line with a **four-cell ladder**: Long, Medium, Short, Survives.

```
        ╱▔▔▔▔╲
        CR  ○ ● ●
        0  ·  1  ·  2  ·  3
              ▔▔▔
```

Cell meaning: *the total damage this wolf ship deals to its target if it is destroyed during that
phase.* The fourth cell is the damage if it is never destroyed.

### 3.1 Cell states

| Cell | Colour | Treatment |
|---|---|---|
| Phase already passed | `INK_GHOST` | Opportunity gone |
| **Current phase** | `CYAN` | 1px `CYAN` box, `T_WOLF_ABILITY` +2px |
| Future phase | `INK_DIM` | — |
| Survives (4th cell) | `ALERT` | Always, in every phase |
| Unavailable (`BS` at Short) | `INK_GHOST` | Rendered as `—`, not a number |

Separators are `·` in `INK_GHOST`.

### 3.2 Why this works without instructions

The **shape of the number sequence carries the tactic**:

```
CR   0 · 1 · 2 · 3      rising   → kill it now, value is bleeding
DE   1 · 1 · 1 · 2      flat     → no rush, worth the same later
BS   3 · 3 · — · 3      dead-end → killing it never helps the damage total
FW   0 · 0 · 1 · 1      rising   → free to kill early, pointless at Short
```

No legend, no glossary, no `P2` shorthand to explain during rules. A player who has never seen the
screen can compare two columns of digits and reach the right conclusion. This also means new hull
types or small-ship variants need no new vocabulary.

### 3.3 Badges

The named abilities (`SIEGE BATTERY`, `STOPS FW BUFF`, `IMMUNE`) stop being the primary line and
become compact badges to the right of the pips:

| Badge | Hull | Meaning |
|---|---|---|
| `↻` | `BS`, `FW` | Returns in the next Wolf Attack if not destroyed |
| `4BP` | `AT` | 4 boarding parties in the Boarding Phase. `ALERT_DEEP` filled chip. |
| `+3` | `SC` | Every surviving Wolf FW does +1 damage. **The number is live** — it is the current count of undestroyed Wolf Fighter Wings across the whole battle, not a constant. |
| `⊘S` | `BS` | Cannot be damaged at Short range. Redundant with the `—` cell; use only at Tier A. |

The `SC` badge is worth calling out: its value genuinely changes as fighter wings die, so
`SC ●●●●● +3` becoming `SC ●●●●● +1` over the course of an attack is real, live information that
no card or paper track can give the room.

---

## 4. Ladder rendering by tier

Ladders cost vertical space, so they degrade with the tiers already defined in v3 §5.1.

| Tier | Ladder form | Height cost |
|---|---|---|
| **A** (≤3 per lane) | Full ladder with `L M S ✕` headers above the cells | +34px (token 100 → 118) |
| **B** (4–8) | Four cells, no headers, current cell boxed | +0 — replaces the ability line in the same 34px row |
| **C** (9–16) | Two values: `now ▸ survives`, e.g. `1▸3` | +0 |
| **D** (17+) | Survives value only, in `ALERT` | +0 |

Tier A with headers:

```
   L    M    S    ✕
   0    1    2    3
        ▔▔▔
```

Tier B inline, full width of a 268px lane:

```
 ╱▔╲  CR  ○●●   0·1·2·3
 └─┘              ▔
```

Tier C/D collapse: `now` is the current phase's cell, `survives` is the fourth cell. When they are
equal (`DE` at Short: `1▸2`, `BS`: `3▸3`) the pair still reads correctly.

**Tier A height change:** tokens grow from 100 to 118px, so Tier A capacity drops from 3 to
**2 per lane** within the 332px stack zone (`2×118 + 10 = 246`). Move the Tier A/B boundary
accordingly: Tier A at `max_stack ≤ 2`, Tier B at `3–8`.

---

## 5. Lane incoming line — floor and ceiling

The lane summary currently reads `▼ 5 DMG`, a single projection. Replace it with a range plus a
bar, so the lane shows **how much of the incoming damage is still preventable**.

```
▼ 9                          <- ceiling: damage if nothing more is destroyed
████████░░░░░░░░             <- solid = floor, outlined = preventable this phase
```

- **Floor** = `sum(damage_if_destroyed_this_phase)` across live wolves in the lane.
  The best possible outcome even with perfect shooting this phase. Cannot be reduced.
- **Ceiling** = `sum(damage_if_survives)` across live wolves in the lane.
- **Bar**: lane width, 4px tall, at `y = 660`. Solid `ALERT` for the floor portion, 1px outlined
  `ALERT` at `alpha 0.35` for the preventable remainder.
- **Number**: the ceiling, `T_DMG_NUM` 26px, `ALERT`, prefixed `▼`.
- Boarding parties append as a separate `ALERT_DEEP` chip: `▼ 9 · 4BP`.
- No attackers: `NO CONTACT`, `INK_GHOST`, no bar.

The bar answers the room's actual question — *is it worth firing at this lane at all?* A lane whose
bar is almost entirely solid is already committed and the fleet's shots are better spent elsewhere.
That is arithmetic the host should never be doing by hand.

---

## 6. Phase behaviour

| Phase | Ladder |
|---|---|
| `targeting` | Full ladder, **no cell boxed**. Nothing is committed yet. |
| `long` / `medium` / `short` | Current phase cell boxed in `CYAN`, earlier cells `INK_GHOST` |
| `boarding` | Ladder dims to `alpha 0.4`; `4BP` badges come forward in `ALERT_DEEP` |
| `resolve` | Ladder replaced by the **actual** outcome: the realised cell in `CYAN`, all others `INK_GHOST` |

At `resolve`, showing which cell actually landed closes the loop and teaches the curve for next
time — players see that the Cruiser they left alive cost them the full 3.

---

## 7. A design line worth holding

`CLAUDE.md`: *a change that makes the software cleverer but the room quieter is a regression.*

The ladder removes **arithmetic** — six hulls × three phases of card lookups that a host or player
would otherwise do by hand. That is squarely the goal of this project.

It would be one small step further to add verdict labels (`ACT NOW`, `CAN WAIT`), auto-sort tokens
by urgency, or highlight the recommended target. **Don't.** Target priority is one of the better
arguments in a Wolf Attack — it is where players with different ships and different information
have to negotiate, and it is exactly the player-to-player interaction the display exists to
support. Ranking targets would resolve that argument silently.

The rule to apply:

- **Rules facts are fair game.** The `—` in the Battlestation's Short cell is on the card. Showing
  it saves a lookup. Same for `↻` and `4BP`.
- **Derived arithmetic is fair game.** Floor, ceiling, live FW buff count — all mechanical.
- **Judgments stay in the room.** No urgency labels, no recommended targets, no sorting by threat
  value, no colour-coding tokens by "how much you should care."

Token ordering within a lane stays as v3 §4.5 — descending hull capacity, stable by `uid`. It is a
fixed, explicable rule, not a live recommendation.

---

## 8. Data contract

No new fields. Everything is derived in the view from `hull`, `phase` and the live roster.

```gdscript
# res://core/wolf_damage.gd  — pure, testable, no Node references

const LADDER := {
	#        long, medium, short, survives      null = cannot be destroyed in that phase
	"bs": {"cells": [3, 3, null, 3], "returns": true},
	"sc": {"cells": [2, 2, 2, 2],    "fw_buff": true},
	"cr": {"cells": [0, 1, 2, 3]},
	"at": {"cells": [0, 0, 0, 0],    "boarding_parties": 4},
	"de": {"cells": [1, 1, 1, 2]},
	"fw": {"cells": [0, 0, 1, 1],    "returns": true},
}

static func ladder(hull: String) -> Array:
	return LADDER[hull].cells

static func damage_if_destroyed_now(hull: String, phase: String) -> int
static func damage_if_survives(hull: String, live_fw_count: int) -> int
static func lane_floor(wolves: Array, phase: String) -> int
static func lane_ceiling(wolves: Array, live_fw_count: int) -> int
```

`damage_if_survives` takes `live_fw_count` because the Strikecarrier's contribution is
`2 + live_fw_count`, and each live `FW`'s own contribution rises by 1 while any `SC` survives.
**Get the double-count right:** the `+1` per fighter wing is a buff *to the fighter wings*, so it
belongs to the `FW` rows, not the `SC` row. The `SC` badge displays it for legibility but must not
add it to its own ceiling.

All four functions are pure and belong in `res://tests/`. The lane floor/ceiling pair in particular
is worth a table-driven test against hand-computed rosters — it is the number the room will trust.

---

## 9. Acceptance checklist

- [ ] A Cruiser at Long shows `0·1·2·3` with the first cell boxed
- [ ] The same Cruiser at Short shows `0·1·2·3` with the third cell boxed and the first two greyed
- [ ] A Battlestation shows `—` in the Short cell, never a number
- [ ] A Fighter Wing at Medium visibly shows that killing it now costs the wolves 1 and killing it at Short costs them 0
- [ ] A Strikecarrier's `+N` badge decreases as Wolf Fighter Wings are destroyed, live, with no state push beyond the roster
- [ ] Lane bars: a lane of three Destroyers is mostly solid; a lane of three Cruisers at Long is mostly outlined
- [ ] Tier A capacity is 2 per lane, not 3, after the height increase
- [ ] At Tier C the ladder collapses to `1▸3` and still reads correctly when both values are equal
- [ ] At `resolve`, each token shows which cell actually landed
- [ ] No token anywhere carries a verdict, ranking, or recommendation

---

## 10. Open item — verify before building

**When does wolf damage actually land?**

The cards are written as *"if destroyed during Long Range: 1 damage to target"*, which reads two
ways:

1. **Damage resolves at the end of the attack**, and the phase of destruction only determines the
   amount. The ladder is a lookup for a single end-of-attack total.
2. **Damage lands at the moment of destruction**, and surviving ships deal their damage at Resolve.
   The ladder is a schedule, and fleet cards should increment their `DMG` totals phase by phase.

Both give the identical ladder, so §3–§5 hold either way. But they differ in whether the fleet card
damage numbers tick up during the attack or all at once at Resolve — which is a visible, spectacle-
relevant difference on a TV twenty people are watching.

Check the Facilitator Guide's Wolf Attack resolution sequence before wiring the card damage
animation. Do not guess.
