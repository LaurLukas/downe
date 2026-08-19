# Star Map TV Display — Specification

**Target:** 1920×1080, second monitor (TV), Godot 4.7.1, Compatibility renderer, GDScript.
**Companion data:** `res://data/star_charts.json` (shipped alongside this spec).
**Related:** `wolf_attack_tv_display_v3_lanes.md`, `wolf_attack_tv_visual_redesign.md` — the TV
runs both screens; palette, typography, background and animation budget are inherited from the
visual redesign spec and must not be re-invented here.

---

## 1. Purpose

The Wolf Attack screen owns the TV during attacks. The star map owns it the rest of the time.
It exists to answer three questions from across a noisy room, in under five seconds:

1. **Where is the fleet?** — including when the fleet is split.
2. **Where has the fleet been?** — the whole path, from `0000` to now.
3. **What is around us?** — which systems are reachable, and which are known.

It is a *shared public artefact*, the electronic twin of the five paper star charts the players
already hold. It exists to make the room point at a screen and argue. It is not a planning tool
and it is not an oracle.

---

## 2. Hard constraints

These follow directly from `CLAUDE.md` §"Hard design constraints". Read them before writing
any rendering code.

**C1 — The TV must never reveal the letter of an unvisited system.**
Scouts report coordinates and system contents verbally. Some scouts are Wolf agents and will
lie. If the TV displays ground truth for a system the fleet has not physically entered, the
software has caught the liar, and the central deception mechanic of the game is dead.

**C2 — The renderer must be structurally incapable of leaking, not merely instructed not to.**
`core/map/star_map_projection.gd` builds the payload sent to `ui/`. Unrevealed letters are
*stripped at the projection boundary*. The TV scene never holds the full chart. This is an
architectural rule, not a display rule: a future bug in a label binding must not be able to
put the whole chart on a 55" screen.

**C3 — Scout reports are claims, never facts.**
If the host chooses to publish a scout's report, it renders as free text typed by the host,
visually tagged `REPORTED`, attributed to the reporting role, in a distinct dashed style that
can never be confused with a visited system. The system stores the string. It does not compare
it to the chart, does not validate it, does not colour it by truth.

**C4 — The host can override every node state, every unit position, every trail entry.**
Jump failures put ships in the wrong place. Ships get abandoned. The host adjudicates.

**C5 — Public information only.** Everything on this screen must be derivable by a player
holding the blank paper chart plus what has been said out loud in the room. Topology,
coordinates, tier depth and fleet positions all qualify. Unvisited system letters do not.

---

## 3. Source data

Extracted from `DoWNE__A4_Single_Sided_v1_0_1.pdf`:

- **pp. 24–28** — five blank player charts (topology + coordinates, **no letters, no bands**).
  These are the sheets on the AEGIS ×2, Dione, Shepherd and Quellon tables.
- **pp. 29–31** — organiser charts **A**, **B**, **C** (topology + coordinates + letters + pursuit
  bands). The Facilitator Guide, Game Setup, allocates exactly one of these to assistant control:
  *"The star map being used for the game."* The host picks one variant at setup.

### 3.1 Key finding: one graph, three variants

**All three organiser charts share identical node positions and identical edges.** Verified by
pixel analysis: 22 node centroids match to within 1px across all three pages, and the 41-edge
set derived by line-sampling is byte-identical for A, B and C.

Only the **letter assignment** differs. Therefore:

> Ship **one** graph. Ship **three** letter maps. Do not build three graphs.

### 3.2 Graph

22 nodes (21 systems + `0000` START), 41 undirected edges. Node `1096` is the central hub
(degree 6). Leaf-ish nodes of degree 2: `0000`, `9997`, `2580`, `6943`, `4888`, `1380`.

Edges, grouped by lower tier:

```
0000 – 1413, 5143
1413 – 5143, 0488, 6837
5143 – 6837, 9997
0488 – 6837, 4454
6837 – 6931, 4454
9997 – 6931
6931 – 4454, 1096, 4753
4454 – 1096, 6964
1096 – 4753, 6964, 3068, 0853
4753 – 3068, 2580
6964 – 6943, 0853
3068 – 0853, 6798, 8378
6943 – 1964
0853 – 1964, 8378
2580 – 6798
1964 – 8378, 4888, 0408
6798 – 1380, 1836
8378 – 1836, 0408
4888 – 0408
1380 – 1836
```

### 3.3 Tiers and pursuit bands

