# Wolf Attack — Public TV Display Specification

A build brief for the large-screen display shown during Wolf Attacks. Written to
be implemented directly in Godot 4.7.1 (Compatibility renderer, GDScript) by
someone who has not read the DoWNE rulebooks.

---

## 1. What this screen is for

During a Wolf Attack, players carrying combat consoles physically leave their
tables and gather at the battle table. That gathering is deliberate game design —
it is the spectacle event of the session and **must not be replaced by
automation**. The physical Wolf ship cards, dice and damage markers remain the
source of truth for what happens.

This display does three things and nothing else:

1. **Aggregate state at a glance.** Twenty people standing around a table cannot
   all read a card. The screen shows who is being shot at and by how much.
2. **Arithmetic.** Running damage totals, threat-if-unopposed, boarding party
   counts, damage-prevented-by-killing-this-now. All derived, never decided.
3. **Drama.** The targeting reveal, the damage ticking up, the boarding
   countdown. This is the screen everyone is looking at during the loudest five
   minutes of the game.

It does **not** resolve combat, roll dice, choose targets, or tell players what to
do. The host drives it from the admin console on the laptop screen.

## 2. Hard rule — what must never appear

The game contains hidden traitors. The TV is visible to every player including
Wolf Agents, and to the Wolf Commander player if that role is in play.

**Never render on this display:**

- Any loyalty, suspicion value, or secret objective.
- Pre-rolled targeting results before the reveal step. The Facilitator Guide
  instructs the host to lay out cards and pre-roll targeting *before* announcing
  the attack. The system will therefore be holding targeting data that must stay
  hidden until the Targeting phase runs.
- Scouting results, star system data, or away mission difficulties.
- Anything from another ship's private state that isn't already public at the
  battle table.

Treat the targeting reveal as a security boundary: the view model handed to this
screen during the pre-attack state must not *contain* the targets, not merely
avoid drawing them. A leak here is a leaked traitor mechanic.

## 3. Physical assumptions

- 16:9 TV, design resolution **1920×1080**, driven as a second display from the
  host laptop. Assume it may actually be 4K and scale.
- Viewing distance **2–5 metres**, standing, in a lit room, at an angle.
- No interaction. Nobody touches this screen.
- It must be readable by someone glancing up mid-argument.

Consequences: minimum body text **32 px**, labels **48 px**, hero numbers **140 px+**.
High contrast. No thin font weights. No information conveyed by colour alone.

---

## 4. Visual language

### Palette

Dark ground, luminous elements — reads well on a TV and matches the setting.

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0B0E14` | Screen background |
| `panel` | `#141922` | Card and panel fill |
| `panel_raised` | `#1D2531` | Active/highlighted panel |
| `rule` | `#2A3444` | Borders, dividers |
| `text_primary` | `#E8EDF5` | Headings, numbers |
| `text_muted` | `#7A8699` | Labels, secondary |
| `wolf` | `#D94A4A` | All Wolf-side elements |
| `wolf_dim` | `#5C2626` | Destroyed Wolf ships |
| `alert` | `#F5C043` | Warnings, boarding, urgency |
| `ok` | `#4CAF7D` | Neutralised threats, safe states |

### Ship identity colours

Every capital ship gets a colour **and** a two-letter code **and** a fixed screen
position. Never rely on colour alone.

| Ship | Code | Hex |
|---|---|---|
| AEGIS | `AG` | `#4A90D9` |
| Dione | `DI` | `#A97BD9` |
| Icebreaker | `IB` | `#9FD4E8` |
| Quellon | `QU` | `#4CAF7D` |
| Shepherd | `SH` | `#E0A63C` |
| Refinery 124 | `R124` | `#E06B3C` |

Fleet ships always appear left-to-right in **targeting-table order**: AEGIS,
Dione, Icebreaker, Quellon, Shepherd, Refinery 124. That order matches the d6
targeting roll (1–6), so players learn the position and can read the screen
against the physical dice without translating.

### Typography

- **Display / numbers**: a condensed geometric sans in heavy weight. Match the
  printed component sheets if you can obtain that face; otherwise Oswald or
  Barlow Condensed SemiBold.
- **Body / labels**: same family, regular weight, letter-spaced +2% for the
  small uppercase labels.
- All labels uppercase. All numbers tabular/lining.

### Motion

The Compatibility renderer is in use — **no particle systems, no screen-space
shaders, no post-processing**. Everything animates through `Tween` on `modulate`,
`scale`, `position` and `Control` anchors. That is enough.

