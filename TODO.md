# DoWNE — build roadmap

Status snapshot as of the four scaffolding commits (`275b6d9`..`e058a65`). Not
a spec — the spec is CLAUDE.md and `downe_shuttle_implementation_prompt.md`.
This tracks what's built vs. what's still needed to run a real game.

## Done — scaffolding (all four layers wired end-to-end)

- **core/**: `Ship`, `Console`, `ResourceStock`, `PursuitTrack`, `TurnManager`
  (Team/Coordination phases only, no step structure), `GameState`,
  `StarSystem` + `AwayMissionOpportunity` (card-scoring arithmetic only, no
  data), `JumpResolver`, `ShipRegistry` (9 ship ids + display names).
- **net/**: `NetMessage` (flat JSON envelope), `HttpStaticFiles` (path
  resolution + content types), `MessageRouter` (routes 2 message types:
  `set_jump_coordinates`, `set_drive_charged`), `Persistence` (autosave to
  `user://` on mutation, `load_dict()`), `NetServer` (TCPServer sniffing
  WebSocket-upgrade vs. static file, one port for everything).
- **ui/**: `DisplayFormat` (pure formatting), `TVDisplay` (read-only:
  turn/phase + pursuit bar only), `HostConsole` (advance phase, force
  pursuit track, read-only ship list), `Main` composition root wired as
  `run/main_scene`.
- **web/**: browser terminal client (`index.html`/`app.js`/`style.css`) —
  ship picker, freeform coordinates field, drive toggle. This is also the
  ESP32 hardware-failure fallback per CLAUDE.md.
- **tests/**: 10 headless test files, `run_tests.gd` walks `tests/`
  recursively. All passing.

None of this has real game content yet — it's plumbing. A game cannot
actually be run with what exists today: there's no starting fleet, no star
systems, no shuttles, no Wolf Attack data.

## Blocked — need your answers before any code gets written

These came up while reading `downe_shuttle_implementation_prompt.md`; it
already says "ask, do not guess" and I'm holding to that:

- [ ] **Mining operations**: does one operation yield *both* the 1d6
      materials and the 3d6 strytium ore, or does the operator pick one?
- [ ] **Cargo/hold capacities**: per-craft resource caps and starting
      loadouts aren't recorded anywhere yet.
- [ ] **`ally` and `wobbly` home ship**: both operated by the Joint
      Engineering Union Engineer, starting dock unspecified.
- [ ] **`endeavour` and `maliades` home bay**: not stated in the brief.

Same category, not yet asked, needed before the corresponding systems can
be built:

- [ ] **Star systems**: the lettered roster (A, B, C…), descriptions, and
      away-mission opportunities (skill + difficulty) — `StarSystem` and
      `AwayMissionOpportunity` exist as empty containers with no data.
- [ ] **Starting fleet setup**: each ship's starting consoles, resource
      loadout, and capacities. Nothing currently populates a fresh
      `GameState` with the real scenario — `add_ship()` has to be called
      manually per ship with no seed data behind it.
- [ ] **Wolf Attack data**: Wolf ship roster, attack-strength scaling off
      the pursuit track, battle-table numbers. Only the pursuit track
      itself (0–10, rise/fall) exists; nothing about what an attack does.
- [ ] **Suspicion / secret objectives**: CLAUDE.md's Runtime topology
      mentions player-phone pages for these, but there's no data model or
      content for either yet (loyalty itself is explicitly paper-only, no
      UI — that one's settled).
- [ ] **Turn phase structure**: the shuttle brief references "Team Phase
      Maintenance Step 6" — implying Team Phase has an internal step
      sequence the host needs to be walked through. `TurnManager` currently
      only has two flat phases, no steps.

## Next up — core/craft system (fully specified, ready to build)

Per `downe_shuttle_implementation_prompt.md`, once the 4 open questions above
are answered:

- [ ] `core/craft/craft_definitions.gd` — static roster (14 shuttles + 3
      fighter wings) as data, not per-craft classes.
- [ ] `core/craft/craft_state.gd` — per-craft mutable state (fuelled,
      docked ship, damage track, fighter count, cargo contents).
- [ ] `core/craft/ability_registry.gd` + `core/craft/abilities/*.gd` — one
      file per ability (`cargo_transfer`, `boarding_support`,
      `boarding_support_elite`, `redeploy`, `repair`, `recharge`,
      `scout_system`, `console_upgrade`, `mining_operations`,
      `resource_harvesting`, `away_mission`, `combat_table`), each with
      `can_execute()` (returns a reason on failure) and `execute()`.
      Abilities take a seeded RNG from `GameState`, never call `randi()`
      directly, so games are reproducible from the JSON dump.
- [ ] Fuel-clears-at-end-of-turn, wired into `TurnManager`'s phase
      advancement.
- [ ] Storage-console-damage resource halving (including docked shuttles),
      with the specific rounding rule from the brief tested at value 5.
- [ ] Combat profiles (Maliades, Highwall, fighter wings) as reference
      data + arithmetic helpers only — no automated resolver (constraint 3
      still applies: Wolf Attacks stay a physical gathering).
- [ ] Host-override setters for every value this layer owns (fuel flag,
      docking, fighter count, Maliades damage, cargo contents), per
      constraint 5.
- [ ] The test list already specified in the brief's §6 (fuel clearing,
      `requires_fuel` rejection reasons, repair costs/caps, consent-gated
      console damage, storage halving, cargo-type rejection, fighter
      launch preconditions, Maliades destruction at exactly 3 damage, and
      a table-driven test that every craft's declared ability IDs resolve
      against the registry).

## Backlog — plumbing gaps in what's already scaffolded

- [ ] **Broadcast wiring**: `NetServer.send()`/`broadcast()` exist but
      nothing calls them — connected web/ESP32 clients never get pushed
      state updates when someone else mutates `GameState`. Right now the
      web terminal is fire-and-forget only.
- [ ] **Crash-recovery rehydration**: `Persistence.load_dict()` exists but
      nothing turns that dict back into a live `GameState` on startup —
      `main.gd` doesn't call it. Needs a `GameState.from_dict()`
      (`Ship.from_dict()`, etc.) counterpart to `to_dict()`.
- [ ] **Host console completeness**: only pursuit track and turn phase
      have override controls right now. Per-ship resource/console editing,
      direct jump-coordinate override, and (once it exists) craft admin
      controls are all missing — most state still has no host bypass path,
      which is a direct gap against constraint 5.
- [ ] **TV display completeness**: currently just a turn/phase line and a
      text pursuit bar. No ship status overview, no Wolf Attack support
      screen, no jump/scout announcement feed.
- [ ] **Deployment**: no export preset configured; no plan yet for how the
      12 ESP32 terminals discover the host's IP on the GL.iNet router
      (static IP? mDNS?). ESP32 firmware itself is out-of-repo work in a
      different codebase.
- [ ] **Player phone pages** (`web/`): only the ship terminal exists.
      Suspicion and secret-objective pages need their data model settled
      (see Blocked, above) before they can be built.