The organiser charts overlay eight horizontal bands. Band index equals hop-distance from
`0000`, and matches the printed label:

| Tier | Printed label | Nodes |
|---|---|---|
| 0 | START | `0000` |
| 1 | −1 Pursuit | `1413` `5143` |
| 2 | −2 Pursuit | `0488` `6837` `9997` |
| 3 | −3 Pursuit | `6931` `4454` |
| 4 | −4 Pursuit | `1096` `4753` `6964` |
| 5 | *(unlabelled — see §10)* | `3068` `6943` `0853` `2580` |
| 6 | −6 Pursuit | `1964` `6798` `8378` |
| 7 | −7 Pursuit | `4888` `1380` `1836` `0408` |

The **−5 label is missing from the printed charts**. The band exists and is correctly drawn;
only the rotated text is absent. The display renders `−5` — this is public information (players
can count hops on their own sheets) and reproducing a typo helps nobody.

### 3.4 Node table

`u` is depth from START (0 → 1). `v` is lateral position on the paper (0 = paper left).
See §5 for how these map to screen.

| Coord | Tier | u | v | Chart A | Chart B | Chart C |
|---|---|---|---|---|---|---|
| 0000 | 0 | 0.0000 | 0.5090 | START | START | START |
| 1413 | 1 | 0.1198 | 0.6372 | A | L | L |
| 5143 | 1 | 0.1937 | 0.3038 | L | E | L |
| 0488 | 2 | 0.2595 | 0.8231 | L | L | C |
| 6837 | 2 | 0.2820 | 0.5064 | D | B | E |
| 9997 | 2 | 0.3126 | 0.1077 | C | L | D |
| 6931 | 3 | 0.4099 | 0.3141 | L | I | L |
| 4454 | 3 | 0.4369 | 0.7026 | M | L | L |
| 1096 | 4 | 0.5414 | 0.4410 | I | F | M |
| 4753 | 4 | 0.5640 | 0.1410 | E | K | G |
| 6964 | 4 | 0.5640 | 0.8795 | G | J | I |
| 3068 | 5 | 0.6676 | 0.2782 | M | M | H |
| 6943 | 5 | 0.6676 | 1.0000 | K | L | F |
| 0853 | 5 | 0.6892 | 0.6385 | L | M | M |
| 2580 | 5 | 0.7108 | 0.0000 | F | G | J |
| 1964 | 6 | 0.7946 | 0.8462 | M | P | K |
| 6798 | 6 | 0.8216 | 0.1141 | N | M | N |
| 8378 | 6 | 0.8459 | 0.5410 | J | M | O |
| 4888 | 7 | 0.9279 | 0.9744 | P | H | P |
| 1380 | 7 | 0.9297 | 0.0090 | M | O | M |
| 1836 | 7 | 0.9514 | 0.3038 | H | M | M |
| 0408 | 7 | 1.0000 | 0.6731 | O | N | M |

### 3.5 System letters

| Letter | System | Class | Map-relevant note |
|---|---|---|---|
| A | Lichen-Covered Asteroids | poor | |
| B | Ice Asteroids | poor | |
| C | Rare Element Moon | poor | |
| D | Abandoned Explorer Outpost | neutral | Reward can *Explore 2 star systems* → feeds the reported layer |
| E | I.C.S.S. Athena Survivors | standard | Reward: *Explore 2 wolf star systems (code W1 or W2)* — see §10 |
| F | Abandoned Refuelling Station | standard | |
| G | Level 5 Survivable Planet | standard | **Jumping here does not reduce the Pursuit Track** |
| H | Derelict Research Vessel | standard | |
| I | Ion Nebula | hazard | **Pursuit Track is not raised while here**; damage each turn |
| J | Unstable Star | hazard | Damage on 4+ each maintenance phase |
| K | Abandoned Wolf Supply Outpost | hazard | Triggers wolf attack unless critical success |
| L | Active Wolf Outpost | wolf | On arrival: attack, ≥1 battlestation + 20 damage |
| M | Active Wolf Fortress | wolf | On arrival: attack, ≥2 battlestations + 25 damage |
| N | Ancient Jump Ring | new eden | |
| O | Deep Nebula | new eden | Scoutable for a cumulative bonus; **do not display the accrued bonus** (FG explicitly warns a Wolf agent may lie about scanning) |
| P | Ancient Space Station | new eden | On arrival: attack, ≥1 battlestation + 20 damage, survivors re-attack |

