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

## Answered

From `downe_shuttle_implementation_prompt.md`'s open questions:

- [x] **Mining operations**: the operator picks one (materials or ore) per
      operation, and gets 2 operations per turn (3 if `requires_fuel`),
      choosing independently each time.
- [x] **Cargo/hold capacities**: per-ship starting resources are in
      `resources.md`. Caps themselves are *still* unspecified there too —
      treat as uncapped (`-1` placeholder) for now, as the brief already
      suggested.
- [x] **`ally` and `wobbly` home ship**: `ally` → Quellon, `wobbly` →
      Shepherd.
- [x] **`endeavour` and `maliades` home bay**: Endeavour → Shepherd,
      Maliades → Dione.

Also resolved along the way:

- [x] **`material` vs `materials` naming**: standardized on **materials**
      (plural) — matches the printed sheets and `resources.md`. Renamed
      `ResourceStock.Kind.MATERIAL` → `MATERIALS` and fixed CLAUDE.md's
      glossary line to match (commit pending).

## Newly available — `resources.md`

An untracked `resources.md` already in the repo (from the *DoWNE
Facilitator Guide v1.0.1*, p.5) covers most of "starting fleet setup":

- Per-ship starting resources (ore/fuel/food/water/materials) and
  security-team counts, machine-readable as a `STARTING_RESOURCES` dict.
- Starting survivor population per ship (the evacuation ceiling — crew/
  passenger capacity numbers on the sheets are flavor only, not enforced).
- Starting unrest: every ship begins at 0; 8+ calls the facilitator
  (mutiny) — not modeled anywhere in `core/` yet.
- Explicitly flags what's still *not* in the source: shuttle starting
  cargo/caps, ship hold caps, starting console state, starting fighter
  counts. Same "treat as uncapped / assume empty, confirm before
  playtest" posture as the open questions above.

## Blocked — still need answers

- [x] **Star systems**: built - see "Star systems" under Backlog, below,
      for the full writeup.
- [x] **Wolf Attack data**: built - see "Wolf Attack system" under
      Backlog, below, for the full writeup.
- [x] **Suspicion / secret objectives**: built - see "Player phone pages"
      under Backlog, below, for the full writeup. Loyalty itself is still
      explicitly paper-only, no UI - that one's settled and stays that
      way.
- [x] **Turn phase structure**: built - see "Maintenance Cycle" under
      Backlog, below, for the full writeup.
- [x] **Unrest**: the field existed already (`Ship.unrest`, added
      earlier this project); what was missing was anything that raised
      or lowered it. `MaintenanceCycle.roll_unrest_gain()` now does the
      raising - see "Maintenance Cycle" below. No documented mechanism
      lowers it anywhere in the source material found so far, other
      than the mutiny threshold (8+) itself being a facilitator call,
      not an automatic reset.

None of these block the craft/shuttle system below — they block star
systems, Wolf Attacks, secret-info phone pages, and a stepped Team Phase
respectively.

**Update**: three more source documents landed in the repo since the above
was written (`open_questions_answered.md`, `ships.md`) and resolve nearly
all of it in full detail — star system topology + away mission data, full
console rosters, Wolf Attack ship roster/scaling/battle tables, the
complete suspicion/secret-info system, and the Team Phase step sequence.
These are now "answered, ready to build" rather than "blocked" - each
still has a couple of source-level open items called out inline (e.g. the
unlabelled −5 pursuit band, the FG-vs-printed-card suspicion values for
Universal Arbourage/Android). See those two files directly rather than
this summary when starting each system - they're thorough.

New from `ships.md`: a third vessel class, **Small Ships** (`gorgoneion`,
`capybara`, `warrior`, `vulcan`, `voyage_33_0`) - 5 optional/crisis
vessels, own population/unrest, own console set, but *cannot take
damage* and must dock with one of the 6 core ships every Team Phase and
Wolf Attack. Not part of the base starting fleet (`resources.md` and the
"only craft" decision above both confirm the base fleet is exactly the 6
core ships). Tracked as its own future system, not folded into
`FleetSetup` or the craft/shuttle system.

## Done — starting fleet setup

- [x] `core/fleet_setup.gd` — builds a fresh `GameState`'s 6 ships from
      `resources.md`'s starting resources/security teams/population, and
      the console roster from `open_questions_answered.md` §2.2 /
      cross-validated against `ships.md`. Unrest starts at 0. Consoles
      start undamaged and uncharged.
- [x] Wired into `ui/main.gd` — a fresh run now starts with the real
      fleet instead of an empty `GameState`. Verified end-to-end: booted
      the real app headlessly and confirmed via HTTP that it serves.
- [x] `Ship.unrest` field added (just the counter — no rules for what
      raises/lowers it yet, that's still open, see Blocked above).
- [x] `Console.charged` field added (was missing entirely — needed to
      represent "uncharged" at setup).
- [x] `ResourceStock.Kind.SECURITY_TEAMS` added (was missing — security
      teams are a transferable resource per the shuttle brief).
- [x] Fixed a real ship/craft naming collision found along the way:
      `ShipRegistry` used to list 9 "ships" (including Endeavour,
      Maliades, Pallas), but those three are craft names, not ships —
      confirmed with you. `ShipRegistry`, `CLAUDE.md`'s Ships table, and
      `web/app.js`'s mirrored ship list are all fixed to the real 6.

This was a prerequisite for the craft system below (shuttles need real
ships to dock at) and is now satisfied.

## Done — core/craft system

- [x] `core/craft/craft_definitions.gd` — the full roster (14 shuttles + 3
      fighter wings) as data via `CraftDefinition.from_dict()`, not
      per-craft classes. `ally`/`wobbly`/`endeavour`/`maliades` home ships
      match the resolved open questions.
- [x] `core/craft/craft_state.gd` + `craft_setup.gd` — per-craft mutable
      state (docked ship, fuelled, cargo `ResourceStock`, combat damage,
      fighter count, scout report, generic per-turn use counter), seeded
      for all 17 craft, docked at home ship, empty/unfuelled (per
      `resources.md`'s recommendation), fighter wings full at 4
      (unconfirmed default — flagged there too).
- [x] `core/craft/ability.gd` + `ability_check.gd` + `ability_result.gd` +
      `ability_registry.gd` + `core/craft/abilities/*.gd` — all 12
      abilities (`cargo_transfer`, `boarding_support[_elite]`, `redeploy`,
      `repair`, `recharge`, `scout_system`, `console_upgrade`,
      `mining_operations`, `resource_harvesting`, `away_mission`,
      `combat_table`), each with `can_execute()`/`execute()`. All
      randomness rolls against `GameState.rng` (seeded, exposed in
      `to_dict()`), never global `randi()`.
- [x] `GameState._on_phase_changed()` clears console charge and craft
      fuel/per-turn uses on every new Team Phase.
- [x] `core/craft/storage_damage.gd` — Storage-console-damage halving,
      including docked shuttles' cargo, with the exact rounding rule
      (5 → 3) tested.
- [x] `combat_table` ability — Maliades/Highwall/fighter-wing profiles as
      dice-roll arithmetic only, never an automated resolver. Fighter
      wings check their home ship's Fighter Bay console is charged and
      undamaged before they can join combat, but not for away missions.
- [x] 9 test files, 21 test files total in the suite, all passing —
      covers every case the brief's §6 asked for by name (fuel clearing,
      `requires_fuel` rejection reasons, repair cost/caps, consent-gated
      console damage, storage halving at value 5, cargo-type rejection,
      fighter launch preconditions, Maliades destroyed at exactly 3
      damage, table-driven ability-id resolution) plus per-ability
      coverage beyond that list.
- [x] Wired into `ui/main.gd`; verified end-to-end with the real app
      booted headlessly over HTTP.

**Deliberately deferred, not silently skipped:**
- `console_upgrade`'s materials cost — no source document gives the
  actual per-box cost, only that the track has 5 boxes (4 on Dione's VIP
  Lounge). Increments `Console.upgrade_level`, charges nothing. Flagged
  loudly in the ability's own file comment.
- `recharge`'s "consoles with an immediate maintenance-cycle effect
  trigger now instead" — sets `Console.charged = true` only; no console
  effect is implemented yet for any console (that's the Maintenance
  Cycle system, still blocked below).
- Maliades' and fighter wings' medium-range "shift a Wolf ship's target
  number" option, and Maliades' Shuttle-Bay repair-on-fuel — both need a
  Wolf ship model that doesn't exist yet (see Blocked, above).
- `repair`'s "2 consoles on 1 ship, 2 ships when fuelled" — implemented
  as literally that (not required to be the *same* ship across calls);
  not cross-checked against a source example, since the brief didn't
  flag this one as ambiguous.

## Backlog — plumbing gaps in what's already scaffolded

- [x] **Broadcast wiring**: `ui/main.gd` now pushes a `{"type": "state",
      "state": GameState.to_dict()}` message to every connected client on
      every `GameState.mutated`, and to a client individually the moment
      it connects (`NetServer.client_connected`). Simplest-correct
      choice: full-state dump every time, matching `Persistence`'s
      already-established "dump everything, every mutation" pattern
      rather than diffing. Revisit only if ESP32 payload size becomes a
      real problem (CLAUDE.md's Networking section).

      Getting here surfaced three pre-existing bugs, all fixed:
      - `GameState.mutated` only ever fired on `add_ship`/`add_craft`/
        `add_star_system` — not on anything that happens *after* setup
        (jump coordinates, drive charge, resources, console state,
        pursuit track, turn/phase advance). `Persistence`'s autosave was
        silently stale this whole time. Fixed by giving `Ship` and
        `CraftState` a `changed` signal that bubbles up everything nested
        under them (including `ResourceStock`/`Console`), and having
        `GameState` connect to it in `add_ship`/`add_craft`, plus
        `pursuit_track.changed` and `turn_manager.phase_changed`
        directly. Covered by `tests/core/game_state_mutated_test.gd`.
      - `NetServer` set `WebSocketPeer.write_mode` on every accepted
        connection - a property that no longer exists on this project's
        Godot version (`send_text()` replaced it). Every websocket accept
        threw and aborted before `accept_stream()` ran, so **no ESP32 or
        browser client has ever been able to open a socket** through this
        server. Confirmed via `ClassDB` introspection, not guessed.
      - Fixing that exposed a second bug: sniffing one TCP port for
        `Upgrade: websocket` requires reading the connection's opening
        bytes, which consumes them - `WebSocketPeer.accept_stream()` then
        has nothing left to read the handshake from and hangs in
        `STATE_CONNECTING` forever. `StreamPeerTCP` has no
        peek-without-consuming and `accept_stream()` has no way to accept
        pre-read bytes, so one port can't do both jobs. Resolved (user's
        call, see chat) by splitting into two `TCPServer`s - one for
        static files, one dedicated to WebSocket upgrades, so
        `accept_stream()` always gets a fresh, untouched connection. New
        port: `ui/main.gd`'s `WS_LISTEN_PORT` (8081, alongside
        `HTTP_LISTEN_PORT` 8080); `web/app.js` and any ESP32 firmware
        need both. CLAUDE.md's Networking section and `net/server.gd`'s
        file comment cover the why in full; `tests/net/server_test.gd`
        now exercises real loopback sockets end-to-end (handshake,
        message routing, `client_connected`, `broadcast()`) instead of
        only the pure helper methods, since that's exactly the layer
        where this hid.

      Not yet done: the web terminal client only *sends* — it doesn't
      render anything from the `"state"` pushes it now receives. That's
      real UI work, out of scope here; flagged under "Player phone
      pages" below since the ship terminal needs the same treatment.
