# Wolf Attack TV Display — v3: Lane Layout

**Supersedes:** the *layout* sections of `wolf_attack_tv_display_v2_gap_spec.md`
(§4.5 wolf force row, §4.6 range bands, §4.7 attack vectors, §4.8 card chip row, §6 scene tree).

**Still in force from v2:** §2 design tokens, palette, typography, type scale, §4.1–4.4 backdrop /
header / pursuit meter / phase rail, §4.9 footer, §7 Godot implementation notes.

---

## 0. Why the layout changes

The v2 layout put every wolf ship in one horizontal row and drew a bezier from each wolf down to
its target. That works at six wolves and collapses at nine.

What v2 actually produces at 15 wolves:

- The row wraps to a second line, so vertical position no longer means anything
- Curves from row 2 pass straight through row 1's tokens
- A wolf in column 8 targeting ship 1 crosses eleven other curves
- Lane 1's card ends up under a bundle of curves that terminate on four different cards
- Ability text collides with the `SEC N` labels

The failure is not cosmetic. **The single thing the room has to read off this screen — which wolf
is hitting which ship — becomes unreadable at exactly the moment it matters most** (high pursuit,
big attack, everyone crowded round the TV).

Drawing better curves does not fix this. Bundling, edge routing and orthogonal routing all still
produce crossings, because the graph is genuinely many-to-few. The fix is to stop drawing the
relationship and start *encoding it in position*.

---

## 1. The core rule

> **A wolf ship is drawn inside its target's lane. Adjacency replaces vectors.**

Six capital ships → six vertical lanes. Every wolf attacking the AEGIS is drawn in the AEGIS lane,
directly above the AEGIS card. There is no line to trace and nothing to cross, at any ship count.

Two consequences worth stating explicitly, because they are the payoff:

1. **Stack height becomes a threat histogram.** Lanes are bottom-aligned against the impact line,
   so the tallest column is the ship under the heaviest attack. Readable from twenty feet away in
   under a second, with no numbers involved.
2. **`→ SHIPNAME` on each wolf token becomes redundant** and is deleted. So does the attacker chip
   row on the fleet cards (`SC` `CR` `DE` …) — the stack above the card *is* that list, with more
   detail. Both removals buy back the space the stacks need.

---

## 2. Screen anatomy

```
┌────────────────────────────────────────────────────────────────────────────┐
│  WOLF ATTACK                                                    TURN 3     │
│  FORCE 10 + PURSUIT 6 = 16 CAP · 16 COMMITTED       [ pursuit meter ] 6/10 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • TARGETING  —  • LONG  —  ◉ MEDIUM  —  • SHORT  —  • BOARDING  — •RESOLVE│
│  BS×1  SC×1  CR×4  AT×2  DE×3  FW×5   ·   3 DESTROYED          <- tally    │
│                                                                            │
│                                                    ┌──────┐                │
│                        ┌──────┐                    │ tok  │                │
│           ┌──────┐     │ tok  │                    │ tok  │                │
│  ┌──────┐ │ tok  │     │ tok  │     ┌──────┐       │ tok  │                │
│  │ tok  │ │ tok  │     │ tok  │     │ tok  │       │ tok  │                │
│  └──┬───┘ └──┬───┘     └──┬───┘     └──┬───┘       └──┬───┘                │
│ ═══╪════════╪═══════════╪══════════════╪═════════════╪══════════ MEDIUM ══ │
│  ▼ 5 DMG   ▼ 3 DMG      ▼ 6 DMG        ▼ 3 · 4 BP    ▼ 4 DMG    NO CONTACT │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐               │
│  │1 AEGIS│ │2 DIONE│ │3 ICEBR│ │4 QUELL│ │5 SHEPH│ │6 REF124│              │
│  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘ └───────┘               │
│                                                                            │
│              TARGETING WRAPS · 7 → 1 · 0 → 6                               │
│  CANNOT BE TARGETED                                                        │
│  ▲ FW ALPHA 4   ▲ FW BRAVO 3   ▲ PDF ESCORT 4   ▲ GORGONEION SHIELD → 2    │
└────────────────────────────────────────────────────────────────────────────┘
```

Vertical geometry (1920×1080 design space, per v2 §2.1):

| Zone | y range |
|---|---|
| Header (title, stats, pursuit) | 60 → 190 |
| Phase rail | 217 |
| Wolf force tally | 248 |
| **Stack zone** (wolf tokens, bottom-aligned) | 280 → 612 |
| Impact line (active range arc) | 626 |
| Incoming line (per lane) | 652 |
| **Fleet card band** | 666 → 906 |
| Targeting wraps | 944 |
| `CANNOT BE TARGETED` | 982 |
| Untargetable entries | 1018 |

