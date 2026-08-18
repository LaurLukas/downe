# Handoff: Wolf Attack TV Display — v3 Lane Layout

## Overview

A 1920×1080 always-on TV display for the Wolf Attack phase of a tabletop/facilitated space game.
It answers one question for a room full of players standing several metres from a 55" panel:
**which wolf ship is attacking which capital ship, and how hard.**

The v3 redesign replaces v2's bezier attack vectors with **lanes**: one vertical lane per capital
ship, and every wolf attacking that ship is drawn inside its lane, bottom-aligned against an impact
line directly above the ship's card. Adjacency replaces vectors, so nothing crosses at any ship
count, and stack height becomes a threat histogram — the tallest column is the ship under the
heaviest attack.

## About the design files

The files in this bundle are **design references created in HTML** — a prototype showing intended
look, geometry and behaviour. They are **not production code to copy**. The authoritative
implementation target is described in `wolf_attack_tv_display_v3_lanes.md` (Godot 4 / GDScript, with
a `core/` + view-layer split). Recreate the design in that environment using its existing patterns;
if you are implementing in some other environment, follow that environment's conventions and treat
the HTML purely as the visual and layout spec.

`Wolf Attack Lanes.dc.html` opens directly in any browser (double-click it) with `support.js`
alongside it. It is a data-driven prototype: its logic class holds the same derivations the real view
needs (lane grouping, tier selection, projected damage, ordering), so read it as reference pseudocode
as well as visual truth.

## Fidelity

**High fidelity.** Colors, typography, sizes and the full vertical geometry are final and are listed
below in absolute 1920×1080 design pixels. Reproduce them exactly. The one deliberately loose part is
the *content* of the synthetic rosters — those exist only to exercise the scaling tiers.

## Screen: Wolf Attack (single screen, 1920×1080)

Design space is a fixed 1920×1080 canvas. All coordinates below are absolute design px.
Content column: `x 95 → 1825` (width 1730).

### Vertical geometry

| Zone | y |
|---|---|
| Header — title / stats / pursuit meter | 56 → 190 |
| Phase rail | 200 → 234 |
| Wolf force tally (left) · `RANGE · <PHASE>` (right) | 236 → 266 |
| **Stack zone** (wolf tokens, bottom-aligned) | 280 → `impactY − 16` |
| Impact line (range arc) | `impactY` |
| Incoming line (per lane) | `impactY + 8` → `+34` |
| **Fleet card band** | `cardTop` → 906 |
| `TARGETING WRAPS · 7 → 1 · 0 → 6` (centred) | 932 |
| `CANNOT BE TARGETED` rule | 974 |
| Untargetable entries (5-col grid) | 1006 → 1036 |

`impactY = 626` and `cardTop = 666` (card height 240) normally. When `max_stack ≤ 2` the screen
rebalances: `impactY = 560`, `cardTop = 626`, card height 280. Card band always ends at y 906.

### Lanes

One lane per capital ship present. Lane `i` is at `x = 95 + i × (lane_width + 18)`, `y 280`,
height 626 (top of stack zone → bottom of card band).

```
lane_width = (1730 − (n_lanes − 1) × 18) / n_lanes      # 6 lanes → 268
```

Lane children, all positioned relative to the lane:

1. **Wash** — full-lane rect over the stack zone only (height `impactY − 16 − 280`), fill
   `SHIP_COLOR[id]` at alpha **0.07** when the lane has live attackers, **0.02** when it does not
   (and 0.02 for every lane during `targeting`). A 2px top edge in `SHIP_COLOR[id]` at alpha 0.5
   (attacked) / 0.15 (quiet).
2. **Stack** — wolf tokens, bottom-aligned to the bottom of the stack zone, growing upward.
   Column-reverse flow: row 0 is the bottom row.
3. **Spine** — vertical bar, centred in the lane, from the bottom of the stack zone down into the
   card's top edge (height `cardTop − 280 − stack_zone_height + 6`), width
   `clamp(incoming_damage, 2, 10)`, fill `ALERT` at alpha 0.75. Drawn only for attacked lanes.
   This is the only attack-vector graphic left, and it cannot cross another one.
