# Wolf Attack TV Display — v1 → Target Gap Spec

**Status:** v1 implementation exists and is structurally roughly correct. It does not yet
read as the target design. This document lists every remaining gap, with measured values.

**Companion documents:** `wolf_attack_tv_display.md` (original spec — state machine, data
contract, host input model). This document *supersedes its visual sections only*. All rules,
phases and host controls in the original spec still stand.

**Reference images**
- `Wolf_Ships-selection.png` — the target. Authoritative for all visual decisions.
- `Wolf_attack_v1.png` — current build. Authoritative for nothing.

---

## 0. How to use this document

1. Work top to bottom. §2 (tokens) must land before anything in §4, because every fix in §4
   references a token by name.
2. Every gap has an ID (`P0-03`, `P1-11`). Use the IDs in commit messages.
3. All coordinates are in a **fixed 1920×1080 design space**, measured off the target mockup,
   ±5px. Do not compute layout from window size — see `P0-01`.
4. Where this document says *verify against source*, do not guess a value. Flag it and move on.
   That rule from `CLAUDE.md` applies here too.

---

## 1. What v1 already got right — do not regress

- Overall information architecture: header → phase rail → wolf force → range bands → fleet cards → footer.
- All six phase names, in the right order, with the correct one highlighted.
- The `PREVENTS N` derivation is correct for the SHORT phase (CR shows `PREVENTS 1`, AT shows `PREVENTS 4 BP`).
- Per-ship signature colours are broadly correct.
- `TARGETING WRAPS · 7 → 1 · 0 → 6` string format.
- Attacker chips on fleet cards, and `BP` chips rendering differently from ship-type chips.
- Damage line uses a `◄ N DMG` form with a leading marker.

Everything below is additive to these.

---

## 2. Design tokens — build this first

Create `res://ui/tv/wolf_attack_tokens.gd` as a `RefCounted` holding constants, and
`res://ui/tv/theme_wolf_attack.tres` as a `Theme` resource. **No hardcoded colours or font
sizes anywhere in the scene scripts.**

### 2.1 Canvas and scaling

| Setting | Value |
|---|---|
| Design resolution | `1920 × 1080` |
| `display/window/size/viewport_width` | `1920` |
| `display/window/size/viewport_height` | `1080` |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `keep` |
| Safe margin — left / right | `95 px` |
| Safe margin — top | `60 px` |
| Safe margin — bottom | `55 px` |

The TV window opens fullscreen on the second display. All node positions are authored against
1920×1080 and scale automatically. Nothing reads `get_viewport_rect()` for layout.

### 2.2 Palette

```gdscript
# Backdrop
const BG_DEEP        := Color("#07090F")  # base, bottom of gradient
const BG_MID         := Color("#12101E")  # mid gradient
const BLOOM_CRIMSON  := Color("#4A0E18")  # top-corner bloom
const BLOOM_EDGE     := Color("#6B1220")  # top edge, very low alpha

# Text
const INK            := Color("#F2EADB")  # primary cream — titles, ship names, wolf strokes
const INK_DIM        := Color("#8A8578")  # field labels, "→ AEGIS", "CANNOT BE TARGETED"
const INK_GHOST      := Color("#3B4252")  # inactive phase items, LONG/SHORT gutter labels

# Accents
const CYAN           := Color("#38E1E8")  # active phase, active band arc, untargetable list
const CYAN_DIM       := Color("#1E6E78")  # wraps line, band hairlines
const ALERT          := Color("#FF3B30")  # ability text, DMG, vectors, targeted borders, over-cap
const ALERT_DEEP     := Color("#8E1A15")  # BP chip fill
const AMBER          := Color("#F7B733")  # pursuit filled cells + counter

# Pursuit meter
const PURSUIT_EMPTY_FILL   := Color("#1B2540")
const PURSUIT_EMPTY_BORDER := Color("#2E3C60")
const PURSUIT_DOOM         := Color("#6E1616")  # cell 10 only

# Surfaces
const CARD_BG          := Color("#0E1424")
const CARD_BG_TARGETED := Color("#1A0E14")
const RULE             := Color("#24303F")  # hairlines

# Fleet ship signature colours — keyed by snake_case ship id
const SHIP_COLOR := {
	"aegis":        Color("#E6EDF7"),
	"dione":        Color("#8B5CF6"),
	"icebreaker":   Color("#C2703C"),
	"quellon":      Color("#2DD4BF"),
	"shepherd":     Color("#4ADE80"),
	"refinery_124": Color("#E5B325"),
}
```

