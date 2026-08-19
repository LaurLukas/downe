# Star Map TV — design handoff

Redesign of the 1920×1080 star map screen (Godot 4.7.1, second monitor). Everything an
implementing agent needs; no other files required.

## Contents

```
Star Map.dc.html                          the reference design — open in any browser
support.js                                runtime for the above (must sit beside it)
star_map_tv_visual_implementation.md      ← START HERE. The rendering spec.
reference/
  star_map_tv_display.md                  original spec: data model, projection, C1–C5
  star_charts.json                        one graph, three letter maps, system table
  before-current-build.png                the build this pass replaces
svg/
  capital-*.svg                           six capital-ship silhouettes (group tokens)
```

## Reading order

1. `star_map_tv_visual_implementation.md` — geometry, colour semantics, node/token composition,
   rail budget, legend, layout tests. This is the buildable document.
2. `reference/star_map_tv_display.md` §7 and §9 — the projection contract and the Godot file
   layout. Unchanged except for four additive fields, listed in §9 of the implementation notes.
3. Open `Star Map.dc.html` alongside both. It is the measured source of every number in the spec.

Where the two specs disagree, the implementation notes win: they were derived from a built and
measured screen. Two deliberate overrides are flagged in-line — the u/v scale factors are no
longer uniform, and scout-claim text is rail-only rather than printed on the map.

## What this pass changed, and why

Playtest read of the previous build: hard to see where the players are, hard to see where the
wolves are, the amber layer was unreadable and unexplained, and small type would not survive a
poor TV.

- **One colour, one meaning.** Cyan = us, red = wolves, amber = unverified claim, violet = hazard.
- **The fleet is a beacon** — pulse ring, corner brackets, halo, and a ship-silhouette token
  carrying its group index, hull, abbreviation and companion count.
- **Wolves are loud** — red ring, red halo, a chip naming the threat, and a rail block counting
  confirmed wolf systems.
- **Numbers survive a bad panel** — coordinates sit *inside* otherwise-empty nodes at 24px; no
  text anywhere below 18px; no label floats loose over the 41 edge lines.
- **A permanent legend bar** naming every line and ring style on screen.
- The occupied pursuit band is tinted in the group's accent, so fleet position reads peripherally
  before you read anything else.

## Reference design caveats

The state shown is invented to exercise every node state at once — chart A, turn 4, fleet split,
Icebreaker stranded on a wolf outpost by a failed jump, two contradicting scout claims on 3068.
It is not a real save. The four host toggles in the design (bands, jump range, scout reports, idle
dim) map to the host controls in `reference/star_map_tv_display.md` §8.

Not built, and still open: the scout-range wash over reachable nodes (§6.6 of the original spec)
and 2/3-hop jump badges. Both were judged clutter against the readability goal — add them behind
host toggles if the room asks.

Open rules questions from the original spec (pursuit per jump vs per tier; merge reconciliation)
are untouched by this pass and remain blockers on the data model, not on rendering.