4. **Incoming line** — at `impactY + 8`, left-aligned in the lane, 30px row:
   - attacked: `▼` (24px, `ALERT`) + damage number (IBM Plex Mono 26px 600, `ALERT`) + `DMG`
     (19px 600, letter-spacing 2, `ALERT` @ 0.8) + when boarding parties are inbound, a
     `·` separator and a filled chip `N BP` (mono 19px 700, `#0A0D1A` on `rgba(255,59,46,0.9)`,
     padding 1px 8px)
   - not attacked: `·` (`INK_GHOST`) + `NO CONTACT` (19px 600, letter-spacing 3, `INK_GHOST`)
   - during `targeting`: `—` + `AWAITING TARGETS`
5. **Fleet card** — see below.

**A lane counts as attacked only if it has at least one live attacker.** A lane whose only attackers
are destroyed renders as idle (`NO CONTACT`, idle card) while still showing those destroyed tokens in
its stack. Empty lanes keep their lane, wash, marker and card — who is *safe* is information.

### Wolf token

Two forms, selected by the height tier (below), never per lane.

**Full form (tier A, 100px tall)** — centred column, gap 6:
- silhouette 116×54 (inline SVG `<use>` of the hull symbol)
- row, gap 12: hull code (IBM Plex Mono 30px 700, letter-spacing 2, `INK`) · pips (10px circles,
  gap 7) · `↻` (24px, `INK_DIM`) when the hull returns next attack
- ability text (18px 700, letter-spacing 2, `ALERT`)

**Compact form (tiers B/C/D, 34/30/26px tall)** — single row, full token width, square corners,
`background: rgba(14,21,38,0.86)`, `border: 1px solid RULE`, padding 0 8px, gap 8:
silhouette 40×22 · hull code (mono, 21px in tier B else 19px, 700) · pips (8px tier B, else 7px,
gap 5) · `↻` (18px) · abbreviated ability, right-aligned (mono 17px, 16px in tier D, 700, `ALERT`).

**Pips** encode remaining hull: `capacity` pips, filled `INK` while alive, hollow
`1.6px solid #3C5F70` beyond remaining hull. Pips never disappear entirely.

**Content shedding by lane width** (independent of tier):

| lane_width | Compact token contents |
|---|---|
| ≥ 240 | silhouette · code · pips · abbreviated ability |
| 180–239 | code · pips · abbreviated ability |
| 150–179 | code · pips |
| < 150 | code · `2/3` numeric pip summary |

**Hull table** (code, damage capacity = pip count = damage contributed, ability, abbreviation):

| Hull | Code | Cap | Ability | Abbr | Notes |
|---|---|---|---|---|---|
| Battlestation | `BS` | 6 | `SIEGE BATTERY` | `SIEGE` | returns next attack (`↻`) |
| Strikecarrier | `SC` | 5 | `STOPS FW BUFF` | `FW+` | |
| Cruiser | `CR` | 3 | `PREVENTS 2` | `P2` | |
| Assault transport | `AT` | 2 | `PREVENTS 4 BP` | `4BP` | contributes 4 boarding parties |
| Destroyer | `DE` | 2 | `PREVENTS 1` | `P1` | |
| Fighter wing | `FW` | 1 | `PREVENTS 1` | `P1` | returns next attack (`↻`) |

Ability labels are re-derived from `hull + phase` on every render, never stored. Open items §14.1 of
the spec (BS/CR labels at Long range) are unresolved — the prototype shows the same label in every
combat phase rather than inventing one. Do not guess either.

**Token state**

| State | Rendering |
|---|---|
| Live | code `INK`, pips per remaining hull, ability `ALERT` |
| Destroyed | **do not stack alpha on alpha** — keep the token at full opacity and express death in colour: code and ability `INK_DIM` (`#8A9AB0`), ability text replaced by `DESTROYED` (full form) / `DEAD` (compact), all pips hollow, 1px `rgba(138,154,176,0.7)` strikethrough across the token's vertical centre |
| Returns next attack | `↻` glyph in `INK_DIM` after the pips |
| Must be targeted first (`FW` during `short`) | 2px `CYAN` left border on the token instead of the 1px `RULE` border |