`G`, `I`, `J`, `K`, `L`, `M`, `P` have on-arrival consequences. Once **visited**, the node badge
should carry the consequence icon — the fleet has already paid for that knowledge.

### 3.6 Variant character (host-facing, admin console only)

| | Omits | Wolf systems (L+M) | New Eden N / O / P |
|---|---|---|---|
| **A** | B | 8 (4 L, 4 M) | 6798 / 0408 / 4888 |
| **B** | A, C, D | **10 (5 L, 5 M)** | 0408 / 1380 / 1964 |
| **C** | A, B | 9 (4 L, 5 M) | 6798 / 8378 / 4888 |

Chart **B** is materially harsher — two extra wolf systems and only one poor-but-safe system.
Surface this in the setup dropdown as a difficulty hint. In all three charts the three New Eden
candidates sit in tiers 6–7; that appears to be an invariant of the design.

---

## 4. Units on the map

Only **jump-capable** units have a map position. Everything else is cargo.

| Unit | Notes |
|---|---|
| AEGIS, Dione, Icebreaker, Shepherd, Quellon, Refinery 124 | The six capital ships. Each has its own Jump Sheet and jumps independently. |
| G.I.V. Voyage 33-0 | Optional extra ship (Approaching Vessel crisis). Jumps using fuel from a ship it is docked with — so in practice it moves with its host, but model it as an independent unit with its own position so the host can separate them. |

**Shuttles and fighter wings never appear as map positions.** Starlight, Endeavour,
Hummingbird, Pallas, Maliades, Philia, Chacau, Highwall and the fighter wings are all attached
to a parent ship. This caps the model at **7 units**.

### 4.1 One token per group — the display collapses the fleet

`core/` tracks all seven units individually. **The TV does not draw seven tokens.** For the
great majority of the game all six capital ships sit on one node, and six pips stacked on a
34 px circle is noise carrying no information.

The rule:

- **Every group is drawn as exactly one token**, its *representative*.
- **The group containing AEGIS is always represented by AEGIS.** No exception, no override.
  AEGIS is the fleet's anchor and the room should learn to read it as "us".
- **Any other group is represented by one capital ship from its members.** Which one does not
  matter to the display, so it is picked once when the group forms and then held for the life
  of that group — a token that swaps ships between turns would read as movement that did not
  happen.
- If a group contains no capital ship (Voyage 33-0 stranded alone), it is represented by
  whatever it does contain.

Selection order, used once at group formation: `Dione, Icebreaker, Shepherd, Quellon,
Refinery 124, Voyage 33-0`. Deterministic, so a crash-recovery reload redraws the same map.
Host can reassign the representative (§8).

**No information is lost.** The full membership of every group is listed in its info-rail card
(§6.5). The map answers *where*; the rail answers *who*.

> Read of your instruction: "a random single capital ship" as *any one of them, we don't care
> which* — not as a genuine per-frame reroll. If you do want it to reroll each time the map
> comes up, that is a one-line change, but say so.

### 4.2 Groups and split pursuit

Facilitator Guide, *Split Fleet*: **"If the fleet is split after an FTL jump, by accident or
design, then all parts of the fleet maintain their own pursuit score."**

Therefore **pursuit is a property of a group, not of the game.** This is a data-model
consequence, not a display detail — if `core/` currently holds a single global pursuit int,
that is a bug waiting for the first split.

- A **group** is the set of units sharing a node. Groups are *derived*, not stored, except for
  their label and pursuit value which persist across a split/merge.
- Group labels default to `MAIN FLEET`, then `GROUP 2`, `GROUP 3`… and are host-editable.
- On merge, the host is prompted to reconcile the two pursuit values. **Do not auto-resolve**
  (see §10, open question 3).

---

## 5. Layout and coordinate mapping

### 5.1 Orientation

The paper chart is portrait (924×1316, aspect 0.70). The TV is landscape 1.78. A re-layout
would be prettier and would be a mistake: twenty players are holding the portrait sheet and
must be able to correlate the screen to paper instantly.

**Rotate the paper 90° clockwise. Do not re-lay-out.** START moves to the left edge, the New
Eden tiers to the right, and every relative position the players memorised is preserved. Labels
stay horizontal.

```gdscript
const MAP_RECT := Rect2(80, 90, 1280, 900)

func node_screen_pos(u: float, v: float) -> Vector2:
	return MAP_RECT.position + Vector2(u * MAP_RECT.size.x, v * MAP_RECT.size.y)
```