Ship colours live in the same lookup table as display names (`CLAUDE.md`: *never hardcode
display strings in logic*). Extend that table with a `color` field rather than creating a
second registry. Small ships (Endeavour, Maliades, Pallas, Voyage 33-0) need colours assigned
before they can appear on this screen — **verify against source / ask the host.**

### 2.3 Typography

v1 uses the Godot default font at default tracking. This is the single largest reason it does
not look like the target. The target is **uppercase everywhere, one squarish techno family,
heavy letter-spacing, tabular figures.**

Bundle OFL fonts under `res://assets/fonts/`. **No CDN, no runtime download** — the host runs
on a GL.iNet travel router with no internet.

| Role | Family | Use |
|---|---|---|
| `DISPLAY` | Chakra Petch Bold (or Saira SemiCondensed Bold) | Title, TURN, phase rail, wolf type codes, card numbers and names |
| `DATA` | JetBrains Mono (Regular / Bold) | Stat lines, pips context, chips, SEC, wraps line, footer |

Tracking is applied with `FontVariation.spacing_glyph`, not by inserting spaces into strings.

```gdscript
var fv := FontVariation.new()
fv.base_font = load("res://assets/fonts/ChakraPetch-Bold.ttf")
fv.spacing_glyph = 6   # px, added per glyph
```

Type scale (px in design space):

| Token | Size | Weight | `spacing_glyph` | Applies to |
|---|---|---|---|---|
| `T_TITLE` | 64 | Bold | 6 | `WOLF ATTACK` |
| `T_TURN` | 40 | Bold | 5 | `TURN 3` |
| `T_STAT` | 22 | Regular | 3 | `FORCE 10 + PURSUIT 6 = 16 CAP · 16 COMMITTED` |
| `T_PURSUIT_NUM` | 26 | Bold | 2 | `6 / 10` |
| `T_PHASE` | 24 | Regular | 4 | inactive phase names |
| `T_PHASE_ACTIVE` | 30 | Bold | 4 | active phase name |
| `T_WOLF_CODE` | 34 | Bold | 3 | `BS`, `SC`, `CR`… |
| `T_WOLF_ABILITY` | 19 | Bold | 2 | `PREVENTS 2`, `SIEGE BATTERY` |
| `T_WOLF_TARGET` | 17 | Regular | 2 | `→ AEGIS` |
| `T_BAND_GUTTER` | 28 | Regular | 6 | `LONG`, `SHORT` in left gutter |
| `T_BAND_ACTIVE` | 26 | Bold | 5 | `MEDIUM` on the arc |
| `T_CARD_INDEX` | 62 | Bold | 0 | `1`–`6` |
| `T_CARD_NAME` | 27 | Bold | 2 | `ICEBREAKER` |
| `T_SEC` | 18 | Regular | 2 | `SEC 9` |
| `T_DMG_NUM` | 38 | Bold | 0 | the damage number |
| `T_DMG_SUFFIX` | 18 | Regular | 2 | the `DMG` word |
| `T_CHIP` | 17 | Regular | 1 | `SC`, `CR`, `4 BP` |
| `T_WRAPS` | 19 | Regular | 5 | `TARGETING WRAPS · …` |
| `T_FOOTER_LABEL` | 16 | Regular | 4 | `CANNOT BE TARGETED` |
| `T_FOOTER_ITEM` | 22 | Bold | 2 | `FW ALPHA` |
| `T_FOOTER_VALUE` | 20 | Regular | 2 | the `4` after `FW ALPHA` |

**All display strings are uppercased at render time**, not in the data model. Add a single
`fmt_display(s: String) -> String` helper; do not `.to_upper()` inline in twenty places.

### 2.4 Vertical rhythm

v1 has the wolf row colliding with the fleet cards and ~180px of dead space above the wraps
line. Correct baselines:

| Element | y (design space) |
|---|---|
| Title / TURN baseline | 112 |
| Stat line + pursuit meter | 155 |
| Header hairline | 190 |
| Phase rail | 217 |
| Wolf silhouette band | 250 → 345 |
| Wolf type code + pips | 372 |
| Wolf ability line | 414 |
| Wolf target line | 452 |
| Active range-band arc | 452 (apex) → 500 (edges) |
| Vector origin | ~505 |
| `SEC N` labels | 638 |
| Fleet card band | 648 → 898 (height 250) |
| Wraps line | 948 |
| `CANNOT BE TARGETED` | 985 |
| Untargetable entries | 1020 |

---

## 3. Priority summary

### P0 — structural. Nothing else matters until these are done.