**Ordering within a lane**, from the bottom (nearest the card) upward: live wolves sorted by
descending damage capacity (BS 6, SC 5, CR 3, AT 2, DE 2, FW 1), ties broken **stably** by `uid`;
then destroyed wolves, same sort, at the top. Destroyed hulls sinking to the top keeps the histogram
honest — total commitment is the column height, the dense red band at the bottom is what is still
coming. Match tokens by `uid` across state pushes and tween them; never rebuild a stack, or every
token jumps and the room loses track of the ship it was watching.

### Scaling

Two independent axes: `n_lanes` (from the fleet) and `max_stack` (the busiest lane). Compute both,
then render. **The tier comes from the busiest lane and is applied to every lane** — uniform token
size across lanes is what makes the histogram comparison valid.

| `max_stack` | Tier | Token | Height | Gap | Cols | Shown per lane |
|---|---|---|---|---|---|---|
| 1–3 | A | full | 100 | 10 | 1 | 3 |
| 4–8 | B | compact | 34 | 6 | 1 | 8 |
| 9–16 | C | compact | 30 | 5 | 2 | 16 |
| 17–24 | D | compact | 26 | 4 | 3 | 24 |
| 25+ | D | compact | 26 | 4 | 3 | 23 + `+N MORE` chip |

`token_width = (lane_width − (cols − 1) × gap) / cols`. Multi-column lanes fill **bottom-up,
left-to-right** — index `k` goes to row `floor(k / cols)`, column `k % cols` — so the bottom row is
always full and the ragged edge sits at the top, where it reads as depth. The `+N MORE` chip is a
`rowH`-tall bar at the top of the stack: `rgba(255,59,46,0.1)` fill, `rgba(255,59,46,0.5)` border,
mono 18px `ALERT`.

Low counts must not be padded: bottom-align and let the air sit at the top of the stack zone. At
`max_stack ≤ 2`, raise the impact line and grow the cards instead (see vertical geometry). At
`n_lanes ≤ 4`, cap `lane_width` at 380 and centre the lane group. Below `lane_width` 150 cards shed
the index number and silhouette; below 120, stop and flag to the host rather than silently splitting
into two rows of lanes.

### Fleet card

`lane_width` × 240 (or 280 in the roomy case), `background: rgba(14,21,38,0.86)`, square corners.

- 4px top bar in `SHIP_COLOR[id]`, full card width
- index number: `left 20, top 12`, mono 80px 600, line-height 1, `SHIP_COLOR[id]` (attacked) or the
  same colour at alpha 0.55 (quiet)
- `SEC N`: `right 16, top 14`, mono 20px, letter-spacing 1, `SHIP_COLOR[id]` — moved inside the card
  in v3, because the 30px above the card is now the spine's entry point
- silhouette: `right 16, top 46`, 150×58, opacity 0.9 attacked / 0.45 quiet
- ship name: `left 20, top 112`, 28px 700, letter-spacing 2, `#DCE6F2` attacked / `INK_DIM` quiet
- damage row: `left 20, top 152` — `DAMAGE` (18px 600, letter-spacing 2, `rgba(138,154,176,0.6)`) +
  accumulated damage (mono 30px 600, `ALERT` when > 0 else `INK_GHOST`) + `/ SEC` (mono 20px,
  `rgba(138,154,176,0.5)`)
- damage bar: `left 20, top 190`, `lane_width − 40` × 6, track `rgba(138,154,176,0.16)`, fill
  `damage / security` in `SHIP_COLOR[id]` @ 0.8, switching to `ALERT` above 60%
- `N BP INBOUND` chip: `left 20, top 210`, mono 19px 700, `#0A0D1A` on `rgba(255,59,46,0.9)`
- card border: `2px solid ALERT` + `inset 0 0 0 999px rgba(255,59,46,0.05)` when attacked, else
  `1px solid RULE`. There is no third state.