- Standard transition: **250 ms**, `Tween.EASE_OUT`, `Tween.TRANS_CUBIC`.
- Damage tick: number counts up over **400 ms** with a 1.15× scale pulse.
- Destruction: token desaturates to `wolf_dim`, scales to 0.9, a diagonal strike
  line draws across it over **300 ms**.
- Targeting reveal: staged, see §5.2. This is the only sequence allowed to take
  more than a second.

Never animate for longer than the host is willing to wait. If the host advances
the phase mid-animation, **snap to the end state immediately**.

---

## 5. Screen states

The display is a state machine with six states, driven by the host. Each state
has one job; layout changes between them rather than cramming everything on at
once.

```
IDLE → INCOMING → TARGETING → RANGE(long) → RANGE(medium) → RANGE(short) → BOARDING → RESOLUTION → IDLE
```

The host can move backwards. The display must never assume forward-only.

---

### 5.1 `INCOMING` — attack announced

The gathering screen. Its job is to give twenty people twenty seconds to walk
across the room, and to set the stakes.

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    W O L F   A T T A C K                   │  200px, wolf red
│                                                            │
│                     ALL SHUTTLES DOCK NOW                  │  56px, alert
│                                                            │
│   ┌──────────────────────────────────────────────────┐    │
│   │  4  FIGHTER WINGS      2  ASSAULT TRANSPORTS     │    │
│   │  2  CRUISERS           1  BATTLESTATION          │    │  Composition,
│   └──────────────────────────────────────────────────┘    │  icons + counts
│                                                            │
│              TOTAL DAMAGE CAPACITY   ██ 21 ██              │  140px
│                                                            │
│   PURSUIT 6/10                          TURN 4             │
└────────────────────────────────────────────────────────────┘
```

- Composition is public — the cards are face up on the table anyway.
- "Total damage capacity" is the sum of every Wolf ship's capacity. It is the
  headline threat number and the one thing players will remember.
- **No targets shown.** They are not yet revealed.
- Slow pulse on the title, 2 s cycle, `modulate.a` 1.0 → 0.75. Nothing else moves.

---

### 5.2 `TARGETING` — the reveal

The single most dramatic moment. Wolf ships are assigned targets by a d6 roll
against the targeting table (1 AEGIS, 2 Dione, 3 Icebreaker, 4 Quellon, 5
Shepherd, 6 Refinery 124).

Layout transitions to the **standing layout** (§5.3) but with all Wolf tokens
grey and all threat counters at zero. Then, one Wolf token at a time:

1. Token scales to 1.2× and flashes white — **150 ms**
2. Token's target band fills with the target ship's colour — **150 ms**
3. A line draws from the token to that ship's card — **200 ms**, then fades
4. That ship's incoming-threat number ticks up — **200 ms**

Total **~700 ms per Wolf ship**, but **overlap them at 250 ms intervals** so a
15-ship attack reveals in about four seconds rather than eleven. Reveal in
descending threat order: battlestations first, fighter wings last.

**Retargeting is possible after the reveal** and must be animated the same way:

- The Wolf Commander player (if in play) may re-roll any targeting dice once, and
  may shift one ship's targeting die by 1 in each range phase (6 wraps to 1, 1
  wraps to 6).
- The AEGIS's Command and Control console may force one Wolf ship to retarget the
  AEGIS. This resolves *after* the Wolf Commander's re-roll.
- Fleet fighter wings and the Maliades may shift a Wolf ship's target number ±1
  at medium range, with the same wrap (a 0 hits Refinery 124, a 7 hits the AEGIS).

So target assignment is **mutable throughout the attack**. When a token retargets,
play the reveal animation again for that token only, and tick the old target's
threat number down as the new one ticks up. Players will be watching for exactly
this — it's the payoff for spending a console on it.

---

### 5.3 `RANGE` — the standing layout (long / medium / short)

This is where most of the attack is spent. One layout, three variants.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WOLF ATTACK · TURN 4    ○ TARGETING ● LONG ○ MEDIUM ○ SHORT ○ BOARD │ 110px
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  WOLF FORCE                                    17 / 21 CAPACITY      │
│                                                                      │
│   ┌────┐ ┌────┐   ┌────┐ ┌────┐ ┌────┐ ┌────┐                       │
│   │ BS │ │ SC │   │ CR │ │ CR │ │ DE │ │ DE │                       │ 460px
│   └────┘ └────┘   └────┘ └────┘ └────┘ └────┘                       │
│   ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐   ┌────┐┌────┐                   │
│   │FW││FW││FW││FW││FW││FW││FW││FW│   │ AT ││ AT │                   │
│   └──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘   └────┘└────┘                   │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐        │
│  │ AEGIS  ││ DIONE  ││ICEBRKR ││QUELLON ││SHEPHERD││ R124   │        │ 380px
│  │        ││        ││        ││        ││        ││        │        │
│  │   7    ││   3    ││   0    ││   1    ││   0    ││   4    │        │
│  │INCOMING││INCOMING││ CLEAR  ││INCOMING││ CLEAR  ││INCOMING│        │
│  └────────┘└────────┘└────────┘└────────┘└────────┘└────────┘        │
├──────────────────────────────────────────────────────────────────────┤
│  LONG RANGE · FLEET GUNS LIVE:  AEGIS MISSILE LAUNCHERS · GORGONEION │ 130px
└──────────────────────────────────────────────────────────────────────┘
```