Stack zone is **332px tall**. That is the budget every scaling decision in §5 works within.

---

## 3. Lane specification

A lane is one `Control` per capital ship present in the battle. `N` lanes are distributed across
the content width (`x` 95 → 1825, gap 18).

```gdscript
lane_width = (1730 - (n_lanes - 1) * 18) / n_lanes
```

| N lanes | Lane width |
|---|---|
| 4 | 419 |
| 5 | 328 |
| 6 | 268 |
| 8 | 185 |
| 10 | 145 |

Lane contents, top to bottom:

1. **Stack** — wolf tokens, **bottom-aligned** against the impact line. Grows upward.
2. **Spine** — a vertical `ALERT` line from the bottom token down through the impact line into the
   card's top edge. Width `clamp(incoming_damage, 2, 10)` px. This is the only remaining
   attack-vector graphic, and it can never cross another one.
3. **Incoming line** — derived summary, `y = 652`:
   - Attacked: `▼ 5 DMG` (`ALERT`), or `▼ 3 DMG · 4 BP` when boarding parties are inbound
   - Not attacked: `NO CONTACT` (`INK_GHOST`)
   - The `▼` is `ALERT`, the number `T_DMG_NUM` at 26px, the suffix `T_DMG_SUFFIX`
4. **Fleet card** — as v2 §4.8, with the chip row removed (see §7).

**Lane wash.** Each lane gets a full-height background `ColorRect` in `SHIP_COLOR[id]` at
`alpha ≈ 0.045`, spanning the stack zone only (not the card). This is what binds a stack to its
card at a glance without any line at all. Targeted lanes go to `alpha ≈ 0.07`; untargeted lanes
drop to `0.02`.

**Empty lanes stay.** A ship with no attackers still gets its lane, its wash, its `NO CONTACT`
marker and its card. Who is *safe* is information.

---

## 4. Wolf token

Two forms. Which one is used depends on §5.

### 4.1 Full form — 100px tall

```
      ╱▔▔▔▔╲          silhouette, 52px tall, INK stroke
      CR ○ ● ●        T_WOLF_CODE 30px + pips r4 gap 11
      PREVENTS 2      T_WOLF_ABILITY 18px, ALERT
```

Centred in the lane. Used when stacks are shallow enough to afford it.

### 4.2 Compact form — 34px tall

```
 ╱▔╲  CR  ○ ● ●   P2
 └─┘
```

A single row: 22px glyph, hull code, pips, abbreviated ability. Left-aligned, full lane width,
1px `RULE` border, `CARD_BG` fill, square corners.

Abbreviated ability strings:

| Full | Abbreviated |
|---|---|
| `PREVENTS 2` | `P2` |
| `PREVENTS 4 BP` | `4BP` |
| `SIEGE BATTERY` | `SIEGE` |
| `STOPS FW BUFF` | `FW+` |
| `IMMUNE` | `IMM` |

### 4.3 Content shedding by lane width

Independent of height tier. Narrow lanes drop elements right-to-left:

| Lane width | Compact token contents |
|---|---|
| ≥ 240 | glyph · code · pips · abbreviated ability |
| 180 – 239 | code · pips · abbreviated ability |
| 150 – 179 | code · pips |
| < 150 | code · `2/3` numeric pip summary |

Pips never disappear entirely — remaining hull is the number players are shooting at.

### 4.4 State

| State | Rendering |
|---|---|
| Live | `INK` code, pips per v2 §4.5 step 5, `ALERT` ability |
| Destroyed | Whole token at `alpha 0.3`, code in `INK_GHOST`, all pips hollow, ability replaced by `DESTROYED` in `INK_GHOST`, 1px strikethrough across the token |
| Returns next attack (`BS`, `FW`) | `↻` glyph in `INK_DIM` after the pips |
| Must be targeted first (`FW` during Short) | 1px `CYAN` left edge on the token |

Destroyed tokens **stay in the lane** and sink to the **top** of the stack (furthest from the
card). Live threats cluster against the impact line. This keeps the histogram honest — the stack
shows total commitment, the dense red band at the bottom shows what's still coming.

### 4.5 Ordering within a lane

Bottom (nearest the card) upward:

1. Live wolves, sorted by descending damage capacity (`BS` 6, `SC` 5, `CR` 3, `AT` 2, `DE` 2, `FW` 1)
2. Ties broken by `uid`, **stably**
3. Destroyed wolves, same sort, at the top

Stable ordering is not a nicety. Twenty people are tracking specific tokens on a live display; a
token that jumps position between state pushes will be read as a different ship.

---

## 5. Scaling — the part that has to be right

Two independent axes. Compute both, then render.

```gdscript
var n_lanes: int      = fleet_ships.size()
var max_stack: int    = lanes.map(func(l): return l.wolves.size()).max()
var lane_width: float = (1730.0 - (n_lanes - 1) * 18.0) / n_lanes
```

### 5.1 Height tier from `max_stack`

The tier is chosen from the **busiest lane** and applied to **every** lane. Uniform token size
across lanes is what makes the histogram comparison valid — do not size lanes independently.

| `max_stack` | Tier | Token | Height | Gap | Columns per lane | Stack capacity |
|---|---|---|---|---|---|---|
| 1 – 3 | **A** | Full | 100 | 10 | 1 | 3 |
| 4 – 8 | **B** | Compact | 34 | 6 | 1 | 8 |
| 9 – 16 | **C** | Compact | 30 | 5 | 2 | 16 |
| 17 – 24 | **D** | Compact | 26 | 4 | 3 | 24 |
| 25+ | **D + overflow** | Compact | 26 | 4 | 3 | 23 + `+N MORE` chip |

All tiers fit inside the 332px stack zone. Tier A: `3×100 + 2×10 = 320`. Tier B: `8×34 + 7×6 = 314`.
Tier C: `8 rows × 30 + 7×5 = 275`. Tier D: `8 rows × 26 + 7×4 = 236`.

Multi-column lanes fill **bottom-up, left-to-right**, so the bottom row is always full and the
ragged edge is at the top where it reads as depth rather than as a gap.

### 5.2 Low counts must not look broken

Tier A with one wolf in a lane produces a lot of air. That is fine — do **not** stretch tokens to
fill the zone. Instead:

- Bottom-align, as always. Empty space sits at the top of the stack zone.
- At `max_stack ≤ 2`, raise the impact line to `y = 560` and let the cards grow to 280px tall.
  The screen stays balanced without inventing filler.
- At `n_lanes ≤ 4`, cap `lane_width` at 380 and centre the lane group. Four lanes stretched across
  1730px looks like a bug, not a design.

### 5.3 High lane counts

If small ships ever become targetable (open question — see §11), `n_lanes` can reach 10–11.
Below `lane_width` 150 the cards lose the index number and icon and keep only the colour bar,
name and damage. Below 120, stop adding lanes and split the fleet across two rows of lanes — but
that is a last resort and should be flagged to the host, not silently entered.

---

## 6. Phase behaviour

### 6.1 `targeting` — the staging pool

At the start of the attack no wolf has a target yet, so there are no lanes to put them in.

- Wolves render in a **staging pool**: a centred grid filling the stack zone, ignoring lane
  boundaries, using the tier that `max_stack = ceil(total_wolves / n_lanes)` would select.
- Lane washes are off. Incoming lines read `—`.
- As the host resolves targeting, each wolf gets a `target_ship_id` and **tweens from its pool
  position into its lane** over 0.35s. Resolving targets one at a time and watching the columns
  build is the spectacle this phase should have.
- If the host assigns all targets at once, stagger the tweens 60ms apart.

### 6.2 `long` / `medium` / `short`

- Impact line arc is `CYAN`, labelled at the right end with the active range name (`T_BAND_ACTIVE`).
  It is one arc, not three bands — v2's LONG/MEDIUM/SHORT gutter is deleted (§7).
- Ability text on every token re-derives from `hull + phase` (v2 §4.5 step 8) with no state push.
- On phase change, tween the arc's control points slightly (±14px) so it visibly "settles".
- During `short`, `FW` tokens get the `CYAN` left edge marker — fleet damage must be assigned to
  fighter wings first, and the display should say so without a rules lookup.

### 6.3 `boarding`

Lanes with `boarding_parties > 0` come forward; all others drop to `alpha 0.4`. The incoming line
switches to `4 BP` in a filled `ALERT_DEEP` chip. Wolf `AT` tokens in those lanes pulse.

### 6.4 `resolve`

Destroyed wolves fade to `alpha 0.15`. Each lane's incoming line switches from projected to actual
damage dealt. Cards show their new damage totals.