- [x] **Crash-recovery rehydration**: `GameState.from_dict()` +
      `Ship.from_dict()` + `CraftState.from_dict()` (counterparts to
      `to_dict()`), plus `load_from_dict()` on `ResourceStock`,
      `Console`, and `PursuitTrack`. `ui/main.gd`'s `_init()` now calls
      `Persistence.load_dict()` first and rehydrates from it when
      non-empty, falling back to `FleetSetup`/`CraftSetup` only for a
      genuinely fresh run.

      Two things worth knowing if you touch this again:
      - `Ship.from_dict()`/`CraftState.from_dict()` load values *onto*
        the `ResourceStock`/`Console` objects `_init()`/`add_console()`
        already created and wired for `changed`-bubbling (see the
        Broadcast wiring entry above), rather than building fresh
        replacement objects — a fresh `ResourceStock.new()` here would
        be unwired from `Ship.changed`, and mutating a rehydrated ship
        post-load would silently stop reaching `GameState.mutated` (would
        break both autosave and broadcast for the rest of that game).
        That's why `ResourceStock`/`Console` got `load_from_dict()`
        instance methods instead of static `from_dict()` constructors.
      - `GameState.from_dict()` restores `turn_manager` *before* adding
        any ship/craft, deliberately — `TurnManager.force_set()` emits
        `phase_changed` the same as `advance()` does, which
        `GameState._on_phase_changed()` reacts to by clearing console
        charge and craft fuel/uses on every new Team Phase. Restoring
        turn/phase while `ships`/`craft` are still empty makes that a
        no-op instead of wiping the very state being loaded. Caught by
        `test_loading_a_team_phase_save_does_not_wipe_the_state_it_just_loaded`
        in `tests/core/game_state_persistence_test.gd` before it ever
        became a real bug.

      Verified two ways: the full round-trip test file above (data
      round-trips, and rehydrated objects still bubble to `mutated`),
      and manually against the real running app — mutated a ship over
      its actual websocket, confirmed the autosave, killed the process,
      restarted it, and confirmed the mutation came back over a fresh
      connection.
- [x] **Host console completeness**: `ui/host/host_console.gd` now builds
      a collapsible, editable panel per ship and per craft (17 of them),
      covering every field `to_dict()` persists — jump coordinates,
      drive charge, unrest, survivor population, all resource kinds, and
      every console's state/charged/upgrade level for ships; docked
      ship, fuelled, combat damage, fighter count, scout report, and
      cargo for craft. All of it writes through the same setters
      MessageRouter and the ability system already use (`Ship.
      set_jump_coordinates()`, `Console.set_state()`, etc.), so there's
      no separate "host" code path to keep in sync - just a UI that can
      reach every setter core/ exposes. Closes the constraint 5 gap
      called out here: every mutable field now has a bypass.

      One thing worth knowing if you touch this again: panels are built
      *once* in `set_game_state()`, not rebuilt on `GameState.mutated`.
      With ~180 editable fields across 6 ships and 17 craft, and
      `mutated` now firing on every real mutation (see Broadcast wiring
      above), rebuilding the whole tree every time would blow away
      whatever the host is mid-typing anywhere the instant *any* player
      action arrives over the network - a background event tearing out
      an in-progress edit is exactly the kind of thing that makes a host
      stop trusting the tool mid-game. Instead, each panel refreshes its
      displayed values from live state only when expanded (a deliberate
      host action), plus a manual "Refresh all" button for when the host
      wants current values without touching every panel.

      Verified by instantiating the real scene headlessly and driving it
      programmatically: expanded a ship panel, edited jump coordinates
      and clicked Set, toggled drive charge, changed a console's state
      via its dropdown, confirmed each wrote through to the live `Ship`/
      `Console` object; mutated state externally and confirmed
      re-expanding picked up the change; expanded a craft panel and
      confirmed toggling fuelled wrote through to `CraftState`. No
      formal test file - this project's suite doesn't instantiate `.tscn`
      Control scenes anywhere yet, and adding that pattern felt like a
      separate decision from this task.
- [x] **TV display completeness (3 of 3)**: added a fleet
      status overview (one row per ship: drive charge, jump coordinates,
      unrest, all six resource kinds - `DisplayFormat.ship_status_line()`)
      and a jump/scout announcement feed. Both rebuild freely on every
      `GameState.mutated`, unlike HostConsole's refresh-on-expand - TV
      display has no editable input a rebuild could interrupt, since it
      never mutates state (see its own file comment).

      New: `core/announcement_log.gd` (`AnnouncementLog`) - a capped,
      newest-first log GameState wires directly to `Ship.
      jump_coordinates_set` and `CraftState.scout_report_set` in
      `add_ship()`/`add_craft()`, so anything that calls those setters
      (a player's phone, the host console's override, a future ESP32
      message handler) gets logged automatically with no separate
      "announce this" call site to remember. Persisted in
      `GameState.to_dict()`/`from_dict()` like everything else, so the
      feed survives a crash-recovery restart. Deliberately dumb: logs
      exactly what was typed, never validated against real star system
      data - same trust model as constraint 1, extended to the display
      layer instead of just the input layer.

      **Wolf Attack support screen: built** - see "Wolf Attack system"
      below. It needed the combat rules engine this note originally
      said didn't exist yet; that engine is now built.

      Bug found and fixed along the way: the rebuild pattern (clear old
      rows, add new ones, same function call) used `queue_free()`, which
      defers removal to end-of-frame - the old and new rows briefly
      coexisted as siblings until cleanup ran. Never visible in the
      compiled game (rendering happens after deferred frees resolve),
      but it broke a same-frame verification script that inspected the
      tree right after triggering a mutation, which is how it was
      caught. Switched to `free()` (immediate) in both `TVDisplay`
      rebuild methods.

      Verified by instantiating the real scene headlessly: 6 ships
      render one row each; mutating a ship's drive charge and jump
      coordinates updates its row without a manual refresh; setting
      jump coordinates and a scout report each produce an announcement,
      newest first, with the right ship/craft display name. New
      `DisplayFormat` functions (`resource_summary`, `ship_status_line`,
      `announcement_line`) are pure and covered in
      `tests/ui/display_format_test.gd`; `AnnouncementLog` itself and
      its `GameState` wiring are covered in
      `tests/core/announcement_log_test.gd`.