#### Wolf token component

Fixed aspect square. Size flows with count: **150 px** at ≤16 tokens, **120 px** at
≤25, **100 px** beyond. Auto-wrap, grouped by class, classes ordered by threat:
Battlestation → Strikecarrier → Cruiser → Destroyer → Assault Transport →
Fighter Wing.

```
┌──────────────┐
│ ████████████ │  ← target band, 12px, target ship's colour
│              │
│      CR      │  ← class code, 44px
│   ● ● ○      │  ← damage pips, filled = damage taken
│              │
│  PREVENTS 3  │  ← 24px, current-phase kill value
└──────────────┘
```

- **Target band**: solid fill in the target ship's colour, with the ship's 2-letter
  code in the band at 20 px so colour is never the only cue.
- **Damage pips**: one per point of damage capacity, max 6. Filled pips in `wolf`,
  empty in `rule`.
- **Destroyed**: whole token drops to `wolf_dim`, diagonal strike through, pips
  all filled, `PREVENTS` line replaced by `DESTROYED`.
- **Returns next attack**: small ↻ glyph, top-right corner. Battlestations and
  Fighter Wings carry it, and it is the *only* reason to kill a battlestation
  early, so it must be visible.
- **Immune this phase**: at Short Range a Battlestation cannot be damaged at all.
  Render it with a hatched overlay and the label `IMMUNE — SHORT`.

#### The `PREVENTS` value

This is the screen's most useful derived number: **how much damage the fleet
avoids by destroying this Wolf ship during the current phase**, computed as
(damage if it survives) − (damage if destroyed now).

| Class | Cap | Long | Medium | Short | Notes |
|---|---:|---:|---:|---:|---|
| Battlestation | 6 | 0 | 0 | — | Deals 3 either way. Killing it only stops its return. Cannot be damaged at short range. |
| Strikecarrier | 5 | *n* | *n* | *n* | Deals 2 either way, but if it survives every surviving Wolf Fighter Wing does +1 damage. *n* = live fighter wing count, **recompute every time a fighter wing dies** |
| Cruiser | 3 | 3 | 2 | 1 | |
| Destroyer | 2 | 1 | 1 | 1 | |
| Fighter Wing | 1 | 1 | 1 | 0 | Also stops its return |
| Assault Transport | 2 | — | — | — | Deals no damage. Show `4 BOARDERS` instead of a number |

The Strikecarrier's dynamic value is the interesting one — it silently becomes
the highest-value target in a fighter-heavy attack, and the screen should surface
that without a human doing the multiplication.

#### Ship card component

```
┌──────────────────┐
│ ██ AEGIS      AG │  ← 16px colour bar, name 40px
│                  │
│        7         │  ← incoming threat, 150px
│    INCOMING      │  ← 26px muted
│                  │
│  ─────────────   │
│  DAMAGE THIS     │
│  ATTACK    ● ●   │  ← taken so far, 32px
│                  │
│  SEC TEAMS   9   │
│  ⬡ PALLAS        │  ← docked craft offering boarding support
└──────────────────┘
```

- **Incoming threat** = sum of damage that will land on this ship if nothing else
  is destroyed. Recompute on every state change. This is the number players
  argue over, so it must be instant and obviously live — pulse it on change.
- `CLEAR` in `ok` green when zero. `INCOMING` in `wolf` when nonzero. Above 6,
  switch the whole card border to `alert` and pulse slowly.