---

## 7. Deleted from v2

Remove these — they are either now redundant or actively harmful to the lane layout.

| Element | Reason |
|---|---|
| Bezier attack vectors (`AttackVectors` node, v2 §4.7) | Replaced by lane adjacency + spines. Delete the node and its `_draw()`. |
| `→ SHIPNAME` line on wolf tokens | The lane says it. Frees 38px per token. |
| Attacker chip row on fleet cards (`SC` `CR` `DE` …) | The stack above the card is this list, with hull state included. |
| `LONG` / `MEDIUM` / `SHORT` gutter labels and dashed dividers (v2 §4.6) | Range is a global phase, not a spatial position. The phase rail plus one labelled arc carries it. |
| Single wide `WolfForceRow` `HBoxContainer` | Replaced by per-lane stacks. |

**Kept from the cards:** the `N BP` chip. Boarding is a separate resolution step with its own
phase, so it stays visible on the card as well as in the incoming line.

**`SEC N` moves inside the card**, top-right corner, because the 30px above the card is now the
spine's entry point. `T_SEC`, `SHIP_COLOR[id]`.

---

## 8. New — wolf force tally

One line at `y = 248`, `T_STAT`, replacing the overview that the single wolf row used to give:

```
BS×1   SC×1   CR×4   AT×2   DE×3   FW×5   ·   3 DESTROYED
```

- Hull codes in `INK_DIM`, counts in `INK`, `×` in `INK_GHOST`
- Counts are **live** hulls only
- `N DESTROYED` in `INK_GHOST`, omitted when zero
- Left-aligned at `x = 95`

This is the aggregate view players need during Short range when deciding what to shoot. It is
derived, never stored.

---

## 9. Data contract deltas

On top of v2 §5:

```gdscript
{
	# wolf_ships gains nothing structurally, but target_ship_id is now load-bearing:
	# an empty string means "unassigned" and routes the token to the staging pool.
	"wolf_ships": [
		{
			"uid": "wolf_cr_02",       # MUST be stable across pushes — drives token identity
			"hull": "cr",
			"damage_taken": 1,
			"destroyed": false,        # NEW — explicit, not inferred from damage == capacity
			"returns": false,
			"target_ship_id": "aegis", # "" during targeting
		},
	],

	# fleet_ships: "attackers" is REMOVED (the lane derives it).
	# "boarding_parties" stays.
	"fleet_ships": [
		{"id": "aegis", "index": 1, "security": 9, "damage": 5, "boarding_parties": 0},
	],
}
```

Everything the lanes need is derived in the view:

```gdscript
func build_lanes(snapshot: Dictionary) -> Array:
	var by_target := {}
	for w in snapshot.wolf_ships:
		by_target.get_or_add(w.target_ship_id, []).append(w)
	# incoming damage = sum of damage_if_not_destroyed for live wolves in the lane
	# incoming BP     = sum of boarding parties for live AT hulls in the lane
```

`incoming_damage` is a **derived, projected** value — what lands if the fleet destroys nothing
more this phase. Label it as projection, never as a committed number, and recompute it on every
push. It is exactly the arithmetic the host should not be doing in their head.

---

## 10. Scene structure

```
WolfAttackTV (Control, 1920×1080)
├── Backdrop            (unchanged from v2 §4.1)
├── Header              (unchanged from v2 §4.2–4.3)
├── PhaseRail           (unchanged from v2 §4.4)
├── WolfTally           (Label)                     # NEW, §8
├── LaneRow (HBoxContainer, separation 18, x 95→1825)
│   └── Lane × N (Control)
│       ├── Wash        (ColorRect, stack zone only)
│       ├── Stack       (Control — custom layout, bottom-aligned)
│       │   └── WolfToken × M
│       ├── Spine       (Control, custom _draw)
│       ├── IncomingLine(HBoxContainer)
│       └── FleetCard   (PanelContainer — v2 §4.8 minus the chip row)
├── StagingPool (Control)   # visible only during `targeting`
├── ImpactArc   (Control, custom _draw)  # drawn ABOVE lanes, BELOW cards
└── Footer              (unchanged from v2 §4.9)
```

`ImpactArc` spans the full width and is drawn once, not per lane, so it stays a single continuous
curve across all six columns.

---

## 11. Implementation notes

- **Lane layout is manual, not a container.** Stacks are bottom-aligned with a variable child
  count; `VBoxContainer` grows from the top and will fight you. Use a plain `Control` and set
  `position.y = stack_bottom - (rows * row_h + (rows-1) * gap)` per lane.