- [ ] `P0-01` Fixed 1920×1080 design space; content is currently clipped off both edges
- [ ] `P0-02` Load and apply the display/data font pair with tracking
- [ ] `P0-03` Replace flat grey background with the gradient + bloom backdrop
- [ ] `P0-04` Remove panel boxes from wolf ships; distribute them across the full width
- [ ] `P0-05` Build the range-band layer (LONG/MEDIUM/SHORT gutters + active arc)
- [ ] `P0-06` Replace vector stubs with curved dashed beziers wolf → target card
- [ ] `P0-07` Apply the §2.4 vertical rhythm; kill the dead space above the wraps line
- [ ] `P0-08` Remove `LIVE: maliades` and `WOLF FORCE - 11 / 11 CAPACITY` from the TV output

### P1 — component fidelity

- [ ] `P1-09` Fleet card styling: fixed height, backing, top colour bar, targeted state
- [ ] `P1-10` Fleet ship icons filled in the ship colour, not thin outlines
- [ ] `P1-11` Card index numbers scaled up and coloured
- [ ] `P1-12` `SEC N` moved off the divider strip, above the card, in the ship colour
- [ ] `P1-13` Wolf pips: filled = remaining, hollow = damage taken
- [ ] `P1-14` Wolf silhouettes: distinct line-art per hull class
- [ ] `P1-15` Pursuit meter: amber fill, dark-navy empty, crimson doom cell
- [ ] `P1-16` Phase rail: size + weight + glow differential on the active item
- [ ] `P1-17` Header: add `TURN N`; colour `COMMITTED` by cap state
- [ ] `P1-18` Chip styling: outlined for ship types, filled `ALERT_DEEP` for BP
- [ ] `P1-19` Footer: short names, cyan triangles, modifier suffixes
- [ ] `P1-20` Wraps line in `CYAN_DIM` with tracking

### P2 — polish

- [ ] `P2-21` Fake glow on the active band arc, targeted card borders, active phase dot
- [ ] `P2-22` Dash-offset animation on attack vectors
- [ ] `P2-23` Slow pulse on targeted card borders
- [ ] `P2-24` Phase-transition cross-fade

---

## 4. Gaps in detail

### 4.1 Backdrop — `P0-03`

**Now:** flat `#3a3f44` grey. Reads as an unstyled Godot window.

**Target:** near-black base, crimson bloom bleeding in from the top corners and top edge,
falling off to almost pure black by the fleet card row. It is the single cheapest change that
makes the screen feel like a battle map.

**Fix**
- Bake a `1920×1080` PNG gradient (`BG_DEEP` → `BG_MID`) and use a full-rect `TextureRect`.
  Cheaper and more predictable than a shader in the Compatibility renderer.
- Add two `TextureRect` bloom layers (soft radial, `BLOOM_CRIMSON`) anchored to the top-left and
  top-right corners, `CanvasItemMaterial.blend_mode = BLEND_MODE_ADD`, `modulate.a ≈ 0.55`.
- One wide, low-alpha `BLOOM_EDGE` strip across the top edge.
- Do **not** rely on `WorldEnvironment` glow — it is unreliable in Compatibility. All glow on
  this screen is faked with pre-blurred additive textures.

### 4.2 Header — `P1-17`

**Now:** `WOLF ATTACK` is small and centred; no turn number; stat line clipped at the left edge;
`11 COMMITTED` is white despite exceeding a cap of 10.

**Target:** title left-aligned at the safe margin, 64px, heavily tracked, cream. `TURN 3`
right-aligned on the same baseline in `INK_DIM`.

**Fix**
- Title left at `x = 95`, `T_TITLE`, `INK`.
- `TURN N` right-aligned to `x = 1825`, `T_TURN`, `INK_DIM`. **`turn` is missing from the data
  contract — add it** (see §5).
- Stat line at `y = 155`: field labels (`FORCE`, `PURSUIT`, `CAP`) in `INK_DIM`, numbers in `INK`.
  Use a `RichTextLabel` with BBCode colour tags, or an `HBoxContainer` of alternating labels.
- The `·` separator is `INK_GHOST`.
- `N COMMITTED` colour is state-driven:
  - `committed < cap` → `INK_DIM`
  - `committed == cap` → `ALERT`
  - `committed > cap` → `ALERT` **and log a warning**. v1 currently shows `10 CAP · 11 COMMITTED`,
    which should not be reachable. Add an assertion in `core/` and a host-console warning.
- Hairline rule at `y = 190`, `x` 95→1825, 1px `RULE`.