**Fleet ships** (id, index, name, security, signature colour): `aegis` 1 AEGIS 9 `#CFE4F5` ·
`dione` 2 DIONE 2 `#A97BFF` · `icebreaker` 3 ICEBREAKER 2 `#E8873C` · `quellon` 4 QUELLON 2
`#46D6C0` · `shepherd` 5 SHEPHERD 2 `#7FD46A` · `refinery124` 6 REFINERY 124 6 `#F2D04A`.

### Header, phase rail, tally, footer

- Title `WOLF ATTACK` 54px 700 letter-spacing 7 `#DCE6F2`; `TURN 3` mono 34px 500 `INK_DIM`, right.
- Stat line: `FORCE` label 24px 600 `INK_DIM`; `10 + PURSUIT 6 = 16 CAP` mono 24px `#DCE6F2`;
  `N COMMITTED` mono 24px `ALERT`. **Assert `committed ≤ cap`** — when it overruns, show a
  `CAP EXCEEDED` chip (mono 18px `#FFC53D`, `rgba(255,197,61,0.16)` fill, 1px `#FFC53D` border) and
  warn on the host console. v2 shipped `10 CAP · 87 COMMITTED` unnoticed; this is that assertion.
- Pursuit meter: ten 30×20 cells, gap 5 — filled `#FFC53D`, empty `RULE`, the final overrun cell
  `rgba(255,59,46,0.3)`; value `6 / 10` mono 24px `#FFC53D`.
- 1px `RULE` rule, then the phase rail: `TARGETING · LONG · MEDIUM · SHORT · BOARDING · RESOLVE`,
  18×1px `RULE` connectors. Active: 16px `CYAN` dot with `0 0 16px 6px rgba(127,216,240,0.45)` glow
  and 30px 700 `#DCE6F2` label. Past: 8px `INK_DIM` dot, 26px 400 `INK_DIM`. Future: 8px `RULE` dot,
  26px 400 `RULE`.
- Wolf force tally at y 236, `x 95`, gap 26: per hull `CODE` (mono 24px 600 `INK_DIM`) `×`
  (mono 22px `INK_GHOST`) `count` (mono 24px 600 `INK`), live hulls only, hulls with zero omitted;
  then `·` and `N DESTROYED` (mono 22px, letter-spacing 2, `rgba(138,154,176,0.55)`), or
  `NONE DESTROYED`. Derived every render, never stored.
- `RANGE · <PHASE>` right-aligned on the same row (`right 95`): `RANGE` 19px 600 letter-spacing 3
  `rgba(138,154,176,0.6)`, phase name 22px 700 letter-spacing 4 `CYAN`. It lives here rather than on
  the arc so it can never collide with the last lane's stack or incoming line.
- Impact arc: one SVG spanning the full content width, drawn once (not per lane) so it stays a
  single continuous curve across all lanes — `2.5px CYAN` @ 0.75 over a `9px CYAN` @ 0.12 halo.
  Path in a `0 0 1730 80` box positioned at `impactY − 40`: `M 0 42 Q 865 20 1730 42` (medium),
  `M 0 46 Q 865 26 1730 46` (long), `M 0 40 Q 865 60 1730 40` (short). On phase change, tween the
  control point ±14px so the arc visibly settles.
- Footer: `TARGETING WRAPS · 7 → 1 · 0 → 6` centred at y 932 (22px, letter-spacing 3, `CYAN` @ 0.8,
  on `rgba(5,6,13,0.9)`); `CANNOT BE TARGETED` label + 1px `RULE` rule at 974; then a 5-column grid
  of entries, each a 16×15 `rgba(127,216,240,0.65)` triangle + name (21px 700, letter-spacing 2,
  `INK_DIM`) + value (mono 21px, `rgba(127,216,240,0.9)`).
- Backdrop: `radial-gradient(120% 100% at 50% 42%, #0A0D1A 0%, #0A0D1A 58%, #05060D 100%)` plus four
  soft nebula radials, a two-layer starfield (`220×190` and `97×83` dot tiles at opacity 0.5), a
  540px red wash from the top (`rgba(46,10,16,0.95)` → transparent) and a 530px darkening from the
  bottom.