- **One `_draw()` for all spines**, one for the arc. Do not create a `Line2D` per lane.
- **Token pooling.** Wolf counts change every phase. Instantiate a pool of ~24 `WolfToken` scenes
  once, then show/hide and reposition rather than `queue_free()`-ing and re-instantiating on every
  state push — the latter will hitch visibly on the host laptop.
- **Token identity is `uid`.** When a push arrives, match existing tokens by `uid` and tween them
  to their new slot. Never rebuild the stack from scratch, or every token jumps.
- **Recompute tiers only when the roster changes**, not per frame. Cache `tier`, `lane_width`,
  `row_h` on the lane row and invalidate on push.
- **`core/` stays clean.** Lane grouping, tier selection and projected damage are all view-layer
  derivations from a flat snapshot. `core/` emits wolves with targets; it knows nothing about
  columns. The pure functions (`project_incoming_damage`, `wolf_ability_label`) belong in
  `res://tests/`.
- **The host override path still applies.** The host must be able to reassign a wolf's target from
  the admin console and see the token move lanes. Do not let the lane layout become a read-only
  derivation that the host cannot correct mid-attack.

---

## 12. Bugs visible in the v2 screenshot — fix alongside

1. **`10 CAP · 87 COMMITTED`.** Committed is being summed wrong, or capacity is not being enforced.
   Add the assertion from v2 §4.2 and a host-console warning.
2. **Every wolf is a `BS`.** Fifteen battlestations at 6 capacity each is 90 points against a cap
   of 10 — consistent with the `87 COMMITTED` figure, so the roster builder is likely picking the
   first hull in the table rather than sampling the attack-scaling formula. Check the wolf roster
   generator against the scaling table in `open_questions_answered.md`.
3. **`DESTROYED` replaces the ability text** and drops the token's colour cue entirely. Per §4.4,
   destroyed tokens keep their code and pips and dim as a whole.
4. **`SEC 9` / `SEC 2` labels overlap the wolf ability text.** Resolved by moving `SEC` inside the
   card (§7).
5. **`TARGETING WRAPS` renders behind the fleet cards.** It moves to `y = 944`, below the card
   band, per §2.
6. **Fleet cards 3 and 5 have no border** while the rest do. All six use `card_idle` or
   `card_targeted` from v2 §4.8 — no third state.

---

## 13. Acceptance checklist

Run the display against synthetic rosters and check each:

- [ ] **3 wolves, 6 lanes** — Tier A, full tokens with silhouettes, cards grown to 280px, no dead-looking gaps
- [ ] **8 wolves, 6 lanes** — Tier B, single column, every stack fits without clipping
- [ ] **15 wolves, 6 lanes** — Tier C, two columns per lane, nothing overlaps the impact line
- [ ] **24 wolves, 6 lanes** — Tier D, three columns, still legible at 2m from a 55" panel
- [ ] **30 wolves** — overflow chip appears, no clipping
- [ ] **12 wolves all targeting one ship** — that lane fills, the other five read `NO CONTACT`, and the histogram reads instantly
- [ ] **4 lanes** — lane group centred, capped at 380px wide, not stretched
- [ ] **10 lanes** — cards shed the index and icon, names still readable
- [ ] At every count above, a stranger can point at a wolf token and name its target **without tracing anything**
- [ ] Tallest stack is always the ship with the most attackers
- [ ] Destroyed wolves are visibly dead but still counted in the stack
- [ ] Advancing the phase re-derives every ability label with no state push
- [ ] Reassigning a target from the admin console moves the token to the new lane
- [ ] Tokens do not jump position between two identical state pushes

---

## 14. Open items — do not guess

Carried forward, plus one new:

1. `BS` and `CR` ability labels at **Long** range — still not in any reference.
2. Gorgoneion and Vulcan footer rules.
3. Signature colours for Endeavour, Maliades, Pallas, Voyage 33-0.
4. **Whether small ships appear on the Wolf Attack targeting table.** This now directly sets
   `n_lanes`, so it is the highest-value open question for this screen. Build for N, tune for 6.
5. **NEW — can a single wolf ship split its attack across targets?** Every A4 wolf card reads
   "damage to target", singular, which is what makes the lane partition clean. If any hull or any
   event can retarget mid-attack or hit two ships, the partition breaks and a wolf would need to
   appear in two lanes. Confirm against the Facilitator Guide before this design is locked.