- **Boarding indicator**: if any surviving Assault Transport targets this ship,
  add a red banner across the card bottom: `⚔ 8 BOARDERS INBOUND`.
- Ships with no incoming and no boarders dim to 60% opacity so the eye goes
  straight to the ones under fire.

#### Phase bar (bottom, 130 px)

Per-phase reminder of what the fleet can actually shoot with. Derived from
console states, so damaged consoles drop off the list — which is itself useful
information the players will otherwise forget.

| Phase | Live fleet weapons |
|---|---|
| **Long** | AEGIS Missile Launchers (2 dmg to 1 target; +1 if ore-enriched) · Gorgoneion Missile Array (3 dice, 6+) |
| **Medium** | AEGIS Missile Launchers (4 dice, 5+; 4+ if enriched) · AEGIS Point Defence Lasers (2 dice, 4+) · Fighter Wings · Maliades · Highwall (if fuelled) · Gorgoneion (3 dice, 5+) · Vulcan Laser Cannon (2 dice, 4+) |
| **Short** | AEGIS Point Defence Lasers (2 dice, 2+) · Fighter Wings · Maliades · Highwall (if fuelled) · Gorgoneion (3 dice, 4+) · Vulcan Laser Cannon (2 dice, 4+) |

**Short Range carries a mandatory rule that must be shown as a banner, not a
footnote**, because players forget it and it changes every targeting decision:

> ⚠ ALL FLEET DAMAGE MUST BE ASSIGNED TO WOLF FIGHTER WINGS FIRST

Show it in `alert` across the full width whenever the phase is Short and at least
one Wolf Fighter Wing is alive. Drop it the moment the last one dies.

---

### 5.4 `BOARDING`

Layout switches entirely. Only ships with inbound boarders are shown, enlarged.
Everything else disappears — this phase concerns two or three ships at most.

```
┌──────────────────────────────────────────────────────────────────────┐
│ WOLF ATTACK · TURN 4    ○ ─── ○ ─── ○ ─── ○ ─── ● BOARDING ACTION   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌───────────────────────────┐  ┌───────────────────────────┐      │
│   │ ██ AEGIS                  │  │ ██ DIONE                  │      │
│   │                           │  │                           │      │
│   │    8          9           │  │    4          2           │      │
│   │ BOARDERS   SEC TEAMS      │  │ BOARDERS   SEC TEAMS      │      │
│   │                           │  │                           │      │
│   │ ⬡ PALLAS DOCKED           │  │ ⬡ PHILIA DOCKED           │      │
│   │   re-roll up to 3 dice    │  │   security teams may       │      │
│   │                           │  │   defend                   │      │
│   └───────────────────────────┘  └───────────────────────────┘      │
│                                                                      │
│              ┌─────────────────────────────────┐                    │
│              │   BOARDING DEFENCE — ROLL 1d6   │                    │
│              │   1     SECURITY TEAM DIES      │                    │
│              │   2-3   NO EFFECT               │                    │
│              │   4+    WOLF ASSAULT TEAM DIES  │                    │
│              └─────────────────────────────────┘                    │
└──────────────────────────────────────────────────────────────────────┘
```

- Each surviving Assault Transport contributes **4 boarding parties** to its
  target.
- **Two transports on one ship is lethal** — the Facilitator Guide explicitly
  warns the host to watch for this during the first attack. When a ship has 8+
  boarders and fewer security teams, put a `⚠ CRITICAL` flag on that card.
- Docked craft that grant boarding support must be listed with what they actually
  do, since the abilities differ: the Pallas re-rolls up to 3 dice, the Chepu and
  the engineering/service shuttles simply enable the docked ship's security teams,
  and the AEGIS itself re-rolls up to 3 dice from its own battle sheet.
- The Pallas and Chepu can **move to a ship of their choice at the start of this
  step if fuelled**, so a card's support line must be able to change during this
  phase. Animate the shuttle glyph flying from one card to another.
- If the Wolf Commander role is in play they may personally lead a boarding
  action for **+2 boarding parties**, decided before the Pallas and Chepu act.
  Show it as a distinct `⚔ WOLF COMMANDER LEADING +2` strip.
- The defence table stays on screen throughout — the host is rolling a lot of
  dice and should not have to remember it.

Boarding counters tick down live as the host resolves rolls. Each removal is a
250 ms fade and a count decrement. That decrementing number is the tension.

---

### 5.5 `RESOLUTION`

After boarding, every surviving Wolf ship damages its target and jumps away.