### 4.3 Pursuit meter — `P1-15`

**Now:** ten cells, nine slate-blue and one red, regardless of the pursuit value. `0 / 10` in white.

**Target:** cells 1..`pursuit` filled `AMBER`; remaining cells `PURSUIT_EMPTY_FILL` with a
`PURSUIT_EMPTY_BORDER` 1px border; cell 10 is always `PURSUIT_DOOM` when unfilled (it is the
game-over slot and must read as menacing even at pursuit 0). Counter in `AMBER`.

**Fix**
- Cell `30 × 26`, gap `5`, row spans `x` 1372 → 1722, vertically centred on `y = 155`.
- Counter right-aligned to `x = 1825`, `T_PURSUIT_NUM`, `AMBER`.
- Draw with a single `Control._draw()` loop, not ten `ColorRect` nodes.
- When `pursuit >= 8`, add a soft `ALERT` glow behind the filled run (`P2-21`).

### 4.4 Phase rail — `P1-16`

**Now:** correct content, but all items are near-identical in size; inactive items are a purple-blue
that reads as a link colour; the active marker is a plain `◉`.

**Target:** inactive items are almost invisible (`INK_GHOST`), the active item is noticeably
larger, bold, `CYAN`, and preceded by a glowing filled dot. The separators are long em-dashes
in `INK_GHOST`.

**Fix**
- Render as `HBoxContainer`, `separation = 18`, left-aligned at `x = 95`, `y = 217`.
- Each phase is `[dot][label]`; dot radius 5, `INK_GHOST` when inactive, `CYAN` + additive glow
  sprite when active.
- Inactive: `T_PHASE`, `INK_GHOST`. Active: `T_PHASE_ACTIVE`, `CYAN`.
- Separators are `—` labels, `INK_GHOST`, not part of the phase items.
- Because the active item changes size, the rail must not reflow visibly. Give every phase item a
  fixed `custom_minimum_size.x` computed from its **active** width, so the row is stable across
  transitions.

### 4.5 Wolf force row — `P0-04`, `P1-13`, `P1-14`

This is the biggest visual gap.

**Now:** three wolf ships crammed into the top-left inside bordered grey panels; a redundant
`WOLF FORCE - 11 / 11 CAPACITY` heading; all pips hollow; silhouettes small and generic;
`↻ returns` rendered as a text line under the ability.

**Target:** wolf ships float free — no panels, no borders, no backing — evenly distributed across
the full 1730px content width, each a large line-art silhouette above a four-line stack.

**Fix**

1. **Delete the `WOLF FORCE — N / N CAPACITY` heading.** The capacity is already in the header
   stat line. (`P0-08`)
2. **Delete all `StyleBox` backing on wolf ship items.** They are transparent.
3. `HBoxContainer` spanning `x` 95 → 1825; every child `size_flags_horizontal = SIZE_EXPAND_FILL`
   so N ships distribute evenly. Each child is a centred `VBoxContainer`.
4. Each child stack, top to bottom:
   - **Silhouette** — max height 95px, centred in the 250→345 band, `INK` stroke, no fill.
   - **Code + pips** on one line at `y = 372`. Code in `T_WOLF_CODE` `INK`; pips to the right,
     radius 5, gap 14, vertically centred on the code's cap height.
   - **Ability line** at `y = 414`, `T_WOLF_ABILITY`, `ALERT`.
   - **Target line** at `y = 452`, `T_WOLF_TARGET`, `INK_DIM`, format `→ SHIPNAME` uppercase.
5. **Pips carry damage state** (`P1-13`). Pip count = the hull class's damage capacity.
   Filled `INK` = remaining, hollow `INK_GHOST` outline = damage taken. Hollow pips come **first**
   (left), matching the target: `CR ○ ● ●` is a cruiser with 1 of 3 taken.

   | Code | Hull | Capacity |
   |---|---|---|
   | `BS` | Wolf Battlestation | 6 |
   | `SC` | Wolf Fleet Strikecarrier | 5 |
   | `CR` | Wolf Cruiser | 3 |
   | `AT` | Wolf Assault Transport | 2 |
   | `DE` | Wolf Destroyer | 2 |
   | `FW` | Wolf Fighter Wing | 1 |

6. **The `↻` returns glyph sits inline after the pips**, not on its own line. Only `BS` and `FW`
   can return (both "will return in the next Wolf Attack" if not destroyed). Colour `INK_DIM`.