The u and v scale factors work out to 1.153 and 1.152 paper-px → screen-px. Effectively
uniform, so the graph is not visibly distorted and edge angles are preserved.

Expose `orientation: "landscape" | "portrait"` in the host config per **C4**. Portrait mode
letterboxes into a 632×1080 column and is a fallback for a rotated monitor, not the default.

### 5.2 Screen regions

```
┌────────────────────────────────────────────────┬─────────────────┐
│  TITLE BAR   TURN 4 · CHART IN PLAY · PURSUIT  │                 │  0..80
├────────────────────────────────────────────────┤   INFO RAIL     │
│                                                │                 │
│              MAP CANVAS                        │   group cards   │
│              Rect2(80, 90, 1280, 900)          │   legend        │
│                                                │   scout ranges  │
│                                                │                 │
├────────────────────────────────────────────────┤                 │
│  BAND SCALE   START −1 −2 −3 −4 −5 −6 −7        │                 │  990..1080
└────────────────────────────────────────────────┴─────────────────┘
0                                             1440              1920
```

Minimum screen distance between any two nodes is **167 px**. That is the budget for node
radius plus trail spread.

- Node radius **34 px**; ring stroke 4 px.
- Coordinate label 28 px, set outside the node, on the side away from the densest neighbour.
- System letter, when revealed, 40 px, centred inside the node.
- Trail branch pitch **9 px**. At most 3 branches can share a segment (§6.3), so max spread
  18 px — the corridor between nodes is never crowded.
- Group token 46 px, offset 54 px from node centre.

---

## 6. Rendering layers

Bottom to top:

```
BackgroundLayer   cosmic sky + nebula (shared with the Wolf Attack screen; reuse, do not fork)
BandLayer         eight vertical pursuit bands + bottom scale
EdgeLayer         the 41 static jump routes
TrailLayer        per-unit path history strands
NodeLayer         22 StarNode instances
UnitLayer         ship pips at occupied nodes
OverlayLayer      scout range rings, destination reticle, host callouts
```

### 6.1 Bands

Vertical bands alternating background tint at 3% and 6% luminance lift, matching the paper's
grey/white alternation. Band boundaries derived from tier, not hardcoded pixel values. Labels
`START −1 −2 −3 −4 −5 −6 −7` along the bottom scale, 24 px, 40% alpha. Toggleable; default on.

### 6.2 Edges

All 41 edges are always drawn — the topology is on every player's sheet, there is nothing to
hide. 2 px, 18% alpha, flat neutral. They are context, not content. Edges do **not** brighten
on hover, pulse, or animate. Every pixel of visual energy belongs to the trails and the
current position.

### 6.3 Trails — the path history

This is the centrepiece and the thing most likely to be got wrong.

Because the display collapses each group to one token (§4.1), it also collapses the history.
Do **not** draw seven overlapping strands. Draw the **path tree**: the set of *distinct* routes
the fleet has taken.

**Construction.** Take every unit's `trail` and insert it into a prefix tree rooted at `0000`.
Each tree edge is drawn exactly once. Falls out of this automatically:

- While the fleet is together, all seven trails share one prefix → **a single line**.
- At a split, the prefix diverges → **the line forks**, and each fork is a real, separate route.
- At a merge, forks converge on a node → **the line rejoins**.

No annotation, no legend, no crossing vectors. The shape of the line *is* the history of the
fleet, and a split is visible from the back of the room as a fork.

**Colour.** The branch carrying AEGIS is the **primary trail**: full weight, 6 px, AEGIS's
nation accent. Every other live branch is drawn 4 px in its group representative's accent
colour. A **dead branch** — a route travelled by a group that has since merged back — is drawn
3 px in neutral grey at 25% alpha. Dead branches are still the fleet's history and belong on
screen; they just stop competing for attention.

**Lateral offset.** A branch is offset perpendicular to its segment by `(branch_index - 1) * 9px`,
where `branch_index` is assigned by a stable depth-first walk of the tree. Because tree edges are
drawn once, at most three branches can ever share a segment (a merged group's dead route plus two
live ones), so the corridor stays clean.

**Age ramp.** Alpha 0.35 for the oldest segment rising to 0.95 for the most recent, computed
over tree depth. The current positions are the brightest things on screen.