## Interactions & behaviour

This is a display, not an interactive UI: no hover, focus or click states. All motion is driven by
host state pushes.

- **`targeting`** — no wolf has a target yet, so there are no lanes to fill. Wolves render in a
  **staging pool**: a centred wrapping grid over the stack zone (214px-wide compact tokens, gap 12)
  on `rgba(127,216,240,0.04)` with a 1px dashed `rgba(127,216,240,0.35)` border and the label
  `STAGING POOL — ASSIGNING TARGETS`. Lane washes drop to 0.02 and incoming lines read `—`. As the
  host resolves targets, each wolf **tweens from its pool position into its lane over 0.35s**;
  if all targets arrive at once, stagger the tweens 60ms apart. Watching the columns build is the
  spectacle this phase should have.
- **`long` / `medium` / `short`** — arc label and curve change; every token's ability label
  re-derives from `hull + phase` with no state push. During `short`, `FW` tokens gain the `CYAN`
  left edge (fleet damage must be assigned to fighter wings first).
- **`boarding`** — lanes with inbound boarding parties stay at full opacity; all other lanes drop to
  0.4. `AT` tokens in those lanes pulse.
- **`resolve`** — destroyed wolves fade further; each lane's incoming line switches from projected to
  actual damage dealt; cards show their new damage totals.
- **Host override** — the host must be able to reassign a wolf's target from the admin console and
  see the token move lanes. The lane layout must stay a correctable derivation, not a read-only one.

## State

The view derives everything from one flat snapshot; `core/` knows nothing about columns.

```gdscript
{
  "phase": "medium",                     # targeting|long|medium|short|boarding|resolve
  "wolf_ships": [
    {
      "uid": "wolf_cr_02",               # stable across pushes — drives token identity
      "hull": "cr",
      "damage_taken": 1,
      "destroyed": false,                # explicit, not inferred from damage == capacity
      "returns": false,
      "target_ship_id": "aegis",         # "" during targeting → routes to the staging pool
    },
  ],
  "fleet_ships": [
    {"id": "aegis", "index": 1, "security": 9, "damage": 5, "boarding_parties": 0},
  ],
}
```

Derived in the view, cached on the lane row and invalidated on push (never recomputed per frame):
lane grouping by `target_ship_id`; `max_stack`; `tier`, `row_h`, `gap`, `cols`, `lane_width`;
`incoming_damage` = Σ damage capacity of **live** wolves in the lane; `incoming_bp` = 4 per live
`AT`; the tally; `committed`. `incoming_damage` is a **projection** — what lands if the fleet
destroys nothing more this phase. Label it as such, never as a committed number, and recompute it on
every push: it is exactly the arithmetic the host should not be doing in their head.

Implementation notes worth carrying over: lay stacks out manually (a `VBoxContainer` grows from the
top and will fight bottom-alignment); one `_draw()` for all spines and one for the arc, not a
`Line2D` per lane; pool ~24 token instances and show/hide rather than freeing and re-instantiating
on every push.

## Design tokens

| Token | Value |
|---|---|
| `BG` | `#05060D` |
| `PANEL` / `CARD_BG` | `#0A0D1A` / `rgba(14,21,38,0.86)` |
| `INK` | `#EDE4D6` |
| `INK_BRIGHT` | `#DCE6F2` |
| `INK_DIM` | `#8A9AB0` |
| `INK_GHOST` | `rgba(138,154,176,0.45)` |
| `RULE` | `#24314A` |
| `ALERT` | `#FF3B2E` |
| `ALERT_DEEP` | `rgba(255,59,46,0.9)` |
| `CYAN` | `#7FD8F0` |
| `WARN` | `#FFC53D` |
| Pip hollow stroke | `#3C5F70` |
| Ship colours | see fleet table |