7. **Silhouettes** (`P1-14`) — six distinct hull classes, authored as SVG, stroke-only, ~2px
   stroke at design scale. Store at `res://assets/silhouettes/wolf/{bs,sc,cr,at,de,fw}.svg`.
   Read the class from the target mockup:
   - `BS` — blocky central mass, symmetrical side pylons, hexagonal prow
   - `SC` — long carrier hull with a dorsal spine and a flared tail
   - `CR` — narrow dart, tapering to a sharp point, small dorsal fin
   - `AT` — fat cylinder with a segmented cargo body and a splayed engine cluster
   - `DE` — twin forward prongs, thin body
   - `FW` — five small chevrons in a loose formation (a *wing*, not a single craft)
8. **Ability label is phase-dependent and derived, not stored.** Build a single
   `wolf_ability_label(hull: String, phase: String) -> String` in `core/`:

   | Hull | Long | Medium | Short |
   |---|---|---|---|
   | `BS` | *verify* | `SIEGE BATTERY` | `IMMUNE` |
   | `SC` | `STOPS FW BUFF` | `STOPS FW BUFF` | `STOPS FW BUFF` |
   | `CR` | `PREVENTS 0` *(verify: no effect at Long)* | `PREVENTS 2` | `PREVENTS 1` |
   | `AT` | `PREVENTS 4 BP` | `PREVENTS 4 BP` | `PREVENTS 4 BP` |
   | `DE` | `PREVENTS 1` | `PREVENTS 1` | `PREVENTS 1` |
   | `FW` | `PREVENTS 1` | `PREVENTS 1` | `PREVENTS 1` |

   Derivation: `prevented = damage_if_not_destroyed − damage_if_destroyed_at(phase)`.
   The `BS` Long-range label and the `CR` Long-range label are **not** visible in either
   reference image — verify against the Facilitator Guide before shipping. Do not invent them.
9. **The row must survive N ≠ 6.** Wolf force scales with pursuit, so plan for 1–10 ships.
   Above 7 ships, scale the silhouette band height down proportionally and drop
   `T_WOLF_CODE` by 4px. Below 4 ships, cap each column's width at 300px and centre the group —
   do not let three ships stretch across the whole screen.

### 4.6 Range bands — `P0-05`

**Now:** absent. There is a horizontal strip of ship colours directly under the wolf row, which
is actually the fleet cards' top bars showing through collapsed spacing. It reads as a stray
rainbow bar.

**Target:** three named zones down the left gutter — `LONG` at the wolf row, `MEDIUM` and `SHORT`
below — with a curved arc marking the **currently active** band.

**Fix**
- `LONG` label at `(95, 380)`, `T_BAND_GUTTER`, `INK_GHOST`.
- `SHORT` label at `(95, 573)`, `T_BAND_GUTTER`, `INK_GHOST`.
- Active band label at `(95, 478)`, `T_BAND_ACTIVE`, `CYAN`. The active band's label replaces the
  ghost one at that position.
- The arc: quadratic bezier, `p0 = (65, 500)`, `control = (960, 452)`, `p2 = (1855, 500)`. 2px
  `CYAN` stroke, plus an 8px soft additive glow underneath (`P2-21`). Sample at 64 points and
  draw with `draw_polyline`.
- Inactive band dividers are 1px dashed `RULE` at the same geometry, no glow.
- The arc moves as the phase advances: LONG → arc at y≈400, MEDIUM → y≈478, SHORT → y≈590.
  Tween the control points over 0.4s on phase change (`P2-24`).

### 4.7 Attack vectors — `P0-06`

**Now:** short straight red segments floating in the middle of the screen, connected to nothing.
They look like damage, not intent.

**Target:** dashed red bezier curves from each wolf ship down to the top edge of its target's
fleet card, with a small solid red node at the impact point.

**Fix**
- One `Control` node draws *all* vectors in `_draw()`. Do not create a `Line2D` per vector.
- Origin: `(wolf_column_center_x, 505)`. Terminus: `(target_card_center_x, card_top_y)` = `(…, 648)`.
- Curve: cubic bezier with control points pulled vertically —
  `c1 = origin + (0, 60)`, `c2 = terminus - (0, 70)`. This produces the target's characteristic
  S-curve that fans outward near the top and converges at the card.
- Sample at 48 points; draw alternating on/off segments — dash 10px, gap 8px. Width 1.5px, `ALERT`,
  `modulate.a = 0.75`.
