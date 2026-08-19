# Star Map TV — visual implementation notes

**Companion to** `star_map_tv_display.md` (the authority on data model, projection and C1–C5) and
`star_charts.json`. This document is the *rendering* layer only: exact geometry, colour semantics,
node/token composition and the collision rules that fall out of them. Where it differs from
§5–§6 of the display spec, this document wins — it is derived from a built and measured
1920×1080 reference (`Star Map.dc.html`).

Nothing here changes the projection contract (§7) except the four additive fields listed in §9.

---

## 1. What problem this pass solves

Playtest read of the first implementation, verbatim: *"functionally alright but not great. Hard to
see where players are. Hard to see where the wolves are. Not sure what the yellow line is and it's
hard to see. If the screen is bad the numbers will not be seen."*

Four fixes, in priority order:

1. **One colour, one meaning.** Cyan is *us*, red is *wolves*, amber is *unverified claim*,
   violet is *hazard*. No colour does two jobs. This is the single highest-value change.
2. **The fleet is a beacon, not a pip.** Locator ring + corner brackets + halo + a ship-silhouette
   token. Findable from the back of the room in under a second.
3. **Wolves are loud.** Red ring + red halo + a text chip naming the threat, plus a rail block
   counting them.
4. **Numbers survive a bad panel.** Every coordinate is ≥20px, set *inside* its node where the node
   is otherwise empty, so nothing floats loose over an edge line. No text anywhere below 18px.

Plus a permanent **legend bar** across the bottom. The room should never have to ask what a line
means.

---

## 2. Canvas geometry

1920×1080, fixed. No responsive behaviour.

```
y   0.. 68   title bar
y  74..955   map canvas (bands span this exactly)
y 962..996   band scale labels
y 1020..1068 legend bar
x  30..1380  map region        x 1400..1890  info rail
```

### 2.1 Node placement

Paper rotated 90° CW as per display spec §5.1. Do not re-lay-out. The mapping:

```gdscript
const NODE_ORIGIN := Vector2(80, 112)
const NODE_SPAN   := Vector2(1250, 812)

func node_screen_pos(u: float, v: float) -> Vector2:
	return NODE_ORIGIN + Vector2(u * NODE_SPAN.x, v * NODE_SPAN.y)
```

Scale factors are 1.353 (u) and 0.617 (v) against paper px — *not* uniform, unlike the earlier
1.153/1.152 proposal. This is deliberate: the earlier uniform mapping left the deepest tiers
crushed against the rail and wasted 200px of vertical. Edge *angles* shift but every relative
position (left/right/above/below, which band, which neighbours) is preserved, which is what
players actually correlate against paper. Verified against all 41 edges: no crossings introduced,
minimum node-centre separation **163px** (6964↔6943).

Resulting positions, for test fixtures:

| Node | x | y | Node | x | y |
|---|---|---|---|---|---|
| 0000 | 80 | 525 | 3068 | 915 | 338 |
| 1413 | 230 | 629 | 6943 | 915 | 924 |
| 5143 | 322 | 359 | 0853 | 942 | 631 |
| 0488 | 404 | 780 | 2580 | 969 | 112 |
| 6837 | 433 | 523 | 1964 | 1073 | 799 |
| 9997 | 471 | 200 | 6798 | 1107 | 205 |
| 6931 | 592 | 367 | 8378 | 1137 | 551 |
| 4454 | 626 | 683 | 4888 | 1240 | 903 |
| 1096 | 757 | 470 | 1380 | 1242 | 119 |
| 4753 | 785 | 227 | 1836 | 1269 | 359 |
| 6964 | 785 | 826 | 0408 | 1330 | 659 |

### 2.2 Bands