- [ ] **Deployment**: no export preset configured; no plan yet for how the
      12 ESP32 terminals discover the host's IP on the GL.iNet router
      (static IP? mDNS?). ESP32 firmware itself is out-of-repo work in a
      different codebase.

      **Two real desktop-windowing bugs found and fixed this session**,
      while running the app visibly (non-headless) for the first time
      this whole project - every previous verification this whole
      engagement was `--headless`, so neither of these had ever been
      exercised:
      - Godot's `embed_subwindows` project setting defaults to `true`,
        which made the TV Display `Window` node render as an overlay
        *inside* the primary window instead of becoming a real second
        OS window - it was drawing on top of and completely hiding the
        Host Console the entire time. Fixed with
        `window/subwindows/embed_subwindows=false` in `project.godot`.
        Confirmed via `DisplayServer.get_window_list()`: 1 window
        before the fix, 2 after (verified as a throwaway diagnostic,
        not left in the code).
      - The TV window's default size (1920x1080, matching the design
        resolution from `wolf_attack_tv_display.md`) combined with
        Godot's default position of `(0, 0)` pushed the OS-drawn title
        bar/border off-screen on any display at or near that same
        resolution - the window *had* a border the whole time
        (`DisplayServer` confirmed `borderless=false`), it just wasn't
        on-screen to grab. Fixed by defaulting the window smaller
        (1280x720) with a small position inset (80, 80) in
        `ui/main.gd`, so decorations always have room. Still freely
        resizable up to the full design resolution and beyond by hand.
      - Still not built: an actual fullscreen/multi-monitor mode for
        real venue use (`wolf_attack_tv_display.md` §7's
        `tv_window.gd` sketch - `current_screen`, borderless
        fullscreen, content scaling). The above two fixes make the
        *windowed* dev/testing experience correct; a host running this
        for real on a laptop + projector still needs that separate
        piece built. Natural to do alongside whatever the TV visual
        redesign below needs anyway.