- Impact node: filled circle r=4, `ALERT`, at the terminus, sitting **on** the card's top edge.
- Multiple wolf ships targeting the same card converge on the same node.
- Card positions must be read after layout settles:
  ```gdscript
  await get_tree().process_frame
  _card_anchors = _cards.map(func(c): return c.get_global_rect())
  queue_redraw()
  ```
  Re-run on `NOTIFICATION_RESIZED` and whenever the roster changes.
- `P2-22`: animate a dash phase offset in `_process` and `queue_redraw()` each frame — slow,
  ~20px/sec, travelling wolf → target. This sells "incoming" without being noisy at 20 feet.

### 4.8 Fleet ship cards — `P1-09` … `P1-12`, `P1-18`

**Now:** inconsistent. Cards 2, 3 and 5 have a grey fill; 1, 4 and 6 have none. Heights vary
(card 5 is taller). Index numbers are small. Ship icons are thin outlines. `SEC N` labels sit on
the divider strip above, not attached to their card. Targeted cards have a thin red border but no
glow.

**Target:** six identical-footprint cards, each with a dark translucent backing, a 3px signature
colour bar along the top edge, a large coloured index number beside a filled ship icon, the name,
a damage line, and a bottom-aligned chip row. Targeted cards get an `ALERT` border and glow.

**Fix**

- **Geometry:** `HBoxContainer`, `x` 95 → 1825, `separation = 24`, children `SIZE_EXPAND_FILL`.
  `custom_minimum_size = Vector2(0, 250)` on every card → width lands at ~268. Internal padding 18.
- **Two `StyleBoxFlat` variants** on a `PanelContainer`:

  | | `card_idle` | `card_targeted` |
  |---|---|---|
  | `bg_color` | `CARD_BG` (a≈0.85) | `CARD_BG_TARGETED` (a≈0.9) |
  | border width (all) | 1 | 2 |
  | `border_color` | `RULE` | `ALERT` |
  | `shadow_color` | — | `ALERT` at a≈0.25 |
  | `shadow_size` | 0 | 14 |
  | `corner_radius` | 0 | 0 |

  Square corners. No rounding anywhere on this screen.
- **Top colour bar:** a child `ColorRect`, full card width, 3px, `SHIP_COLOR[id]`, at the card's
  top edge — *inside* the card, above the padding. Not a separate full-width strip.
- **`SEC N`** (`P1-12`): right-aligned to the card's right edge, baseline `y = 638` — i.e. floating
  *above* the card, outside it. `T_SEC`, `SHIP_COLOR[id]`.
- **Index + icon row** (`P1-11`, `P1-10`): index number left, `T_CARD_INDEX`, `SHIP_COLOR[id]`.
  Ship icon right, **filled** silhouette in `SHIP_COLOR[id]` (v1 uses hairline outlines, which
  disappear at TV viewing distance), max height 34px. Store at
  `res://assets/silhouettes/fleet/{ship_id}.svg` as solid shapes, tinted via `modulate`.
- **Name:** `T_CARD_NAME`, `INK`, uppercase, baseline `y ≈ 775`.
- **Damage line:** `y ≈ 810`. Undamaged → a single `—` em-dash in `INK_GHOST`. Damaged →
  `◄` marker (`ALERT`, small) + number (`T_DMG_NUM`, `ALERT`) + `DMG` (`T_DMG_SUFFIX`, `ALERT`
  at a≈0.8).
- **Chip row** (`P1-18`): bottom-aligned at `y ≈ 862`, `HBoxContainer`, separation 6.
  - Ship-type chip (`SC`, `CR`, `DE`, `FW`, `AT`, `BS`): transparent fill, 1px `ALERT` border,
    `ALERT` text, height 28, h-padding 8.
  - Boarding-party chip (`4 BP`): **filled** `ALERT_DEEP`, no border, `INK` text. It must read as
    a different category — boarding is a separate resolution step, not another damage source.
- **Ordering:** cards are laid out by `index` (1–6), always, regardless of targeting or damage.
  The index is the targeting-wrap position and players read it as a physical seating order.

### 4.9 Footer — `P1-19`, `P1-20`

**Now:** wraps line in plain white with a large dead gap above it. `CANNOT BE TARGETED` is clipped
at the left edge. Entries use full formal names (`I.C.S.S. Fighter Wing Alpha 4`), which forces the
row wider than the screen. Two entry types from the target are missing entirely.

**Target:** wraps line in dim cyan, tightly spaced under the cards. Footer entries are short,
cyan, triangle-prefixed, and support an optional modifier suffix.

**Fix**
- Wraps line (`P1-20`): centred, `y = 948`, `T_WRAPS`, `CYAN_DIM`. Format unchanged:
  `TARGETING WRAPS · 7 → 1 · 0 → 6`.