Spacing: lane gap 18, content margin 95, card padding 20, token gaps 4/5/6/10 by tier.
Type: **Oxanium** 400–800 for labels and numbers-as-words, **IBM Plex Mono** 400–700 for all
numerics, codes and machine text. Scale: 80 (card index) · 54 (title) · 34 (turn) · 30 (hull code,
active phase, card damage) · 28 (ship name) · 26 (phase, incoming damage) · 24 (stats, tally) ·
22 (range, footer values) · 21 (footer names, tier-B code) · 19 (compact code, small labels) ·
18 (ability, chips) · 17/16 (tier C/D abbreviations). Nothing on this screen goes below 16px, and
nothing below 18px carries information a player needs from across the room. Square corners
everywhere except the two 7px-radius pod cradles inside the Shepherd silhouette.

## Assets

Ship silhouettes are hand-built vector geometry, authored in this project — no third-party assets,
no licences to clear. They live two ways in the bundle:

- `svg/wolf-*.svg` (6) and `svg/capital-*.svg` (6) — standalone files, `viewBox 0 0 170 76` for wolf
  hulls (padded to `-2 -2 174 80` so the 2.5px stroke is not clipped) and `0 0 150 60` for capital
  ships. Wolf hulls are `fill #0A0D1A` + `stroke #EDE4D6 2.5px`; capital ships are flat fills in
  their signature colour.
- inline `<symbol>` definitions in the prototype (`#hull-bs … #hull-fw`, `#ship-aegis …
  #ship-refinery124`) referenced by `<use>`. Inlining is deliberate: fragment references issue no
  network requests, so the display cannot show a broken glyph if an asset path is wrong.

In Godot, import the SVGs as `SVGTexture`/scalable textures, or port the polygon lists directly —
they are all straight-edged polygons, rects and three circles.

## Files in this bundle

| File | What it is |
|---|---|
| `Wolf Attack Lanes.dc.html` | The v3 lane design. Open in a browser. Data-driven: its logic class is reference pseudocode for lane grouping, tier selection, ordering and projected damage. |
| `support.js` | Runtime the prototype needs. Keep it next to the HTML. |
| `wolf_attack_tv_display_v3_lanes.md` | The authoritative v3 spec this design implements — rationale, scaling tables, phase behaviour, acceptance checklist, and the open questions. Read §13 before calling it done. |
| `svg/` | The 12 ship silhouettes as standalone SVG files. |
| `Wolf Ships.dc.html` | The superseded v2 screen plus the silhouette reference sheet (all 12 hulls with design notes). Useful for silhouette intent; **not** the layout to build. |

### Switching scenarios in the prototype

The design exposes two props on the root component — `scenario` and `phase` — so you can walk the
spec's acceptance checklist. Without a host UI, set them by editing the two lines at the top of
`renderVals()` in the file:

```js
const scenario = this.props.scenario ?? '8 wolves · tier B';
const phase = (this.props.phase ?? 'medium').toLowerCase();
```

`scenario`: `3 wolves · tier A` · `8 wolves · tier B` · `15 wolves · over cap` ·
`24 wolves · over cap` · `30 wolves · over cap` · `12 on one ship`.
`phase`: `targeting` · `long` · `medium` · `short` · `boarding` · `resolve`.

The default (`8 wolves · tier B`) sits honestly inside the stated 16-point cap. The three
`over cap` rosters deliberately overrun it to exercise tiers C and D and the `+N MORE` overflow, so
they also light the `CAP EXCEEDED` assertion — that chip firing there is correct, not a bug.

## Open questions — do not guess

Carried from the spec §14; each one changes the layout, so get answers before locking:

1. `BS` and `CR` ability labels at **Long** range are in no reference.
2. Gorgoneion and Vulcan footer rules.
3. Signature colours for Endeavour, Maliades, Pallas, Voyage 33-0.
4. **Do small ships appear on the targeting table?** This sets `n_lanes` directly — build for N,
   tune for 6.
5. **Can one wolf split its attack across targets?** Every wolf card reads "damage to target",
   singular, which is what makes the lane partition clean. If any hull or event can hit two ships, a
   wolf would need to appear in two lanes and the partition breaks. Confirm before locking this
   design.