```
┌──────────────────────────────────────────────────────────────────────┐
│                      A T T A C K   E N D S                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   AEGIS       ● ● ● ● ●   5 DAMAGE      −1,250 SURVIVORS             │
│   DIONE       ● ●         2 DAMAGE      −5,000 SURVIVORS             │
│   ICEBREAKER  —           NO DAMAGE                                  │
│   QUELLON     ●           1 DAMAGE      −2,000 SURVIVORS             │
│   SHEPHERD    —           NO DAMAGE                                  │
│   R124        ● ● ●       3 DAMAGE      −3,000 SURVIVORS             │
│                                                                      │
│   ─────────────────────────────────────────────────────────────      │
│                                                                      │
│   WOLF LOSSES     14 OF 17 DESTROYED                                 │
│   RETURNING       ↻ 1 BATTLESTATION · ↻ 2 FIGHTER WINGS              │
│                                                                      │
│   FLEET POPULATION   211,250   ▼ 11,250                              │
└──────────────────────────────────────────────────────────────────────┘
```

- Damage is displayed as pips per ship, matching the physical damage cards the
  players are about to draw.
- **Survivor loss is an inference — confirm before building.** The rules state
  survivors die from all damage a ship sustains, and each point of damage draws
  one card from that ship's damage deck. The most likely reading is that each
  damage point moves the population track down one step, except when the damage
  hits an Armoured Hull console (AEGIS only), which explicitly prevents survivor
  loss. **Do not ship the survivor column until this is confirmed** — put it
  behind a flag and show only the damage pips in the meantime.
- The `RETURNING` line is important and easy to miss: Battlestations and Fighter
  Wings that survive come back in the next attack. Players should leave the table
  knowing what they failed to kill.
- Hold this screen until the host dismisses it. It's the debrief.

---

## 6. Data contract

The display is a **pure function of a snapshot**. It contains no rules logic,
holds no authoritative state, and never mutates anything. The rules engine in
`res://core/` produces this dictionary; the presentation layer renders it.

```gdscript
# res://core/combat/wolf_attack_view.gd — plain data, no Node
{
    "phase": "range_medium",   # incoming | targeting | range_long |
                               # range_medium | range_short | boarding |
                               # resolution
    "turn": 4,
    "pursuit": 6,

    "wolf_ships": [
        {
            "id": "wolf_cruiser_2",       # stable across the attack
            "class": "cruiser",           # battlestation | strikecarrier |
                                          # cruiser | destroyer |
                                          # fighter_wing | assault_transport
            "capacity": 3,
            "damage_taken": 1,
            "destroyed": false,
            "target": "dione",            # null while phase == "incoming"
            "returns_if_survives": false,
            "immune_this_phase": false,
            "prevents": 2,                # derived; null for transports
            "boarders": 0,                # 4 for a surviving transport
        },
    ],

    "fleet_ships": [
        {
            "id": "aegis",
            "incoming_damage": 7,          # derived from live wolf ships
            "damage_this_attack": 2,
            "security_teams": 9,
            "boarders_inbound": 8,
            "support_craft": [
                {"id": "pallas", "effect": "reroll_3"},
            ],
            "critical": true,              # boarders > security_teams
        },
    ],

    "live_fleet_weapons": ["aegis_missile_launchers", "fighter_wing_alpha"],
    "wolf_commander_leading_boarding": false,
    "fighter_wings_alive": 8,              # drives strikecarrier "prevents"
}
```

Notes for the implementer:

- `prevents` and `incoming_damage` are computed in `core/`, not in the UI. They
  are game rules, and they need tests. The UI must not do the arithmetic.
- Wolf ship `id` must be stable for the whole attack so the UI can animate a
  specific token rather than rebuilding the grid. Never reorder the array
  between frames; append and mutate in place.
- The `incoming` phase snapshot must **omit** the `target` field entirely rather
  than sending null-but-populated data. See §2.

The rules engine emits one signal on change; the display rebinds and tweens the
diff:

```gdscript
signal wolf_attack_view_changed(view: Dictionary)
```

---

## 7. Godot implementation notes

### Second-window setup

The admin console runs on the laptop's own display; this screen is a separate
`Window` node targeting the TV.

```gdscript
# res://presentation/tv/tv_window.gd
extends Window

func _ready() -> void:
    var screens := DisplayServer.get_screen_count()
    current_screen = 1 if screens > 1 else 0
    content_scale_size = Vector2i(1920, 1080)
    content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
    borderless = true
    mode = Window.MODE_FULLSCREEN
    unresizable = true
```