- `CANNOT BE TARGETED` at `(95, 985)`, `T_FOOTER_LABEL`, `INK_DIM`.
- Entry row at `y = 1020`, `HBoxContainer`, separation 40, starting at `x = 95`.
- Each entry: `▲` glyph (`CYAN`, 14px) + short name (`T_FOOTER_ITEM`, `CYAN`) + optional value or
  modifier (`T_FOOTER_VALUE`, `CYAN` at a≈0.6).
- **Short names.** Add a `short_name` field to the ship/asset lookup table:

  | Full | Short |
  |---|---|
  | I.C.S.S. Fighter Wing Alpha | `FW ALPHA` |
  | I.C.S.S. Fighter Wing Bravo | `FW BRAVO` |
  | P.D.F. Escort Fighter Wing | `PDF ESCORT` |

- **Missing entry types.** The target shows two entries v1 does not render:
  - `▲ GORGONEION SHIELD → 2` — a defensive asset with a numeric modifier
  - `▲ VULCAN LASER` — a defensive asset with a text modifier and no number

  The footer is therefore not just "fighter wings" — it is **all assets present at the battle that
  cannot be targeted**, including active defensive systems. Generalise the data contract
  accordingly (§5). **Verify the exact Gorgoneion and Vulcan rules against the Facilitator Guide**
  before wiring their values.

### 4.10 Debug output — `P0-08`

Remove from the TV scene:
- `LIVE: maliades`
- `WOLF FORCE - 11 / 11 CAPACITY`

Neither belongs on a display twenty players are standing around. If the live-client indicator is
needed for the host, it goes on the **admin console**, not the TV. Per `CLAUDE.md`: no `print()`
in committed code — route it through the logging helper to the host console instead.

---

## 5. Data contract additions

The TV scene consumes one flat `Dictionary` snapshot. These keys are missing or need extending.
`core/` stays free of any presentation concern — it emits data, the scene decides how it looks.

```gdscript
{
	"turn": 3,                        # NEW — header TURN N
	"phase": "medium",                # targeting|long|medium|short|boarding|resolve
	"force_base": 10,
	"pursuit": 6,
	"cap": 16,
	"committed": 16,

	"wolf_ships": [
		{
			"uid": "wolf_cr_02",
			"hull": "cr",             # bs|sc|cr|at|de|fw
			"capacity": 3,            # derived from hull, included for the view
			"damage_taken": 1,        # NEW — drives pip fill state
			"returns": false,         # NEW — drives the ↻ glyph (bs, fw only)
			"target_ship_id": "aegis",
		},
	],

	"fleet_ships": [
		{
			"id": "aegis",
			"index": 1,
			"security": 9,
			"damage": 5,
			"targeted": true,
			"attackers": [
				{"label": "SC", "kind": "ship"},
				{"label": "CR", "kind": "ship"},
			],
			"boarding_parties": 0,    # renders as a "N BP" chip when > 0
		},
	],

	"targeting_wraps": [{"from": 7, "to": 1}, {"from": 0, "to": 6}],

	"untargetable": [                 # GENERALISED — was fighter-wings-only
		{"short_name": "FW ALPHA",    "value": "4",        "modifier": ""},
		{"short_name": "GORGONEION",  "value": "2",        "modifier": "SHIELD →"},
		{"short_name": "VULCAN",      "value": "",         "modifier": "LASER"},
	],
}
```

Notes:
- `ability_label` is **not** in the contract. It is derived in the view from `hull` + `phase`
  via §4.5 step 8, so the label updates on phase change without a state push.
- `display_name`, `short_name` and `color` for fleet ships come from the existing lookup table,
  keyed by `id`. Do not duplicate them into the snapshot.

---

## 6. Scene structure