**Non-adjacent hops.** A trail pair that is not a graph edge is legal and must render: jump
failures explicitly relocate ships, the host can override any position, and a "long" jump may
cross multiple hops (§10, open question 1). Render these as a **dashed quadratic arc** bowed
away from the graph, in the unit colour, so a mis-jump or a host correction is visually obvious
rather than silently drawn as a straight line through the middle of the map.

**Draw-in animation.** When the map is brought up, strands draw from START to current position
over 1.8 s, chronologically, easing out. Total animation budget for this screen is one such
sequence plus the node pulse in §6.4 — nothing else moves.

### 6.4 Node states

`StarNode.tscn` has exactly five states. The projection (§7) determines which.

| State | Ring | Fill | Shows | Meaning |
|---|---|---|---|---|
| `unknown` | 2 px, 25% alpha | none | coordinate only | Never visited, nothing published |
| `reported` | 3 px **dashed**, amber | none | coordinate + claim chip | A claim was published by the host |
| `visited` | 4 px solid | class tint | coordinate + letter + name + consequence icon | The fleet has been here |
| `occupied` | 4 px solid + slow 0.5 Hz pulse | class tint | as `visited` + ship pips | Units are here now |
| `destination` | 4 px + reticle | as underlying | as underlying + `DESTINATION` tag | Host has published a jump target |

`destination` composes with the others — a reticle can sit on an `unknown` node.

**The `reported` chip.** Below the node, a dashed-border chip:

```
┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
╎ REPORTED · STARLIGHT · T3 ╎
╎ "G — Level 5 Planet"      ╎
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

The claim text is a verbatim host-typed string in quotes. It is never parsed, never matched
against the chart, never coloured by class. If two scouts report the same node differently,
**show both chips stacked.** Contradiction is the most interesting thing that can happen in
this game and the display should stage it, not resolve it.

A `reported` node becomes `visited` only when a unit actually arrives. At that moment the true
letter appears and any stale claim chips remain visible for one turn, greyed, so the room can
see who was right. This is the payoff of the whole mechanic and is worth the extra state.

### 6.5 Group tokens

One token per group, positioned 54 px from the node centre at −45° (upper right), pushed to
another quadrant if a coordinate label or claim chip is already there.

The token is a 46 px rounded chip: representative ship's nation accent fill, dark
abbreviation text (`AEG`, `DIO`, `ICE`, `SHP`, `QUE`, `R124`, `V330`).

- **AEGIS's token** carries a 3 px white outline. It is the fleet anchor and should be findable
  instantly.
- When more than one group exists, every token gains a **`+n` counter** for the other ships
  travelling with it (`AEG +4`). Zero suffix when the group is a lone ship. This is the whole
  fleet's disposition in two glyphs.
- When only one group exists, drop the counter entirely and draw `AEG` alone — the fleet is
  whole, and the screen should say nothing further about it.
- A group containing a damaged or abandoned ship gets a hatched notch on the token's lower
  edge; detail lives in the rail.

**Info rail group card**, one per group, in the right-hand rail — this is where membership
goes, since the map deliberately does not carry it:

```
┌──────────────────────────────┐
│ ① MAIN FLEET        6931 ·L· │
│ AEGIS · Dione · Shepherd     │
│ Quellon · Refinery 124       │
│ PURSUIT 4          HERE 1 TRN│
└──────────────────────────────┘
┌──────────────────────────────┐
│ ② ICEBREAKER        4454 ·?· │
│ Icebreaker (damaged)         │
│ PURSUIT 6          HERE 2 TRN│
└──────────────────────────────┘
```

The circled index matches a badge drawn at the node's upper-left, so a player can get from card
to map position without reading coordinates. When there is only one group the card loses its
index and simply reads `FLEET`.

### 6.6 Scout range rings

Public information (players can count hops on their own charts), and directly useful for the
room. Off by default, host toggles per scout.

| Scout | Parent ship | Range |
|---|---|---|
| Starlight (Exploration Shuttle) | AEGIS | 2 jumps; a second system if fuelled |
| Hummingbird (Exploration Shuttle) | Quellon | 3 jumps |
| Endeavour (Science Shuttle) | Shepherd | Any system, regardless of range |

Range is a **BFS over graph edges from the parent ship's current node** — which matters
precisely because the fleet can split, and a scout's reach follows its own hull, not the
"fleet". Render as a soft tinted wash over the reachable nodes' cells plus a labelled boundary,
not as a circle (the graph is not metric). Endeavour gets a rail line reading
`ENDEAVOUR · UNLIMITED RANGE` rather than a wash over all 22 nodes.

### 6.7 Jump range overlay

**Confirmed:** jump distance is hop count on the chart.

| Class | Hops | AEGIS fuel | Voyage 33-0 fuel |
|---|---|---|---|
| Short | 1 node | 2 | 1 |
| Medium | 2 nodes | 3 | 1 |
| Long | 3 nodes | 6 | 2 |

Per-ship fuel costs come from each Jump Drive console; the Upgraded state reduces cost by 1.
`star_chart.reachable_within(from, hops)` is a BFS and serves both this and §6.6.

Off by default, host toggles per group. When on, the reachable set from that group's node is
drawn as three nested washes — short brightest, long faintest — with a small `1` / `2` / `3`
hop badge on each reachable node. Nodes at 4+ hops are untinted.

This is public information: a player with the paper chart can count the same hops. It removes
arithmetic from the room, which is the point of the software, without removing any negotiation
— *where* to go remains entirely a player argument, and the overlay says nothing about what is
at any of those nodes.

Note the interaction with the split fleet: reachability is computed from **each group's own
node**, so a stranded ship's options genuinely differ from the main fleet's. Do not compute one
range set for "the fleet".

---

## 7. Data contract

`core/map/star_map_projection.gd` builds this. It is the only thing `ui/` receives.

```json
{
  "type": "star_map",
  "chart_id": "A",
  "turn": 4,
  "orientation": "landscape",
  "show_bands": true,

  "nodes": [
    { "id": "0000", "state": "visited", "letter": "START", "name": "Fleet Origin",
      "class": "start", "visited_turns": [0] },

    { "id": "6931", "state": "occupied", "letter": "L", "name": "Active Wolf Outpost",
      "class": "wolf", "consequence": "wolf_attack", "visited_turns": [2, 4] },

    { "id": "3068", "state": "reported",
      "claims": [
        { "text": "G — Level 5 Survivable Planet", "source": "STARLIGHT", "turn": 3 },
        { "text": "looked like a fortress to me",   "source": "HUMMINGBIRD", "turn": 3 }
      ] },

    { "id": "1836", "state": "unknown" }
  ],

  "groups": [
    { "id": "g1", "index": 1, "label": "MAIN FLEET", "at": "6931",
      "representative": { "abbr": "AEG", "colour": "#3f6fb5", "is_aegis": true },
      "members": [
        { "label": "AEGIS",        "status": "ok" },
        { "label": "Dione",        "status": "ok" },
        { "label": "Shepherd",     "status": "ok" },
        { "label": "Quellon",      "status": "ok" },
        { "label": "Refinery 124", "status": "ok" }
      ],
      "pursuit": 4, "turns_here": 1 },

    { "id": "g2", "index": 2, "label": "ICEBREAKER", "at": "4454",
      "representative": { "abbr": "ICE", "colour": "#b5563f", "is_aegis": false },
      "members": [ { "label": "Icebreaker", "status": "damaged" } ],
      "pursuit": 6, "turns_here": 2 }
  ],

  "path_tree": {
    "root": "0000",
    "branches": [
      { "id": "b0", "nodes": ["0000", "1413", "6837", "6931"],
        "state": "live", "group": "g1", "colour": "#3f6fb5", "primary": true },
      { "id": "b1", "nodes": ["6837", "4454"],
        "state": "live", "group": "g2", "colour": "#b5563f", "primary": false },
      { "id": "b2", "nodes": ["6931", "1096", "6931"],
        "state": "dead", "group": null, "colour": null, "primary": false }
    ]
  },

  "scout_rings": [
    { "scout": "STARLIGHT", "from": "6931", "jumps": 2 }
  ],

  "jump_ranges": [
    { "group": "g1", "from": "6931", "short": ["6837","4454","1096","4753","9997"],
      "medium": ["1413","0488","5143","3068","0853","6964","2580"],
      "long":   ["0000","6798","8378","6943","1964"] }
  ],

  "highlight": { "node": "1096", "mode": "destination", "label": "PROPOSED JUMP" }
}
```

### Projection rules — enforce these in `core/`, with tests

1. `letter`, `name`, `class` and `consequence` are present **if and only if**
   `state ∈ {visited, occupied}`. For `unknown` and `reported`, the keys are **absent**, not
   null, not empty string. Write a test that asserts absence.
2. `claims[].text` is passed through byte-for-byte. No trimming to a known letter, no
   normalisation, no lookup.
3. **The projection emits groups, not units.** Per-unit positions and trails live in
   `fleet_positions.gd`; the projection collapses them. `ui/` has no concept of an individual
   ship's position — only membership strings on a group card. This is what makes the
   one-token rule impossible to accidentally violate in a scene file.
4. `path_tree.branches` is built by inserting every unit trail into a prefix tree and emitting
   each tree edge once. A branch's `nodes` array starts at its fork point, not at the root, so
   segments are never drawn twice.
5. A branch may contain a consecutive pair that is not in `edges` — a 2- or 3-hop jump records
   only its endpoints, and jump failures relocate ships arbitrarily. The renderer handles it
   (§6.3); the projection does not reject it and does not interpolate the intermediate nodes.
   **A medium or long jump is one segment, drawn as one arc**, not as a walk through the hops
   it skipped: the fleet was never at those systems.
6. A node may appear twice in one branch — the fleet can return. Render the segment once, at
   the most recent age.
7. `pursuit` lives on the group. There is no top-level pursuit field.
8. `representative` is stable for the lifetime of the group. Recomputing it on every projection
   build is a bug: the token would flicker between ships.

Transport: flat JSON over the existing WebSocket, `type: "star_map"`. Payload is ~4 KB with a
full 7-unit history, which is fine for the host↔TV link. The ESP32 terminals never receive it.

---

## 8. Host controls (admin console)

The admin console shows the **same map with ground truth** — all letters visible, in a scene
that is explicitly not the TV scene and never routed to the second monitor.

| Control | Behaviour |
|---|---|
| Chart in play | `A` / `B` / `C`, set at setup, changeable mid-game (**C4**) with a confirm |
| Move unit | Set any unit's node directly. Appends to trail. Adjacency is **not** enforced. |
| Undo last move | Pops the trail entry. For fat-fingered jump adjudication. |
| Publish claim | Node + free-text + source role + turn. Appears as a `reported` chip. |
| Retract claim | Removes a chip. |
| Set group label / pursuit | Per group. Prompted on merge. |
| Set group representative | Which ship's token stands for the group. Locked to AEGIS for AEGIS's group. |
| Toggle scout ring | Per scout. |
| Toggle jump range | Per group. Shows the 1 / 2 / 3-hop wash (§6.7). |
| Set destination | Node + label, or clear. |
| Show / hide map | Pushes the map to the TV, or returns it to the Wolf Attack idle state. |
| Force state | Override any node to any state. Escape hatch. |

### When the map goes up

- **Automatically** for 45 s after every jump resolution — the reveal moment, and the reason
  this screen exists.
- **On demand** during the Coordination Phase, when the room is arguing about where to go.
- **As the idle screen** between phases, at 60% brightness with the draw-in animation
  suppressed, so it does not compete with conversation.
- **Never** during a Wolf Attack. The attack screen has absolute priority on the TV.

---

## 9. Godot structure

```
res://data/
  star_charts.json                one graph, three letter maps, system table