Vertical, boundaries at the **midpoint in u between adjacent tiers** (never hardcoded px — derive
from the tier extremes so a data edit can't desync them). Screen x boundaries:

| Tier | x from | x to | Fill |
|---|---|---|---|
| START | 30 | 155 | white 5.5% |
| −1 | 155 | 363 | white 2.2% |
| −2 | 363 | 532 | white 2.2% |
| −3 | 532 | 691 | white 2.2% |
| −4 | 691 | 850 | white 2.2% |
| −5 | 850 | 1021 | white 2.2% |
| −6 | 1021 | 1189 | white 5.5% |
| −7 | 1189 | 1380 | white 2.2% |

**Occupied bands are tinted, not just striped.** Any band containing a group is filled in that
group's accent at 10% with a 1px inset border of the same at 18%, and its scale label is drawn in
the group accent at weight 700 instead of 40%-alpha neutral. This is the cheapest possible
"where are we" cue and it works peripherally — read it before you read anything else on screen.
Two groups in one band: the AEGIS group's accent wins.

Band scale labels: 24px mono, `STA −1 … −7`, centred in their band at y 962.

---

## 3. Colour semantics — enforce as a single table, not per-scene literals

| Token | Hex | Means, and means ONLY |
|---|---|---|
| `FLEET` | `#7FD8F0` | The AEGIS group. Locator, primary trail, jump range, destination. |
| `FLEET_ALT` | `#C9D8E8` | A non-AEGIS group. Pale steel — still reads as "us". |
| `WOLF` | `#FF3B2E` | Confirmed wolf system (`L`, `M`) and its glow/chip. |
| `CLAIM` | `#FFC53D` | Unverified scout claim. **Always paired with a dashed stroke.** |
| `HAZARD` | `#A78BFA` | `I`, `J`, `K`. |
| `KNOWN` | `#A5B4C6` | Visited, no consequence (`D`, `E`, `F`, `H`). |
| `POOR` | `#8FA1B8` | `A`, `B`, `C`. |
| `EDEN` | `#EDE4D6` | `N`, `O`, `P`, and `0000`. |
| `UNKNOWN` | `rgba(140,158,182,0.32)` | Never-visited ring. |
| Text | `#DCE6F2` / `#A9B8CC` / `#8A9AB0` | primary / secondary / label |

Background: `radial-gradient(140% 110% at 22% 42%, #0B0F1C, #070A13 55%, #04050B)` plus two soft
nebula washes (violet at 300,300; teal at 1180,760). Shared with the Wolf Attack screen — reuse,
do not fork.

**The rule that fixes the "what is the yellow line" complaint:** amber may never appear on a solid
stroke, and no other colour may appear on a dashed one *except* the relocation arc (§5, drawn in
`FLEET_ALT` because it is still a fleet movement). If a future feature needs a fifth meaning, it
gets a shape, not a colour.

---

## 4. Node composition

Two sizes only. `unknown`/`reported` = **76px** diameter, `visited`/`occupied` = **84px**.

| State | Ring | Fill | Centre content |
|---|---|---|---|
| `unknown` | 2px solid `UNKNOWN` | `rgba(8,11,20,0.7)` | **coordinate, 24px mono, `#7E8EA6`** |
| `reported` | 3px **dashed** `CLAIM` | `rgba(26,20,4,0.82)` | coordinate, 24px mono, `CLAIM` |
| `visited` | 4px solid class tint | class tint @14% | **letter, 42px, 700** |
| `occupied` | as `visited` + locator (§4.2) | as `visited` | letter, 42px |
| wolf `visited`/`occupied` | **5px** solid `WOLF` + `0 0 32px WOLF@45%` | `WOLF` @16% | letter, 42px, `#FF8375` |

**Coordinate placement is state-dependent, and that is intentional.** An unvisited node is an
empty circle, so the coordinate goes *inside* it — big, centred, never colliding with an edge
line. A visited node's centre belongs to the letter, so its coordinate moves into the info chip
below (§4.1). This is the change that makes the map survive a dim projector: on the old build the
labels were 28px floating text sitting on top of 41 edge lines.

Wolf nodes additionally get a **radial glow** in the glow layer, behind the edges: 300px circle,
`WOLF` at 30% closest-side. This is what makes wolf presence readable at a glance rather than
per-node. The occupied node gets the same in `FLEET` at 22%, 420px.

### 4.1 Info chip (visited / occupied / reported)

A single-line chip centred 8px below the node, opaque background, 1px border in the node's tint:

```
┌──────────────────────────────┐
│ 6931 ·  WOLF OUTPOST         │   coord 20px mono 600  ·  name 19px 700 ls1
└──────────────────────────────┘
```

Hard rules, learned the hard way:

- `white-space: nowrap` on the name, always. A wrapped chip grows into its own node ring and
  looks like a bug. Size the chip to the text; do not size the text to the chip.
- Names are **shortened for the map**, full names live in the rail: `WOLF OUTPOST`,
  `WOLF FORTRESS`, `EXPLORER OUTPOST`, `ION NEBULA`, `ASTEROIDS`, `ORIGIN`.
- Reported nodes get a **dashed** chip reading the claim *count*, never claim text:
  `2 CLAIMS · CONFLICT` when the claims disagree, else `N CLAIM(S)`. Verbatim text is rail-only
  (§6.3) — the old inline `REPORTED · source: "` chip clipped at the map edge and was the thing
  the room could not read.
- **A chip must be nearer its own node than any other node.** Measure it. When the natural slot
  below the node is taken (fleet token, another chip), go lower-right diagonal, not sideways: a
  chip pushed 60px sideways attaches itself to the neighbour and publishes a claim about a system
  that has none.
- `0000` is the one node whose chip goes *above* it — below would collide with 1413, and left runs
  off canvas.

### 4.2 Occupied locator

Three elements, all in the group accent, concentric on the node:

1. **Pulse ring** — 120px circle, 3px stroke, `scale 1 → 1.16` / `opacity 0.55 → 0.10`,
   2.4s ease-in-out, infinite. ~0.42 Hz, near the spec's 0.5 Hz.
2. **Corner brackets** — four 22px L-corners on a 140px box, 4px stroke. Reads as a targeting
   reticle; survives being photographed off a TV, which a soft glow does not.
3. **Halo** — see §4.

### 4.3 Group token

A 210–226px chip offset from the node, opaque accent fill, containing in order:

```
( 1 )  ▰▰▰➤   AEG            +4
 index  hull   abbr      companion count
```

- **26px index disc** — dark fill, accent-coloured numeral. This carries the ①②③ link to the
  rail card. It lives *inside the token*, not floating at the node's upper-left; on-node badges
  overlap the ring at every offset that still reads as "attached".
- **Hull silhouette**, 48×20, from `res://art/capital-*.svg`, filled in the token's dark ink.
  Answers the user's "maybe the fleet could be a small ship icon" — and unlike an abbreviation it
  is legible when the panel crushes the blacks.
- **Abbr** 23px mono 700. **`+n`** companion count at 65% ink, omitted when the group is alone.
- AEGIS's token: 3px white outline. Any other group: 6px `WOLF`-coloured bottom edge if the group
  contains a damaged ship, plus a `DMG` tag.
- Position: upper-right of the node at ~64px, pushed to another quadrant when the info chip or a
  neighbour's chip is there. Reference build: fleet token *above* 1096 (the −45° slot collides
  with 3068's claim chip), and up-and-right of 0488.

---

## 5. Edges and trails

- **41 edges, always all drawn**, 2px `#5C6E88` at 40%. They never brighten, pulse or animate.
- **Jump range** (host toggle, default on): the 1-hop edges out of each group's node, redrawn 4px
  in the group accent at 34%, round caps. One overlay, no numeric badges — hop digits on eight
  nodes cost more clutter than they return, and the room can count. Per-group, computed from
  *that group's* node (never one set for "the fleet").
- **Primary trail** 7px `FLEET`, round joins, `drop-shadow(0 0 12px FLEET@65%)` on the newest
  segments. Age ramp by stroke opacity: 0.45 oldest → 0.95 newest, in two or three runs, not per
  segment — a smooth gradient is invisible at 3m.
- **Dead branch** 3px `#8A9AB0` at 28%, dotted (`1 9`). Still history, no longer competing.
- **Non-adjacent hop** (jump failure, host relocation, 2–3-hop jump): dashed quadratic arc
  (`16 12`) in the moving group's accent, bowed *away* from the graph interior, with a small
  rotated 20px label naming it (`JUMP FAILURE`). Never a straight line — a straight line through
  the middle of the map reads as a route that exists.
- **Draw-in**: dash-offset animation over the newest run, 1.8s ease-out, once, on map-up only.
  Suppressed in idle mode. This plus the node pulse is the whole animation budget.

---

## 6. Info rail — x 1400, width 490

Column, 16px gaps, starting y 78. **Hard budget: the rail must end above y 1010.** Measure it in a
test; the first build overflowed to 1262 and silently ate the entire scout section. Order matters
— the two things the room asks for are at the top.

### 6.1 Group card (one per group)

```
▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ 4px accent
( 1 )  MAIN FLEET                    1096  [I]
AEGIS · DIONE · SHEPHERD · QUELLON · R124        18px mono
HAZARD · DAMAGE/TURN · PURSUIT FROZEN            18px, class tint
SCOUT REACH · STARLIGHT 2 · HUMMINGBIRD 3        19px mono
ENDEAVOUR · ANY SYSTEM
PURSUIT ▮▮▮▮▯▯▯▯▨▨ 4                    HERE 1   pips 18×15, gap 3
```

- Title 26px 700. Coordinate 26px mono in the accent; letter in a class-tinted badge.
- Line 3 is the **consequence summary** — the on-arrival rule in ≤40 chars, in the class tint.
  This is why the fleet's situation is legible without anyone reading the paper chart.
- Scout reach belongs *here*, not in its own block: a scout's range follows its parent hull, and
  hulls live in groups. Two lines, no dangling separator.
- Pursuit pips: 10 cells, last two `WOLF`@28% as the danger zone. Value in `CLAIM` colour.
- `HERE n`, `nowrap`. Everything in this card is `nowrap` or an explicit `<br>` — a wrapped rail
  line pushes the block below it and, four blocks down, pushes the last one off the screen.
- Non-AEGIS group: same card, `FLEET_ALT` accent, damaged members flagged `(DAMAGED)` in `WOLF`.

### 6.2 Wolf presence

```
WOLF PRESENCE                    CONFIRMED 3
[L] 6931  OUTPOST                     LEFT T4
[M] 4454  FORTRESS                    LEFT T2
[L] 0488  OUTPOST                    ICE HERE
```

Container tinted `WOLF`@6% with a `WOLF`@45% border. Only ever lists **visited** wolf systems —
this block is a C1 pressure point, so build it by filtering the projection's node array on
`state ∈ {visited, occupied}` and `class == "wolf"`. It must be structurally unable to read a
letter the projection did not send. The right column says why the room should care: which turn we
left, or which group is sitting on it right now (in that group's accent).

### 6.3 Scout reports

Dashed `CLAIM` border, `CLAIM`@50% wash, header `SCOUT REPORTS · UNVERIFIED`. One entry per claim,
newest first, stacked — **contradictions are shown, never resolved**:

```
3068  STARLIGHT · T3
      “G — Level 5 Survivable Planet”
3068  HUMMINGBIRD · T3
      “looked like a fortress to me”
```

Claim text 20px mono in `#E4D8B4`, in typographic quotes, passed through byte-for-byte. Whole
block behind the `show_reports` host toggle (display spec §10 open question 4) — one flag hides
both the rail block and the on-map dashed rings, and hiding it must not move anything else.

---

## 7. Legend bar — y 1020, full width

Eight items, evenly spaced, 20px 700 labels in `#A9B8CC`, each with a real swatch drawn the same
way the map draws it (a *dashed* mini-ring for `SCOUT CLAIM`, a dotted rule for
`ABANDONED ROUTE`, and so on):

`FLEET HERE · PATH TRAVELLED · JUMP FAILURE · ABANDONED ROUTE · WOLF SYSTEM · HAZARD · SCOUT CLAIM · UNVISITED`

Permanent, not a host toggle. It is 48px of screen that removes an entire category of question
from the room, and it is the direct answer to *"not sure what the yellow line is"*.

---

## 8. Title bar

Left: `STAR MAP` 46px 700 ls6, then `/ TURN n · CHART A` 30px mono in `#8A9AB0`. The chart letter
is public (it is printed on the organiser sheet the assistant holds) but carries no letters.

Right: a `CLAIM`-bordered chip, present **only when `groups.size() > 1`**:
`FLEET SPLIT · n GROUPS`. When the fleet is whole the header says nothing further about it —
same principle as dropping the `+n` counter from a lone token.

---

## 9. Projection additions

Four additive fields. All are derived from data `core/` already holds; none is new truth, and none
weakens the C2 boundary. Extend `test_star_map_projection.gd`'s string-search leak assertion to
cover all of them.

```json
"nodes": [
  { "id": "6931", "state": "visited", "letter": "L", "name": "Active Wolf Outpost",
    "class": "wolf",
    "short_name": "WOLF OUTPOST",              // 1. map chip label, <=16 chars
    "consequence_summary": "ATTACK ON ARRIVAL", // 2. rail line, <=40 chars
    "left_turn": 4 }                            // 3. for the wolf-presence right column
],
"groups": [
  { "id": "g1", "index": 1, "at": "1096",
    "band_tint": true,                          // 4. this group's tier gets the accent fill
    "scouts": [ { "label": "STARLIGHT", "jumps": 2 } ] }
]
```

`short_name` and `consequence_summary` are **table lookups keyed on the letter**, and therefore
subject to the same iff-visited rule as `letter`/`name`/`class`: absent keys, not empty strings,
for `unknown` and `reported`. Do not let the TV scene hold the lookup table — that would put all
21 names one bug away from the screen. `left_turn` is `visited_turns.back()` when no unit is there.

---

## 10. Idle mode

`idle_dim`: a `rgba(4,5,11,0.42)` veil over everything, draw-in suppressed, pulse kept. One flag.
The pulse stays because the idle screen's only job is still to answer "where are we" — it just
stops shouting while people talk over it.

---

## 11. Test the geometry, not just the data

The layout failures in this pass were all collisions, and all of them were invisible in code
review and obvious in a measured DOM. Add `tests/test_star_map_layout.gd`:

1. No two text elements overlap by more than 6px on both axes.
2. Nothing extends past x 1920 / y 1080. (The first build lost a whole rail section this way.)
3. Rail column bottom < 1010 with two groups, three claims and three wolf systems — the densest
   realistic state. Fixtures should also cover the *empty* state: one group, no claims, no wolves.
4. Every info chip is closer to its own node's centre than to any other node's centre.
5. No text element renders below 18px.
6. Minimum node-centre separation ≥ 160px for all 22 nodes.

Run it headless against the projection fixtures, not against a screenshot.