- [x] **Player phone pages** (`web/`): built the suspicion/clue system
      from `open_questions_answered.md` §4 - the only part of "secret
      objectives" that isn't paper-only (loyalty itself stays off the
      system entirely, CLAUDE.md constraint 4; §4.5 confirms phone pages
      carry only suspicion and facilitator-issued clues).

      - `core/player.gd` (`Player`) - id, name, suspicion (clamped at 0,
        no stated upper bound), and a clue list. `changed`-bubbles into
        `GameState.mutated` the same way Ship/CraftState do.
        `Player.posse_size_required(suspicion, standers)` is FG's arrest
        formula (§4.3) as pure arithmetic - "6 including the accuser,
        minus 1 per 5 suspicion, plus 1 per stander," clamped to a
        minimum of 1.
      - **Not built**: the Intelligence Agent's 80%-accuracy
        investigation (§4.4). Loyalty stays off the system entirely, so
        the software has no ground truth to weight a roll against - only
        a human with the paper cards can actually answer "is this
        player a Wolf Agent," which is exactly constraint 4's point.
        Also not built, per §4.6's own recommendation: any scoring model
        for the open-ended team objectives.
      - `ui/host/host_console.gd` - a new Players section: add a player
        by name (host generates the id, types in whatever starting
        suspicion the dealt loyalty card says), override suspicion
        directly, a "roll 1d6" convenience button for the clue table
        (§4.2 - pure dice arithmetic; the host still decides whether/who
        to tell anything, same as away missions never auto-resolving),
        the arrest posse-size calculator (host-only - FG: "tell the
        players the number required, never the suspicion value"), a
        clue history, and a send-clue field. Also shows each player's
        phone-page URL (`DisplayFormat.player_phone_url()`) built from a
        best-effort local IP guess, for the host to turn into a QR code
        externally - actual QR generation is out of scope (no
        CDN/library, and the IP itself is provisional pending the
        Deployment item's IP-discovery decision above).
      - `web/player.html` + `web/player.js` - a player's own phone page.
        Identifies itself to the server right after connecting
        (`{"type": "identify_player", "player_id": ...}`, read from the
        URL's `?id=`), then renders exactly its own suspicion number and
        clue feed. Deliberately neutral copy ("this number by itself
        doesn't mean anything") - §4.1 is explicit that loyalists start
        at 5 and 10 on purpose, and any UI must not imply a nonzero
        score is evidence.

      **Privacy boundary, not an afterthought**: suspicion and clues are
      the first genuinely secret per-connection data this app has ever
      sent over the network - unlike ships/craft (public knowledge in
      the fiction), leaking one player's suspicion or clue text to every
      socket would be a real problem, not just noise. `GameState.
      to_dict()` (host-local save) still includes every player, but
      `to_public_dict()` (what gets broadcast to all clients) strips
      `"players"` entirely, and `player_to_dict(id)` is sent only to
      that player's own peer_id via a new `player_state` message -
      `ui/main.gd` tracks a `player_id -> peer_id` map, populated on
      `identify_player` and cleared on disconnect. `net/message_router.gd`
      is untouched; `identify_player` is transport bookkeeping (which
      socket is which player), not a state mutation, so `ui/main.gd`
      intercepts it before routing rather than teaching MessageRouter
      about connection identity.

      Verified end-to-end against the real running app (not just unit
      tests): booted the actual `Main` scene, added two players
      directly to its live `GameState`, connected three real websocket
      clients (one that never identifies - like the ship terminal always
      has - plus one per player), and confirmed: the unidentified
      client's broadcasts never contain a `"players"` key; each
      identified player only ever receives their own `player_state`,
      never the other's (including a clue seeded specifically to try to
      leak across); and mutating one player's suspicion only pushes an
      update to that player's own connection. Also drove the host
      console's Players section programmatically end-to-end (add player,
      override suspicion, roll 1d6, run the posse calculator, send and
      see a clue, read back the generated phone URL) and confirmed
      static file serving for the two new web/ files.

- [x] **Wolf Attack system**: built from a dedicated brief
      (`wolf_attack_tv_display.md`, added to the repo for this) plus
      `open_questions_answered.md` §3. This is the biggest single
      feature in the project so far - a combat rules engine, a full
      host console control section, and a second TV screen the host
      swaps to for the length of an attack.

      **Scope, agreed up front**: the brief specifies pixel-exact
      typography, staged reveal animations (700ms per Wolf ship,
      overlapped), a custom flow container, and exact venue colours -
      none of which can be verified without a real TV, so all of that
      was cut in favour of correct state/data/layout using plain Godot
      Controls (`HFlowContainer` for the wolf token grid) and basic
      `Tween`-free color overrides. Every piece of *arithmetic* in the
      brief is implemented exactly; the *visual polish* is not. Also
      cut, per the brief's own explicit instruction (§5.5/§9): survivor
      loss per damage point - flagged there as unconfirmed and "do not
      ship until confirmed," so only damage pips are shown, no
      population-loss number anywhere.

      **core/combat/** (new):
      - `wolf_ship_definitions.gd` - static per-class data (capacity,
        targeting table, and the damage-if-destroyed-at-phase /
        damage-if-survives tables from open_questions_answered.md
        §3.1). The brief's own PREVENTS table (§5.3) was derived
        independently from the same source numbers and cross-checked
        against this file in tests - both agreeing is what makes the
        numbers trustworthy rather than transcribed once and hoped.
      - `wolf_ship_state.gd` - one Wolf ship's live state (damage,
        target die, which phase it was destroyed in if any).
        `changed`-bubbles like Ship/CraftState/Player.
      - `wolf_attack.gd` (`WolfAttack`) - the attack instance: 7-phase
        state machine (incoming → targeting → long → medium → short →
        boarding → resolution), host-driven only, forward *and*
        backward (`advance_phase()`/`retreat_phase()` - "the host can
        move backwards" is explicit in the brief). Targeting dice ARE
        rolled by this class via the caller's rng, not left for the
        host to type in - unlike scout/jump coordinates, a targeting
        roll has no deception to protect (fleet-vs-NPC, not
        player-vs-player), so it's automated the same way
        `combat_table`'s fighter/Maliades/Highwall rolls already are.
        `compute_damage_tally()` is the one non-obvious piece: a Wolf
        ship's damage depends on *when* it dies (a dying blow locked in
        at destruction, from `damage_if_destroyed_at`) versus surviving
        to the end (`damage_if_survives`) - the same function serves
        both the live "incoming damage" readout mid-attack and the
        final resolution tally, since nothing about the derivation
        changes, only whether more damage might still land.
      - `wolf_attack_view.gd` (`WolfAttackView`) - pure view-builder
        matching the brief's §6 data contract exactly. This is the
        security boundary: **while phase is INCOMING, every Wolf
        ship's "target" key is omitted from the dict entirely, not
        sent as null** - the brief is explicit that a leak here is a
        leaked traitor mechanic, and that the view handed to a screen
        pre-reveal must not *contain* the targets, not merely avoid
        drawing them. Targets are pre-rolled the moment a ship is added
        (so the reveal is instant once TARGETING starts, matching "the
        host pre-rolls before announcing the attack"), so this really
        is a redaction, not a delay.

      **A real leak caught before it shipped, not a hypothetical**:
      `GameState.to_public_dict()` (what gets broadcast to every
      connected client) was building `wolf_attack` from the raw
      `WolfAttack.to_dict()`, which always has every ship's true
      `target_die` - the persistence path needs that (a crash-recovery
      restart must not re-roll targets the host already announced and
      laid cards out for), but the *network* path doesn't get to see it
      before the reveal. Fixed by having `to_public_dict()` substitute
      `WolfAttackView.build(self)` for the raw object, so the broadcast
      literally cannot see what the TV doesn't draw - reusing the one
      function that already knows how to redact, rather than trusting
      every future renderer (web terminal, some future ESP32 handler)
      to remember not to. Covered directly:
      `test_to_public_dict_never_leaks_targets_during_incoming` and
      `test_to_dict_persistence_keeps_the_raw_target_die` in
      `tests/core/combat/wolf_attack_view_test.gd`.

      **ui/host/host_console.gd** - a new Wolf Attack section: start/end
      attack, add Wolf ships by class, generic damage taps (+1/-1,
      auto-destroys at capacity, undo un-destroys), retargeting
      (re-roll for the Wolf Commander, ±1 shift for fighters/Maliades,
      force-to-AEGIS for the AEGIS's C&C), a boarding sub-section
      (decrement boarders/security teams, Wolf Commander "+2" one-shot),
      and a resolution summary. Deliberately *not* built: console-weapon
      abilities (Missile Launchers, Point Defence Lasers, Gorgoneion's
      Missile Array, Vulcan's Laser Cannon) - the brief's own host-input
      model (§8) never lists "roll ship weapon X", only a generic
      damage tap, so the host resolves those dice physically/mentally
      (same as they already would for anything off-script) and taps the
      result on. Fighter Wings/Maliades/Highwall already had working
      dice rolls via the existing `combat_table` ability from an earlier
      session; wiring that into this UI as a convenience button was
      explicitly deferred rather than built into this pass.

      Unlike every other host console section, this one rebuilds its
      entire subtree on every `GameState.mutated` rather than
      refresh-on-expand - almost everything in it is taps and
      spinbox+Set rows used live during a fast-paced attack, not free
      text a rebuild could interrupt mid-typing.

      **A real crash caught before it shipped**: connecting the rebuild
      directly to `mutated` crashed immediately - "Object is locked and
      can't be freed" - because the rebuild frees the whole section,
      including whichever button's own `pressed` handler is what
      triggered the mutation in the first place; Godot won't free a
      node while it's still inside its own signal emission. Fixed with
      `CONNECT_DEFERRED`, which runs the rebuild after that call stack
      unwinds. Would have hit on the *first* button press in real play;
      caught by a headless script that actually clicked through the
      section rather than just calling core/ methods directly.

      **ui/tv/wolf_attack_display.gd + .tscn** (new) - the second TV
      screen, matching the brief's 4 distinct layouts (INCOMING;
      STANDING, which covers targeting + all three range phases, since
      the brief itself says they share one layout; BOARDING; RESOLUTION).
      `ui/main.gd` now instantiates both `TVDisplay` and
      `WolfAttackDisplay` as children of the same TV `Window`, toggling
      `visible` on `GameState.mutated` based on whether `wolf_attack` is
      active - swapped by visibility rather than added/removed from the
      tree, so nothing has to be rebuilt from scratch when the host
      flips back to check pursuit mid-attack. Entirely read-only, same
      as `TVDisplay` - never mutates state, only renders
      `WolfAttackView.build()`.

      **Assumption, not a guess**: Small Ships (Gorgoneion, Capybara,
      Warrior, Vulcan, Voyage 33-0) are treated as never targetable by
      a Wolf ship. This was flagged as unconfirmed in the brief's own
      §9, but both source documents independently lean the same way -
      `ships.md`'s own Open Items section says the targeting table
      listing only the six core ships "suggests they are never
      targeted at all," and the brief's targeting table (§5.3) agrees.
      Two sources converging, not one guess. Moot regardless for this
      pass, since Small Ships aren't modeled as `Ship` objects in
      `core/` at all yet (separate future system per the note further
      up this file) - there's no object a Wolf ship even *could* target.
      Same reason `live_fleet_weapons` only covers the AEGIS's two
      weapon consoles and the craft with `combat_table` - Gorgoneion's
      Missile Array and Vulcan's Laser Cannon are Small Ship consoles
      with no object to check the charged/damaged state of yet.

      **Also not built**: the brief's §7 second-window setup
      (fullscreen, multi-monitor targeting, content scaling) - that's a
      general TV-window deployment concern predating this feature, not
      specific to Wolf Attacks, and overlaps the existing Deployment
      item above (screen resolution at the venue is listed there as
      unconfirmed too). The "LOST" placeholder for a destroyed/abandoned
      core ship (§9 open question 3) wasn't built either - whole-ship
      destruction isn't modeled anywhere in `core/` yet, only console
      damage, so there's no state for a ship to be "LOST" *from*; all
      six ships are always shown. Multiple simultaneous attacks (§9
      open question 4) follow the brief's own recommendation without
      extra code: ending and starting a new `WolfAttack` naturally
      creates "a new instance" the way the brief suggests, and
      `WolfAttack.round_number` exists for the TV to label them.

      5 new test files covering the roster/damage-table cross-check,
      per-ship state and its dict round-trip, the full attack state
      machine (targeting/retargeting/damage/boarding/resolution math),
      the view builder's security boundary, and `GameState` wiring
      (persistence round-trip of an in-progress attack, `mutated`
      bubbling). 31 test files total, all passing. Verified end-to-end
      against the real running app twice: once driving the host
      console's Wolf Attack section by tapping through every control
      (start → add ship → damage → target reveal → retarget → range
      phases → boarding → resolution → end), and once driving
      `game_state.wolf_attack` directly while inspecting the actual TV
      scene tree at every phase (composition/capacity on INCOMING,
      token/card counts on STANDING, a destroyed token's token updating,
      the boarding card appearing for the right ship, the resolution
      list, and the TVDisplay/WolfAttackDisplay visibility swap in both
      directions).

- [x] **Star systems**: built from `open_questions_answered.md` §1 -
      the map topology, all 16 systems' content, and the per-game
      mutable state each needs. Scoped as a data layer, matching what
      the backlog item literally asked for ("exist as empty containers
      with no data"); wiring this data into jump resolution, scout
      range checks, or an away-mission-running host UI is follow-up
      work, not done here (see below).

      **core/star_chart.gd** (`StarChart`, new) - the 22-node jump
      graph (`0000` plus 21 lettered systems), one fixed topology
      shared by three "organiser chart" variants (A/B/C) that only
      differ in which system letter sits on which node. The source doc
      itself flags this transcription as unverified against the
      printed original and explicitly asks for a symmetry test - added
      (`tests/core/star_chart_test.gd`), plus node/edge count checks,
      full connectivity, and confirmation that each chart omits exactly
      the letters the source says it should (chart A has no B; chart B
      has no A, C, or D; chart C has no A or B). All pass, which is
      good evidence the transcription is internally consistent - it is
      not proof it matches the printed chart, which nothing here can
      check without the physical artwork.

      **`core/star_system_definition.gd` + `star_system_definitions.gd`**
      (new, mirrors `CraftDefinition`/`CraftDefinitions`) - the static
      roster: all 13 card-based systems (A-M) with their opportunities
      (skill, difficulty, critical threshold, reward text), plus
      standing effects that belong on the system rather than any one
      opportunity (G doesn't reduce pursuit; I doesn't raise pursuit
      while present and deals maintenance-phase damage on a 3+; J deals
      maintenance-phase damage on a 4+ and repeats every turn; K's
      difficulty is secretly rolled and repeats every turn; L/M trigger
      a Wolf Attack on arrival and block their own away mission until
      the base there is destroyed).

      **core/away_mission.gd** extended: `critical_threshold` (-1 = no
      critical tier, matching "a single number means no critical
      tier"), multi-skill opportunities (system C's "20 mining and
      exploration" accepts either), reward/critical-reward text, and
      `is_success()`/`is_critical()` threshold-comparison helpers -
      still "automate the totalling and threshold comparison only" per
      the source doc's own instruction; card dealing, discarding, and
      assignment stay physical, unchanged from before.

      **core/star_system.gd** rewritten as the mutable per-game
      instance (mirrors `Ship`/`CraftState`): which opportunities have
      been completed, whether an L/M Wolf base has been destroyed yet,
      and K's rolled difficulty/critical threshold once
      `roll_hidden_difficulty()` has been called (idempotent - a second
      call is a no-op, since the source treats it as one fixed value
      per game, not re-rolled per attempt). `changed`-bubbles into
      `GameState.mutated` like everything else; `star_system_setup.gd`
      (mirrors `FleetSetup`/`CraftSetup`) populates all 16 into a fresh
      `GameState`, wired into `ui/main.gd`.

      **A privacy boundary carried over from the Wolf Attack work**:
      `GameState.to_public_dict()` (the network broadcast) excludes
      `star_systems` entirely. System K's difficulty is explicitly
      never supposed to reach a player - "your UI must be able to show
      an unknown difficulty without leaking the rolled value" - and
      unlike Wolf ship targeting there's no away-mission UI yet to
      justify building a `WolfAttackView`-style partial-redaction path
      for it. Full exclusion now, same treatment as `players`, revisited
      if/when an away-mission UI needs to show *something* about a
      system to a player.

      **One source ambiguity resolved with the user, not guessed**:
      system E's third reward reads "explore 2 wolf star systems (code
      W1 or W2)" in the source table, but no W1/W2 system exists
      anywhere in the charts or data - the source doc itself says "ask
      before modelling it." Resolved by replacing it with a reward
      pointing at real data instead: revealing the location of the two
      actual Wolf systems, L and M - same "find Wolf territory" flavor,
      but grounded in systems that exist. Covered by
      `test_system_e_reward_replaces_broken_w1_w2_reference`.

      **Deliberately not built, scope agreed with the user up front**:
      - Systems N (Ancient Jump Ring), O (Deep Nebula), and P (Ancient
        Space Station) - the "New Eden candidates" - have bespoke
        non-card completion conditions (multi-step repair progress; a
        scout-roll settlement mechanic with a hidden per-ship bonus
        that must never reach any player-facing surface; a
        reactor-cannibalization threshold). They exist in the topology
        and roster (`is_new_eden_candidate`, `new_eden_description`)
        but their bespoke mechanics aren't implemented - each is
        realistically its own small system.
      - Wiring `StarChart`/`StarSystemDefinitions` into
        `JumpResolver` or scout range checks. `JumpResolver`'s pursuit
        consequence is still a bool the *host* judges by looking at
        what a scout typed, not something the engine computes from real
        map data - auto-deriving it from `StarChart` would mean the
        engine validating a scout's coordinates against reality, which
        is exactly what CLAUDE.md constraint 1 forbids. Scout range
        checks ("within N jumps" - Starlight 2, Hummingbird 3) would be
        legitimate to wire up (a hard capability limit, not a
        deception check), but nothing in the engine tracks the fleet's
        actual current node yet either - a separate piece of work.
      - An away-mission-running host console section (pick a system and
        opportunity, enter the card total, see success/crit, apply the
        reward) and automatic reward *application* to `GameState`.
        Reward text is fully data-modeled now; nothing yet triggers
        applying it. Natural next step once someone wants to actually
        run an away mission through the tool rather than at the table
        with a pen.

      Also fixed in passing: CLAUDE.md's glossary was missing
      `exploration` as a skill (six skills exist, not five) - the
      source doc flagged this explicitly; now corrected.

      6 new test files covering the graph topology/symmetry, the full
      system roster (all 16 letters, every standing-effect flag, the
      E-reward replacement, the "no minerals" guard the source doc
      explicitly asks for), the mutable instance's behavior and dict
      round-trip, and `GameState` wiring (bubbling, persistence,
      `to_public_dict()` exclusion). 35 test files total, all passing.
      Verified against the real running app: booted `Main` fresh and
      confirmed all 16 systems populate; mutated three systems
      (completed an opportunity, destroyed a Wolf base, rolled K's
      hidden difficulty) and confirmed `to_public_dict()` still
      excludes `star_systems` entirely; then did a real process
      restart from the autosave and confirmed all three mutations,
      including the rolled difficulty, survived crash recovery intact.

- [x] **Maintenance Cycle**: built from `open_questions_answered.md`
      §5, cross-checked against `ships.md`'s per-ship Reactor/ration
      data. The Team Phase's internal step sequence - each ship's table
      runs 6 steps (7 for AEGIS) at its own pace, not fleet-wide in
      lockstep.

      **`core/maintenance_cycle.gd`** (new) - step definitions, and the
      arithmetic each one needs: Reactor charge caps and damaged
      penalties per ship (`ships.md`'s own "Reactor charges vs. console
      count" table plus each ship's Reactor console entry, not the
      rougher "-2 or -3" summary in `open_questions_answered.md`, which
      doesn't say which ships get which penalty - this doc does,
      unambiguously, per ship); ration cost tables per ship
      (§2.3); `apply_storage_step()` (reuses the already-built
      `StorageDamage`); `spend_rations()`; `roll_unrest_gain()` (2d6 +
      ration bonus, thresholds at 12 and 20); `roll_riot_damage()` (1d6
      vs current unrest); Reactor cap/charged-count reference numbers;
      `refuel_shuttle()` (spends 1 strytium fuel, fuels one docked
      craft, through whichever Shuttle Bay console - AEGIS has two,
      Zeta and Omega, everyone else has one).

      **Scope boundary carried over directly from a decision already
      made this session for Wolf Attack resolution**: *which specific
      console* takes riot damage is not modeled. `open_questions_
      answered.md` §2.1 is explicit that damage is dealt by drawing
      from a finite **per-ship** deck of that ship's own printed
      console cards ("this is load-bearing - model the deck, not a
      random console picker") - a real system of its own, not yet built
      anywhere in `core/`. `roll_riot_damage()` reports *whether* a hit
      landed (dice arithmetic, automated, no deception potential); the
      host draws the physical card and marks the resulting console
      damaged through the per-console override HostConsole already has
      - exactly the same split already applied to Wolf Attack damage
      resolution (the number is computed, which console takes it stays
      physical).

      Similarly, **which consoles get charged (step 5)** and **which
      shuttle gets refuelled (steps 6/7 - which craft, not that it
      happens)** stay host/player choices made through controls that
      already existed (the per-console "charged" toggle, craft
      docking) - this only adds the cap/count reference numbers and,
      for refueling specifically, the fuel-spending action itself
      (spending resources is exactly the kind of arithmetic this
      project already automates everywhere else).

      **`core/turn_manager.gd`**: added a new `advanced` signal, kept
      deliberately separate from the existing `phase_changed`. This
      exists for one reason: `force_set()` (used both by `GameState.
      from_dict()` on crash-recovery restore, and by HostConsole's
      "Force Set" override button) emits `phase_changed` exactly like a
      real `advance()` does, and there's no way to tell them apart from
      inside a `phase_changed` handler. That distinction turned out to
      matter immediately - see below.

      **A real bug caught by reasoning about the persistence path, not
      just by testing the happy path**: `open_questions_answered.md`
      §5.4 says pursuit rises by 2 every turn, which is easy arithmetic
      to automate - and the first draft did, by hooking it to
      `phase_changed`. That would have meant every reload of a save
      sitting in a Team Phase silently added +2 pursuit it shouldn't
      have, compounding a little more on every crash-recovery restart -
      exactly the failure mode this project's Persistence design exists
      to protect against, undone by the very feature meant to help.
      Caught before it was ever wired up wrong, by asking "what else
      calls the thing this connects to" before connecting it - the
      `advanced` signal exists specifically so pursuit-per-turn (and
      anything like it later) can listen to "a turn actually happened"
      without also catching "a save got reloaded" or "the host corrected
      a mistake". `test_reloading_into_a_team_phase_does_not_double_
      apply_pursuit_per_turn` and `test_force_set_into_team_phase_does_
      not_raise_pursuit` guard this directly.

      **`core/ship.gd`**: added `completed_maintenance_steps` - a
      per-turn checklist (which of this ship's 6/7 steps have run this
      Team Phase), cleared by the same end-of-Team-Phase sweep that
      already clears console charge and craft fuel.

      **`ui/host/host_console.gd`**: each ship's existing panel gained
      a Maintenance Cycle section - a running checklist, a Storage-step
      button, ration-level pickers with a spend button, unrest/riot
      roll buttons showing the roll and result, Reactor cap/count
      readout, and a refuel action per Shuttle Bay console (two for
      AEGIS). Uses the same refresh-on-expand pattern as the rest of
      the ship panel, not Wolf Attack's rebuild-on-every-mutation one -
      these are occasional, once-per-turn actions with no rapid-fire
      tapping to protect against, so there's no in-progress-typing risk
      the way Wolf Attack's frequent damage taps have.

      **Deliberately not built**: real-time clock/timer tracking (5
      min Team Phase, 15 min Coordination, extended on turn 1) - the
      backlog item was specifically about the missing step sequence,
      not about wall-clock facilitation, and nothing here needs it.
      Small Ships' 4-step cycle (no Storage step; the riot step costs
      population instead of console damage) is captured as reference
      data (`MaintenanceCycle.SmallShipStep`) but not wired to
      anything, since Small Ships aren't modeled as objects in `core/`
      yet - consistent with every other Small-Ship-shaped gap noted
      elsewhere in this file.

      2 new test files (`maintenance_cycle_test.gd`,
      `ship_maintenance_steps_test.gd`) plus new tests added to the
      existing turn/persistence suites, covering the arithmetic
      (storage/rations/unrest/riot/reactor-cap/refuel), the `Ship`
      checklist and its dict round-trip, and the `TurnManager.advanced`/
      `phase_changed` split with the exact regression scenario described
      above. 37 test files total, all passing. Verified against the
      real running app:
      expanded AEGIS's panel and tapped through all 7 steps in order,
      confirming each one's actual effect (resources halved, rations
      spent at the right per-ship cost, unrest changed, a docked
      shuttle actually got fuelled and exactly 1 fuel was spent) and
      that the checklist display updated correctly at every step.

## Done — Wolf Attack TV display v1 redesign

First pass at matching `Wolf_Ships-selection.png`, built per the plan in the
previous version of this section. Landed: `ui/tv/ship_icon.gd` (hand-drawn
vector icons for the 6 Wolf classes + 6 fleet ships), `ui/tv/wolf_display_palette.gd`
(ship-identity colors matched to the reference image), `ui/tv/targeting_lines.gd`
(dashed curved lines from wolf tokens to their target's fleet card), a rewritten
`wolf_attack_display.tscn`/`.gd` STANDING layout with a pursuit bar, phase
breadcrumb, redesigned wolf tokens (icon + class-specific effect label) and
fleet cards (colored index numbers, SEC/DMG readout, class-code + "N BP" tag
chips), and a "CANNOT BE TARGETED" strip. Structurally verified against a
live driving script (pursuit bar fill, breadcrumb highlight, icon/effect-label
content, fleet card index/tags, targeting-line link count all asserted); one
real bug found and fixed this way - the "N BP" boarding-party tag read
`fleet_ship["boarders_inbound"]`, which `WolfAttackView` only populates once
the attack reaches `Phase.BOARDING`, but the fleet card is only ever shown
during targeting/range phases, so the tag was always empty. Fixed by deriving
a *projected* boarder count from each targeting wolf ship's own `boarders`
field instead (same data the wolf token's "PREVENTS N BP" label already uses).
Full test suite still green (37 files), no `core/` changes needed.

User feedback after looking at it running: "a little bit better, but there is
still a lot of work to do" - not close enough to the reference yet. Explicitly
**not pixel-matched** going in (see the file-header comment on both new
scripts) since this environment can't screenshot a live Godot window - visual
QA has to come from the user actually looking at it, which is what happened
here and is why there's a v2 pass below.

## Done (superseded in part by v3 below) — Wolf Attack TV display v2: close the gap spec

The user did a proper side-by-side pass against `Wolf_Ships-selection.png`
and wrote it up as `wolf_attack_tv_display_v2_gap_spec.md` (repo root) -
**read that file directly before starting**, it has exact pixel coordinates,
hex colors, font sizes and a full priority-ordered checklist; this entry is
just a pointer into it, not a substitute. It explicitly *supersedes v1's
visual sections only* - `wolf_attack_tv_display.md`'s state machine, data
contract and host input model still stand.

**Headline diagnosis**: v1 got the information architecture right but reads
as "an unstyled Godot window," not a battle map - no design tokens (colors/
fonts/spacing are ad hoc per-node), flat grey background, wolf ships sit in
bordered panels instead of floating free across the full width, no range-band
gutter/arc, attack vectors are disconnected stubs, fleet cards are
inconsistently styled, and there's leftover debug text (`LIVE: maliades`,
`WOLF FORCE - N / N CAPACITY`) that shouldn't be on a screen 20 players are
standing around.

**Work top to bottom, per the spec's own §0 instruction** - §2 (design
tokens: `wolf_attack_tokens.gd` + a bundled font pair with letter-spacing)
must land before anything in §4, since every later fix references a token by
name.

- [x] **P0 - structural** - all 8 landed. `res://ui/tv/wolf_attack_tokens.gd`
      holds every color/font-scale/vertical-rhythm constant (§2); the STANDING
      layout is a fixed 1920×1080 canvas via `tv_window.content_scale_*` in
      `ui/main.gd` (`P0-01`); Chakra Petch (DISPLAY) + JetBrains Mono (DATA,
      variable font, weight selected via the `wght` axis) are bundled under
      `res://assets/fonts/` and applied with `FontVariation.spacing_glyph`
      tracking per token, no CDN/runtime download (`P0-02`); `wolf_backdrop.gd`
      draws the near-black gradient + crimson top-corner bloom, built at
      runtime from `GradientTexture2D` resources rather than baked PNGs -
      this project has no image editor in its toolchain, and Godot's own
      procedural gradients give the same "cheap, computed-once, no shader"
      result the spec was after without needing external raster assets
      (`P0-03`); the wolf force row is a bare `HBoxContainer` (no
      `PanelContainer`/border) spanning the full safe-margin width, each
      item `SIZE_EXPAND_FILL` (`P0-04`); `range_bands.gd` draws the
      LONG/MEDIUM/SHORT gutter labels and the active-band arc, hidden
      outside range phases (`P0-05`); `targeting_lines.gd` now draws a
      proper cubic-bezier dashed curve per spec §4.7's control-point math,
      fixed vector origin/terminus y-values instead of node-edge-derived
      ones (`P0-06`); every STANDING element sits at its §2.4 y-coordinate
      via the `.tscn`'s explicit offsets (`P0-07`); the `LIVE: <weapon>` and
      `WOLF FORCE - N / N CAPACITY` debug lines are gone from the TV output
      entirely, not moved anywhere else yet - see below (`P0-08`).

      Touching the wolf-item and fleet-card builders for `P0-04` made most
      of **P1** cheap to land in the same pass, so it did:
      fixed-height fleet cards with `CARD_BG`/`CARD_BG_TARGETED` backing, a
      top color bar, and an `ALERT` border+shadow when targeted (`P1-09`);
      larger colored index numbers (`P1-11`); `SEC N` above the card in the
      ship color (`P1-12`); wolf pips as filled-remaining/hollow-damage-taken,
      hollow first, via the new `wolf_code_pips.gd` (`P1-13`); the pursuit
      meter as one `_draw()` call in `pursuit_meter.gd`, amber-filled/
      navy-empty/crimson-doom-cell (`P1-15`); phase rail active item is
      larger/bold/cyan with fixed per-item widths so the row doesn't reflow
      (`P1-16`, minus the glow - that's `P2-21`); header `TURN N` +
      cap-state-colored `COMMITTED`, built as one `RichTextLabel` with BBCode
      per the spec's own suggestion (`P1-17`); outlined ship-type chips vs.
      filled `ALERT_DEEP` BP chips via a shared `_make_chip()` helper
      (`P1-18`); footer short names (new `CraftDefinition.short_name` field,
      `core/craft/craft_definitions.gd`) + cyan triangles (`P1-19`, minus
      Gorgoneion/Vulcan - still blocked on Small Ships not being `core/`
      objects); wraps line in `CYAN_DIM` with tracking (`P1-20`).

      Verified structurally against a live driving script each time (content
      scale, title hand-off between the shared and STANDING-owned titles,
      stat line/pursuit meter/breadcrumb text and state, range-bands
      visibility toggling on/off with phase, wolf item/pips/fleet-card
      structure and coloring, targeting-line link count, footer entry
      count, and the P0-08 debug-text removal) - one round-trip bug in the
      test script itself (a wrong child index), not the app. Full test
      suite still green (37 files) - no `core/` changes beyond the new
      `short_name` field, which is plain display-string data, same
      category as `display_name` already living there.

      **Deliberately not done in this pass**: **all of P2** (`P2-21`..
      `P2-24`: glow, dash-offset animation, pulse, cross-fade) -
      explicitly the polish tier, ordered last in the spec's own priority
      list; the P0-08 "route it through the host console instead"
      follow-up for the removed debug lines - not built, just removed,
      since that's a new host-console feature, not a TV-side fix.

      `P1-10`/`P1-14` (filled/silhouette ship icons) landed in a follow-up
      round: the user hand-authored real `.svg` art for all 12 ships (6
      Wolf hull classes + 6 fleet ships) under `res://svg/` and asked for
      it to replace the v1/v2 placeholder icons. `ship_icon.gd` was
      rewritten from a hand-drawn `_draw()`-per-class vector artist into a
      texture loader: one `Dictionary[String, Texture2D]` of
      `preload()`s, `_draw()` now just fits the right texture into the
      Control's rect (aspect-preserved, centered) via `draw_texture_rect`.
      `icon_color` still exists and is passed through as a modulate
      multiply rather than dropped - the SVGs already bake in a color per
      ship close to `WolfAttackTokens.SHIP_COLOR`/`INK`, so passing those
      same tokens through is close to a no-op most of the time, and it's
      what makes the "destroyed" wolf-ship dim state (multiplying by the
      dark `INK_GHOST`) keep working without a special case. `line_width`
      (unused by any caller) was dropped along with the old stroke-drawing
      code.

      Also fixed, from direct user feedback on the running P0 build: the
      backdrop is a flat `WolfAttackTokens.BG_DEEP` fill now, not the
      gradient+bloom `wolf_backdrop.gd` built for `P0-03` ("do the whole
      background in a single dark color") - the gradient/bloom code was
      simple enough to leave in place but is currently unused; and the
      wolf force row was stretching a single ship across the entire
      screen width, or would have badly crushed a large attack (a real
      attack can field up to ~20 wolf ships, not just the reference
      image's 6) - `WolfForceRow` changed from an `HBoxContainer` with
      `SIZE_EXPAND_FILL` children to an `HFlowContainer` (`alignment =
      ALIGNMENT_CENTER`) with a fixed 180px item width, so N ships wrap to
      more rows instead of stretching or squeezing, matching spec §4.5
      step 9's intent ("the row must survive N ≠ 6") without the spec's
      more granular per-count threshold rules.
- [ ] **P2 - polish**: fake glow on the active band arc/targeted
      cards/active phase dot (`P2-21`); dash-offset travel animation on
      attack vectors (`P2-22`); slow pulse on targeted card borders
      (`P2-23`); phase-transition cross-fade (`P2-24`).

**Data contract additions** (§5 of the spec) - `core/` stays presentation-free,
these are new/extended keys on the existing flat snapshot dict, not new
rules: `turn` (missing from the contract entirely - header needs it),
per-wolf-ship `damage_taken` and `returns` (drives pip fill state and the
inline `↻` glyph), and a generalized `untargetable` list (short_name/value/
modifier triplets) so the footer can cover more than just fighter wings.
`wolf_ability_label(hull, phase) -> String` is meant to be a small pure
function in `core/` (derived from damage-if-destroyed-at-phase, not stored),
which also makes it headlessly testable per the spec's §7 note.

**Open items - do not guess, per CLAUDE.md** (spec §9, flagged rather than
resolved by the spec author):
1. `BS` and `CR` ability labels at **Long** range - not visible in either
   reference image; verify against the Facilitator Guide before wiring.
2. Gorgoneion shield value and Vulcan laser state derivation, and whether
   they always appear in the footer or only when active.
3. Signature colors for the small ships (Endeavour, Maliades, Pallas,
   Voyage 33-0) - needed before they can appear on this screen at all.
4. Whether small ships appear on the Wolf Attack targeting table at all
   (already on the project's open-questions list) - determines whether
   `FleetRow` needs to handle more than 6 cards. Build it N-capable
   regardless, per the spec, but tune spacing for 6 until answered.

## Next up — Wolf Attack TV display v3: lane layout (replaces v2's WolfForceRow/AttackVectors)

The user watched the v2 build with a bigger wolf roster and it fell apart -
a wide attack wraps the single wolf row to a second line, and the bezier
vectors from row 2 pass straight through row 1's tokens and cross each
other, so the one thing this screen exists to show (which wolf is hitting
which ship) stops being readable at exactly the moment it matters most (high
pursuit, big attack). The fix is a full handoff folder:
`ui/design_handoff_wolf_attack_lanes/` - **read `wolf_attack_tv_display_v3_lanes.md`
in there directly before starting**, it's the authoritative spec (rationale,
exact geometry, scaling tables, phase behavior, data contract, acceptance
checklist, open questions). `README.md` in the same folder is a slightly
denser restatement with a couple of extra visual details (e.g. the backdrop
recipe, exact type scale). `Wolf Attack Lanes.dc.html` + `support.js` is a
browser-openable HTML/JS prototype - **not production code to port**, but
its logic class is reference pseudocode for lane grouping/tier
selection/ordering, and it's driven by editable `scenario`/`phase` props at
the top of `renderVals()` so every acceptance-checklist roster can actually
be looked at before committing to layout choices. `Wolf Ships.dc.html` is
the superseded v2 screen plus a silhouette reference sheet - silhouette
intent only, not the layout to build.

`svg/` in that folder is now the **only** copy of the 12 ship silhouettes -
`res://svg/` (the v2 SVG pass's original location) has been removed on the
user's explicit instruction, and `ship_icon.gd` preloads directly from
`res://ui/design_handoff_wolf_attack_lanes/svg/` instead. That means this
handoff folder is no longer just reference material sitting next to
production code (unlike `wolf_attack_tv_display_v2_gap_spec.md`/
`Wolf_Ships-selection.png`, which are) - its `svg/` subfolder specifically
is a live asset dependency. Whoever builds v3 should keep that in mind if
this folder ever gets tidied away or archived once the lane redesign
lands - moving/deleting it again will silently break every `ShipIcon`
preload the same way it did the first time (caught and fixed mid-session;
see git history around the v3 TODO.md entry for the full story).

**The core rule** (spec §1): *a wolf ship is drawn inside its target's lane;
adjacency replaces vectors.* Six capital ships → six vertical lanes, wolves
stack bottom-aligned above their target's card, growing upward. Nothing
crosses at any ship count, and stack height becomes a threat histogram
readable in under a second from across the room. Two things this buys, and
why they're deleted: `→ SHIPNAME` on each wolf token is redundant (the lane
says it) and the fleet card's attacker-chip row (`SC` `CR` `DE`...) is
redundant (the stack above the card *is* that list, with hull state
included) - both removals free the space the stacks need.

**Supersedes v2's layout only** - v2's design tokens/palette/type scale
(§2), backdrop/header/pursuit meter/phase rail (§4.1-4.4), footer (§4.9) and
Godot implementation notes (§7) are explicitly still in force and don't need
rebuilding, just reusing from `wolf_attack_tokens.gd` etc. **Deleted**
(v3 spec §7): the bezier `AttackVectors` node and its `_draw()` entirely; the
`→ SHIPNAME` target line on wolf tokens; the fleet card's attacker-chip row;
the `LONG`/`MEDIUM`/`SHORT` gutter labels and dashed dividers from
`range_bands.gd` (range is now one continuous labelled arc, not three
spatial bands); the single wide `WolfForceRow` `HBoxContainer`. **Kept on
the card**: the `N BP` chip (boarding is its own phase, stays visible in two
places). **Moved**: `SEC N` goes inside the card's top-right corner, since
the space above the card is now the spine's entry point.

**New pieces to build**:
- `LaneRow` (`HBoxContainer`, replaces `WolfForceRow` + `FleetRow` combined)
  of `Lane` controls, each holding a `Wash` (colored `ColorRect` over the
  stack zone only, binds a stack to its card without a line), a `Stack`
  (bottom-aligned, **manual positioning, not a `VBoxContainer`** - per spec
  §11, `VBoxContainer` grows from the top and fights bottom-alignment), a
  `Spine` (one vertical `ALERT` bar per lane, width `clamp(incoming_damage,
  2, 10)`, from stack bottom through the card's top edge - the only vector
  graphic left, and it can't cross another one), an `IncomingLine` (derived
  `▼ N DMG` / `NO CONTACT` / `— AWAITING TARGETS` summary), and the
  restyled `FleetCard`.
- `StagingPool` - visible only during `targeting`, before any wolf has a
  `target_ship_id`. A centred grid ignoring lane boundaries; as the host
  resolves targets, each wolf **tweens from its pool position into its
  lane** (0.35s, staggered 60ms if many resolve at once) - "watching the
  columns build is the spectacle this phase should have."
- `ImpactArc` - one continuous curve across the full width (not per lane,
  not three bands like v2's `RangeBands`), tweens its control point ±14px
  on phase change.
- `WolfTally` - new one-line aggregate at y=248: `BS×1  SC×1  CR×4  ·  3
  DESTROYED`, live-hull counts only, always derived, never stored. Fills
  the gap left by deleting the per-token target line as the thing players
  read to decide what to shoot during Short range.

**Scaling is the part that has to be right** (spec §5) - two independent
axes, `n_lanes` (fleet size) and `max_stack` (busiest lane), computed
together; **the tier comes from the busiest lane and applies to every
lane** (uniform token size is what makes the histogram valid - do not size
lanes independently). Five tiers from `max_stack`: 1-3 → full 100px tokens
(A), 4-8 → compact 34px (B), 9-16 → compact 30px in 2 columns (C), 17-24 →
compact 26px in 3 columns (D), 25+ → same as D plus a `+N MORE` overflow
chip. All tiers are sized to fit the 332px stack zone exactly (worked
arithmetic is in spec §5.1 - use it, don't re-derive). Multi-column lanes
fill bottom-up/left-to-right so the ragged edge sits at the top, reading as
depth. At `max_stack ≤ 2` the impact line rises and cards grow to 280px
instead of leaving dead air; at `n_lanes ≤ 4` lanes cap at 380px wide and
centre rather than stretching. Below 150px lane width cards lose their
index number and icon; below 120px, stop and flag to the host rather than
silently wrapping to two rows of lanes.

**Token identity matters more here than in v2** - wolf counts change every
phase, so per spec §11: pool ~24 `WolfToken` instances up front and
show/hide + reposition rather than `queue_free()`/re-instantiate on every
push (visible hitching otherwise); match tokens by `uid` across pushes and
tween them to their new slot, never rebuild the stack from scratch, "or
every token jumps and the room loses track of the ship it was watching."
Ordering within a lane, bottom (nearest card) to top: live wolves by
descending damage capacity, ties broken stably by `uid`, then destroyed
wolves same sort at the top - destroyed hulls sinking to the top keeps the
histogram honest (stack height = total commitment, the dense band at the
bottom = what's still coming).

**Data contract deltas** (spec §9, on top of v2 §5): `wolf_ships[].destroyed`
is now required explicit (not inferred from `damage_taken == capacity`);
`target_ship_id: ""` during targeting routes a wolf to the staging pool
instead of a lane; `fleet_ships[].attackers` is **removed** - the lane
derives that list instead of the view pre-computing it. `core/` stays
exactly as clean as v2 asked: lane grouping, tier selection and
`incoming_damage`/`incoming_bp` are view-layer derivations from the flat
snapshot, cached on the lane row and invalidated on push (not recomputed
per frame), and `incoming_damage` must be labeled as a **projection** (what
lands if the fleet destroys nothing more this phase), never as committed
fact - "exactly the arithmetic the host should not be doing in their head."

**Real bugs to fix alongside the rebuild** (spec §12, evidently seen on a
screenshot of the actual v2 build, not just theoretical) - check each
against the current code before assuming it's already handled:
1. `10 CAP · 87 COMMITTED` - the P0 pass added a `push_error` assertion in
   `_refresh_stat_line()` for `committed > cap`, but not the visual
   `CAP EXCEEDED` chip (mono 18px `#FFC53D`, filled `rgba(255,197,61,0.16)`,
   1px `#FFC53D` border) or a host-console-visible warning the spec now
   also asks for - both still open.
2. Every wolf in that screenshot was a Battlestation (15 × 6 capacity = 90
   against a cap of 10) - suggests whatever roster generator produced that
   test data always picks the first hull in the table instead of sampling
   the attack-scaling formula from `open_questions_answered.md`. Not
   necessarily this project's code (could be the design prototype's own
   synthetic-roster generator) - **investigate which generator produced
   it** before assuming `core/`'s is broken.
3. Destroyed-token rendering: v3 §4.4 wants the whole token dimmed
   (`alpha 0.3`) while *keeping* its code/pips/colour cues plus a
   strikethrough, not replacing the ability line with `DESTROYED` and
   losing the color entirely the way the current `_build_wolf_item()`
   does. This is an explicit v3 behavior change, not just a bug fix - the
   README's version of §4.4 goes further still ("do not stack alpha on
   alpha - keep the token at full opacity and express death in colour"),
   so **reconcile the README vs. the .md spec's own wording on this one
   point** before implementing (they disagree on whether the *token* or
   just its *contents* should dim).
4. `TARGETING WRAPS` allegedly rendered behind the fleet cards in that
   screenshot - the current build already positions it at y≈940, below the
   card band (which ends at 898), so this may already be fixed; verify
   against a live run rather than assuming either way.
5. Fleet cards 3 and 5 reportedly had no border while the others did, all
   six should use the same `card_idle`/`card_targeted` styling with no
   third state - also worth a live-run check before assuming it's stale.

**Open questions - do not guess** (spec §14, carried forward plus one new):
1. `BS`/`CR` ability labels at Long range - still not in any reference.
2. Gorgoneion/Vulcan footer rules.
3. Signature colors for Endeavour, Maliades, Pallas, Voyage 33-0.
4. Whether small ships appear on the targeting table - now directly sets
   `n_lanes`, the highest-value open question for this screen specifically.
5. **NEW - can a single wolf ship split its attack across two targets?**
   Every wolf card in the source material reads "damage to target,"
   singular, which is what makes the one-wolf-one-lane partition clean. If
   any hull or event can hit two ships, a wolf would need to appear in two
   lanes and the whole partition breaks. **Confirm against the Facilitator
   Guide before locking this design** - per the spec's own instruction, not
   just this file's usual caution.

**Acceptance checklist** (spec §13) is the real verification target once
built - synthetic rosters at 3/8/15/24/30 wolves, 4 and 10 lanes, and a
12-wolves-on-one-ship case, checking that the tallest stack is always the
most-attacked ship, destroyed wolves stay visibly dead but counted, phase
changes re-derive every ability label with no state push, and a host
reassigning a target from the admin console actually moves the token to
its new lane rather than the lane layout being a read-only derivation.