res://core/map/
  star_chart.gd                   RefCounted. Loads json. nodes, edges, neighbours(),
                                  hops_between(), reachable_within(from, n) [BFS],
                                  jump_class(from, to) -> short|medium|long|out_of_range.
  fleet_positions.gd              RefCounted. Units, trails, derived groups, pursuit per group,
                                  stable representative per group. Emits `positions_changed`.
  path_tree.gd                    RefCounted. Prefix tree over unit trails -> branch list.
  star_map_projection.gd          RefCounted. build(chart, positions, reveal_state) -> Dictionary.
                                  The C2 boundary. Collapses units to groups.
  reveal_state.gd                 RefCounted. visited set, claims list. Never holds truth
                                  about unvisited nodes.

res://ui/tv/star_map/
  StarMapScreen.tscn / .gd        Control 1920x1080. Consumes the projection dict only.
  StarNode.tscn / .gd             Five states, no chart access.
  TrailLayer.gd                   Node2D, _draw() over projection.units.
  GroupCard.tscn / .gd            Info rail entry.
  ClaimChip.tscn / .gd

res://ui/admin/
  StarMapAdmin.tscn / .gd         Ground-truth map + controls from §8.

res://tests/
  test_star_chart.gd              22 nodes, 41 edges, degree of 1096 == 6,
                                  hops_between("0000","0408") == 7, tier(n) == BFS depth,
                                  jump_class within 1/2/3 hops.
  test_path_tree.gd               Seven identical trails -> one branch. One divergent trail ->
                                  two branches sharing no segment. Merge -> convergence, and
                                  the abandoned route emitted once as `dead`.
  test_star_map_projection.gd     Leak tests. THE important file.
  test_split_fleet.gd             Split → two groups → independent pursuit → merge.
                                  Representative is stable across rebuilds; AEGIS's group
                                  always reports AEGIS.