```
WolfAttackTV (Control, full rect, 1920×1080)
├── Backdrop (Control)
│   ├── Gradient        (TextureRect, full rect)
│   ├── BloomTopLeft    (TextureRect, additive)
│   ├── BloomTopRight   (TextureRect, additive)
│   └── BloomTopEdge    (TextureRect, additive)
├── Header (Control)
│   ├── Title           (Label)
│   ├── TurnLabel       (Label)
│   ├── StatLine        (RichTextLabel)
│   ├── PursuitMeter    (Control, custom _draw)
│   └── Rule            (ColorRect, 1px)
├── PhaseRail (HBoxContainer)
├── RangeBands (Control, custom _draw)   # gutter labels + arc + dashed dividers
├── WolfForceRow (HBoxContainer)
│   └── WolfShipItem × N (VBoxContainer — NO PanelContainer)
│       ├── Silhouette  (TextureRect)
│       ├── CodeAndPips (Control, custom _draw)
│       ├── AbilityLine (Label)
│       └── TargetLine  (Label)
├── AttackVectors (Control, custom _draw)  # ABOVE bands, BELOW cards
├── FleetRow (HBoxContainer)
│   └── FleetShipCard × 6 (PanelContainer)
│       ├── ColorBar    (ColorRect, 3px)
│       ├── SecLabel    (Label — anchored above the card)
│       ├── IndexAndIcon(HBoxContainer)
│       ├── NameLabel   (Label)
│       ├── DamageLine  (HBoxContainer)
│       └── ChipRow     (HBoxContainer, bottom-aligned)
└── Footer (VBoxContainer)
    ├── WrapsLine       (Label, centred)
    ├── CannotLabel     (Label)
    └── UntargetableRow (HBoxContainer)
```

**Draw order matters.** `AttackVectors` sits between `RangeBands` and `FleetRow` so vectors pass
*over* the band arc but *under* the card edges — which is what makes the impact nodes read as
landing on the cards rather than floating above them.

---

## 7. Godot 4.7.1 implementation notes

- **Compatibility renderer.** No `WorldEnvironment` glow, no `BackBufferCopy` tricks. All glow is
  a pre-blurred PNG with `CanvasItemMaterial.blend_mode = BLEND_MODE_ADD`.
- **Custom drawing beats node soup.** Pursuit cells, wolf pips, band arcs and attack vectors are
  all one `_draw()` each. Roughly 60 nodes on this screen instead of ~250.
- **`queue_redraw()` on state change only.** The only per-frame redraw is `AttackVectors` (for the
  dash animation) and only while `phase` is a combat range.
- **Tracking is `FontVariation.spacing_glyph`.** Never pad strings with spaces — it breaks
  centring and word-wrap.
- **Tabular figures.** Enable the `tnum` OpenType feature on the `DATA` font so the pursuit counter
  and damage numbers do not jitter as they change.
- **Theme type variations** (`Label/TvTitle`, `Label/TvStat`, …) rather than per-node
  `theme_override_font_size`. One place to retune the whole screen.
- **`core/` stays clean.** No `Color`, no font, no pixel value in the rules engine.
  `wolf_ability_label()` returns a plain `String`; the view colours it.
- **Test the view headlessly** where possible: `wolf_ability_label()` and the pip-state derivation
  are pure functions and belong in `res://tests/`.

---

## 8. Acceptance checklist

Screenshot the running TV output at 1920×1080 and compare against `Wolf_Ships-selection.png`:

- [ ] Nothing is clipped on any edge; margins are visually equal left and right
- [ ] The background is near-black with visible crimson bloom at the top
- [ ] All text is uppercase and visibly letter-spaced
- [ ] `TURN N` is present, top right
- [ ] Pursuit meter is amber-filled to the current value; cell 10 is crimson
- [ ] The active phase is obviously larger and cyan; the others nearly vanish
- [ ] Wolf ships have no boxes around them and span the full content width
- [ ] Wolf pips show damage (some hollow, some filled) when a wolf ship is damaged
- [ ] `LONG` / `MEDIUM` / `SHORT` appear in the left gutter; a cyan arc marks the active one
- [ ] Every targeted card has a dashed red curve arriving at a dot on its top edge
- [ ] All six cards are the same height with visible backing and a coloured top bar
- [ ] Targeted cards glow red; untargeted cards recede
- [ ] Card index numbers are large and in the ship colour
- [ ] `SEC N` sits above each card, in the ship colour
- [ ] `BP` chips are filled; ship-type chips are outlined
- [ ] The footer shows short names and supports modifier suffixes
- [ ] No debug text anywhere on the screen

---

## 9. Open items — do not guess

Per `CLAUDE.md`, flag these rather than resolving them:

1. `BS` and `CR` ability labels at **Long** range — not visible in either reference image.
2. Gorgoneion and Vulcan rules — how the shield value and laser state are computed, and whether
   they always appear in the footer or only when active.
3. Signature colours for the small ships (Endeavour, Maliades, Pallas, Voyage 33-0) — needed
   before they can appear on this screen at all.
4. **Whether small ships appear on the Wolf Attack targeting table.** Already on the project's
   open-questions list; it directly determines whether `FleetRow` must handle more than six cards.
   Until answered, build `FleetRow` to handle N cards, but tune spacing for six.
