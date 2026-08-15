# DoWNE — Den of Wolves: New Eden (Electronic Edition)

## What this is

A Godot 4 application that runs a **megagame**: a live, in-person social game for
~20 players around physical tables, lasting 6–8 turns of roughly 20 minutes each.

This is **not a video game**. It is a facilitation tool. Its job is to remove
arithmetic and bookkeeping from a human host so that one person can run the event
alone, where the tabletop original needed two or more. The players are in a room
talking to each other. The software is infrastructure, not the experience.

**Consequence:** every feature must be evaluated by whether it reduces host
workload without reducing player-to-player interaction. A change that makes the
software cleverer but the room quieter is a regression.

## Hard design constraints — DO NOT "improve" these

These look like bugs or missing features. They are deliberate. Do not add
validation, verification, or automation to any of them without being asked.

1. **Scout coordinate entry accepts arbitrary typed input.**
   Scouts (AEGIS's Starlight shuttle, Shepherd's Scientist, Quellon's Explorer)
   discover jump coordinates and report them to the fleet. Some players are
   secretly Wolf agents and will report false coordinates on purpose. The rules
   explicitly tell players they can double-check a scout they suspect.
   **Never** validate typed coordinates against the real star system data,
   auto-fill them, grey out wrong options, or warn the user. The system publishes
   what was typed. Trust is the players' problem to solve — that is the game.

2. **Away missions keep their card-negotiation mechanic.**
   Players select a Mission Leader, receive cards, discard, and assign cards to
   opportunities by argument and agreement. Do not replace this with dice, a
   solo dexterity minigame, or an auto-resolver. Automate the scoring arithmetic
   (A–10 = +1–10, face cards = −5, plus shuttle bonuses); never the assignment.

3. **Wolf attacks stay a physical gathering.**
   Players with Wolf Attack consoles physically walk to the battle map. Keep the
   TV display as spectacle supporting that gathering. Do not resolve attacks
   silently in the background, and do not push the whole battle to individual
   terminals.

4. **Loyalty briefs stay on paper.** Do not build a UI for them.

5. **The host can override any state.** Every rule the engine enforces needs a
   host admin path to bypass it. Real games go off-script; the host adjudicates.
   Never make a state transition that only the engine can perform.

**General rule:** where player deception is possible, the system *facilitates*
and never *verifies*. If a change would let the software catch a liar, it is
wrong.

## Architecture

Three layers, strictly separated.

```
res://core/   Pure GDScript rules engine. Game state, resources, pursuit track,
              damage, jumps, mission scoring. RefCounted classes only.
res://net/    TCPServer, HTTP file serving, WebSocket. Transport only.
res://ui/     TV output scenes + host admin console.
res://web/    Static HTML/JS/CSS served to phones and browser terminals.
```

**`core/` must never reference `Node`, `get_tree()`, `Engine`, or any scene.**
This is what lets the rules be tested headlessly. If you need to notify something,
emit a signal from a `RefCounted` and let the caller wire it up.

Layers talk downward only. `ui/` may read `core/`. `core/` knows nothing about
`net/` or `ui/`.

### Runtime topology

Godot runs **natively on the host laptop**. It is the server. It is never
exported to web — a browser cannot listen on a socket.

Clients are:
- 12 ESP32-S3 terminals (ships, shuttles, fighter wings) over WebSocket
- Player phones on static pages served from `res://web/`, for secret information
  (loyalties, suspicion, secret objectives), reached by QR code
- A browser-based terminal client, which is both the playtest path and the
  hardware-failure fallback. **Keep it working.** If a terminal dies mid-game the
  player picks up a phone and carries on.

All of this runs on a GL.iNet travel router with **no assumption of internet
access**. Never add a runtime dependency on an external service or CDN.

### Networking

- One `TCPServer`. Sniff the request: `Upgrade: websocket` → `WebSocketPeer.accept_stream()`,
  otherwise serve a static file from `res://web/`.
- Set `write_mode = WebSocketPeer.WRITE_MODE_TEXT` so browsers receive strings.
- **Do not use Godot's high-level multiplayer / RPC.** Clients are ESP32s and
  browsers, not Godot peers.
- Messages are flat JSON with a `type` field. Keep payloads small — the ESP32s
  parse them on limited RAM.

### Persistence

Dump full game state to JSON on every mutation, to `user://`. Crash recovery
matters more than performance: the failure mode is twenty people standing around
while the host restarts something.

## Conventions

- GDScript, tabs, static typing where it costs nothing (`var x: int = 0`).
- `snake_case` for files, functions, variables. `PascalCase` for classes.
- Ship and shuttle identifiers are lowercase snake_case internally
  (`refinery_124`, `fighter_wing_alpha`) and display names come from a single
  lookup table. Never hardcode display strings in logic.
- No `print()` in committed code; use a single logging helper that also writes to
  the host console.

## Commands

```bash
godot --headless --script res://tests/run_tests.gd   # rules engine tests
godot .                                              # run the host application
```

Write a test in `res://tests/` for any change to `core/`.

## Domain glossary

- **Turn** — one Team Phase (5 min) + one Coordination Phase (15 min). 6–8 per game.
- **Resources** — strytium ore, strytium fuel, food, water, material. Cannot move
  between ships without an appropriate shuttle.
- **Pursuit Track** — 0–10. Rises over time, falls on jumps away from Wolf space.
  Reaching 10 ends the game in failure. Drives Wolf attack strength.
- **Jump** — requires charged drive, sufficient strytium fuel, and coordinates
  written on the ship's sheet. Adjudicated during the Coordination Phase.
- **Console** — a ship subsystem that can be damaged, repaired, or upgraded.
- **Star systems** — lettered (A, B, C…), each with a description and away mission
  opportunities rated by difficulty and skill type (mining, salvage, science,
  engineering, search & rescue).
- **Wolf agent** — a player secretly working for the enemy. There may be more than
  one. The system must never reveal or infer who they are.

## Ships

| Ship | Supplies | Notes |
|---|---|---|
| AEGIS | Military | Fighter Wings Alpha & Bravo, Starlight scout shuttle, assault shuttle |
| Dione | — | Carries the Interstellar Council President and many survivors |
| Icebreaker | Materials, ore | |
| Shepherd | Food | Has a Scientist who can scout |
| Quellon | Water, upgrades | Has an Explorer who can scout |
| Refinery 124 | Strytium fuel | |
| Endeavour | — | Research lab, science devices |
| Maliades, Pallas | — | Additional ships |