Handle `screens == 1` gracefully — during development and during a hardware
failure at the venue there may be no second display. Fall back to a windowed
1280×720 on the primary screen rather than crashing or drawing offscreen.

### Scene structure

```
TvWindow (Window)
└── BattleDisplay (Control, full rect)
    ├── TopBar (Control)
    │   ├── AttackLabel
    │   ├── PhaseTracker
    │   └── PursuitReadout
    ├── StateContainer (Control)      # only one child visible at a time
    │   ├── IncomingScreen
    │   ├── StandingScreen            # targeting + all three range phases
    │   │   ├── WolfGrid (Control, custom flow layout)
    │   │   └── FleetRow (HBoxContainer)
    │   ├── BoardingScreen
    │   └── ResolutionScreen
    └── PhaseBanner (Control)         # bottom bar / short-range warning
```

- `WolfToken` and `ShipCard` are separate scenes instanced into their containers.
- Use a **custom flow container** for `WolfGrid`, not `GridContainer` — token size
  must respond to token count, and `GridContainer` fixes columns rather than
  sizing children.
- `StateContainer` swaps children via `visible`, not `queue_free`, so returning
  to a previous phase is instant and animation state is preserved.

### Compatibility renderer constraints

Confirmed target is the Compatibility (GL) renderer, so:

- No `GPUParticles2D` — use `CPUParticles2D` if particles are genuinely needed,
  or preferably no particles at all.
- No screen-space shaders, no `BackBufferCopy`, no glow via `WorldEnvironment`.
  The "luminous" look comes from colour choice and a pre-baked glow texture
  behind bright elements, not post-processing.
- Prefer `Tween` over `AnimationPlayer` for anything data-driven, since token
  counts vary per attack.

### Fonts

Load one variable font at two weights. Set `TextServer` subpixel positioning off
and use integer font sizes — TVs often apply their own sharpening and subpixel
text can shimmer at distance.

Define every size as a constant in one theme resource so the whole screen can be
scaled up in one edit after the first venue test. **Expect to increase every size
by 10–20% after seeing it on the actual TV.** That is normal and the reason to
centralise it.

---

## 8. Host input model

The TV cannot exist without an input path, and DoWNE targets a **single host**.
Input burden is therefore a design constraint on this screen, not a separate
concern. Spec'd here only far enough to bound the display work.

The host is standing at the battle table, not sitting at the laptop. Assume the
admin console is reached via a tablet or phone on the local network, or the
laptop is on the battle table.

Minimum input set during an attack:

| Action | Frequency | Target interaction |
|---|---|---|
| Advance / retreat phase | 5–6 per attack | Two large fixed buttons |
| Add 1 damage to a Wolf ship | very high | Single tap on a token |
| Destroy a Wolf ship | high | Tap when damage reaches capacity — should auto-destroy |
| Retarget a Wolf ship | occasional | Tap token, tap ship |
| Decrement boarders / security teams | high, boarding only | Single tap |

Auto-destroying a token when `damage_taken == capacity` removes the single most
frequent redundant action. Damage must also be **removable** — players
miscount, and the host needs to undo without a modal.

Everything else — dice, decisions, arguments — stays physical.

---

## 9. Open questions

Resolve these before or during the build; do not guess.

1. **Survivor loss per damage point.** §5.5. Blocking for the resolution screen.
2. **Are Small Ships targetable?** The targeting table lists only the six capital
   ships, and Small Ships "cannot take damage" — which suggests the Gorgoneion,
   Capybara, Warrior and Vulcan never appear as targets and so never appear on
   the fleet row, only in the live-weapons list. Confirm.
3. **Does the fleet row show ships that have been destroyed or abandoned earlier
   in the game?** A destroyed ship shouldn't occupy a sixth of the screen, but
   removing it breaks the fixed targeting-table positions players have learned.
   Recommend keeping the slot, rendering it as a struck-through `LOST` placeholder.
4. **Multiple simultaneous attacks.** Systems L, M and P trigger repeated attacks
   until the Wolf base is destroyed. Is that a new attack instance each time
   (screen resets to `INCOMING`) or a continuation? Recommend a new instance with
   a round counter in the top bar.
5. **Screen resolution at the venue.** Design at 1080p, but confirm before the
   first playtest — if it's a 4K panel the content scaling above handles it, but
   font hinting will want checking.