```

`core/map/` follows the standing rule: no `Node`, no `get_tree()`, no `Engine`, no scene
references. All four classes are `RefCounted` and headlessly testable.

### The leak test

`test_star_map_projection.gd` must assert, for a chart where the fleet has visited only
`0000` and `1413`:

- exactly 2 nodes carry a `letter` key
- the other 20 carry no `letter`, `name`, `class` or `consequence` key at all
- serialising the whole projection to a string and searching it for the name of any unvisited
  system returns nothing
- a published claim of `"G — Level 5 Planet"` on a node whose true letter is `M` round-trips
  unchanged and does not cause `class` to appear

That last string-search assertion is crude and is exactly the point: it catches the leak no
matter which key someone accidentally adds later.

---

## 10. Open questions

Carried forward, not guessed. Items 1–3 change the data model; resolve them before
implementing trails.

1. ~~What is a "short" / "medium" / "long" jump?~~ **RESOLVED.** Hop count on the chart:
   short = 1 node, medium = 2, long = 3. Specced in §6.7 and implemented as
   `star_chart.jump_class()`. Nothing further needed.

2. **Does pursuit fall by 1 per jump, or by 1 per tier crossed?** *(Sharpened by Q1.)*
   The Pursuit Track sheet says *"−1 per jump away from 0000"*, but the organiser chart bands
   are labelled cumulatively, −1 through −7 by tier depth. Now that long jumps are confirmed to
   cross up to three nodes, this matters concretely: **a long jump from tier 1 to tier 4 is
   either −1 or −3.** If it is −1, long jumps are a fuel-expensive way to lose pursuit
   reduction and nobody will use them; if it is −3, the band labels are simply the running
   total and the rule reads "−1 per node of distance". The second reading makes the printed
   bands make sense and is the working assumption, but it is a real rules question, not a
   display one. **This is now the top blocker.**

3. **How is pursuit reconciled when two split groups merge?**
   FG confirms each part keeps its own score but is silent on rejoining. Higher value? Lower?
   Host call? Currently specced as a host prompt, which is safe but may be busywork.

4. **Should scout reports appear on the TV at all?**
   §6.4 specs them as opt-in host-published claims. The alternative is admin-only, keeping all
   scout traffic verbal. The claim chips are dramatic but they also give a lying Wolf agent a
   free official-looking billboard — which may be a feature. Your call.

5. **Signature colour for Voyage 33-0.** Much reduced by the one-token rule — it only ever
   shows if Voyage 33-0 is stranded alone as its own group. It is Gliese, same as Refinery 124,
   so it still needs a distinguishable treatment for that case (specced as desaturated,
   unconfirmed).

6. **`W1` / `W2` wolf system codes.** System E's away-mission reward reads *"Explore 2 wolf
   star systems (code W1 or W2)"*, but the charts label wolf systems `L` and `M`. Either a
   leftover from an earlier draft or a separate code space. Unresolved from previous passes.

7. **Missing −5 pursuit band label** on organiser charts A, B and C (§3.3). The display renders
   it. Worth fixing in the print files.

8. **Does the fleet re-scout?** System D's reward grants *"Explore 2 star systems"* and Deep
   Nebula accumulates scouting missions. The projection needs to know whether a second scout of
   an already-claimed node replaces or stacks the chip. Currently specced as **stacks** (§6.4),
   because contradiction is the interesting case.

9. **How long do dead branches persist?** §6.3 keeps an abandoned route on screen forever in
   neutral grey, on the argument that it is still the fleet's history. Over seven or eight turns
   with a couple of splits that is maybe three or four faint lines — probably fine, possibly
   clutter. The alternative is to fade them out after two turns. Easy to change either way;
   worth a look at the first playtest rather than deciding now.

---

Per FG guidance on Deep Nebula — *"Do not share the accrued bonus with the players beforehand in
case a Wolf Agent wants to lie about scanning the nebula"* — the nebula scouting counter is
**admin-only** and must never reach the projection. Same class of constraint as C1.
