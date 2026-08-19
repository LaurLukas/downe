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
and wrote it up as `wolf_attack_tv_display_v2_gap_spec.md` (`docs/`) -
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

**Open items - do not guess, per CLAUDE.md** (spec §9; flagged by the spec
author, now checked against the real physical card set found at
`C:\Users\lukas\Desktop\downe\DoWNE - A4 Double Sided v1.0 (1).pdf` - the
Facilitator's Guide PDF itself only lists "Wolf Ship cards" as a
battle-table component, it doesn't print their text, so the answers below
came from the printed cards themselves, not the Guide):
1. [x] **`BS`/`CR` ability labels at Long range - not a data gap, just an
   image the spec author didn't have.** The printed Battlestation card has
   no Long-range-specific line at all - its effect is "if destroyed at
   **any** range: 3 damage to target" (it's simply immune at Short, per
   `IMMUNE_PHASES` below) - while the printed Cruiser card is explicit:
   "if destroyed during Long Range: **No effect**." Both match
   `core/combat/wolf_ship_definitions.gd`'s `DAMAGE_IF_DESTROYED_AT`
   table exactly (Battlestation `{LONG: 3, MEDIUM: 3, SHORT: -1}`, Cruiser
   `{LONG: 0, MEDIUM: 1, SHORT: 2}`), as does every other hull's table
   entry (Strikecarrier, Destroyer, Fighter Wing, Assault Transport) and
   the boarding-party/returns/immune-phase flags. `core/` already has this
   right - now triple-verified (source doc → brief's own PREVENTS
   cross-check → the actual printed cards), nothing to change in code.
2. **Gorgoneion shield value and Vulcan laser state - the abilities and
   their exact numbers are now known; the footer display question is not.**
   From the printed I.C.S.S. Gorgoneion and P.V. Vulcan craft cards:
   - Gorgoneion's **Force Field Projector** (requires charged): before the
     Targeting step, choose 1 ship; that ship's total damage taken this
     attack is reduced by a flat **2**, applied once at end-of-attack
     resolution. The "shield value" is not a derived or variable number -
     it's a fixed -2, gated only on whether the console was charged that
     turn (same charged/uncharged pattern as every other console in the
     game).
   - Gorgoneion's separate **Missile Array** (requires charged, offensive
     not defensive): 3 dice at each of Long/Medium/Short range, 1 damage
     per 6+/5+/4+ rolled, capped at 1 damage per individual target per
     phase.
   - Vulcan's **Laser Cannon** (requires charged): 2 dice at Medium and
     Short range only (not Long), 1 damage per die on a 4+.
   None of this is implemented in `core/` yet (confirmed via grep - only
   file-comment placeholders reference Gorgoneion/Vulcan combat today),
   consistent with Small Ships not being modeled as objects at all. Still
   genuinely open: whether the footer shows these consoles' state
   unconditionally or only when charged/relevant - the source never
   addresses TV display conventions, only game rules - but by analogy
   with how Fighter Wings already gate on their Fighter Bay's
   charged/undamaged state before appearing in combat, gating the footer
   entry the same way is the consistent choice once Small Ships exist as
   `core/` objects.
3. [~] **Signature colors - the 6 core ships are now answered, the 4
   remaining craft/small ship are not.** New `ship_colors.md` (`docs/`)
   gives the canonical six, sourced from `wolf_attack_tv_visual_redesign.md`
   §5.1: AEGIS `#CFE4F5`, Dione `#A97BFF`, Icebreaker `#E8873C`, Quellon
   `#46D6C0`, Shepherd `#7FD46A`, Refinery 124 `#F2D04A` - each hue tied to
   what the ship *does* (ice-white command, ore ember, water aqua, food
   leaf, fuel sulfur), plus the two derived-state rules ("colour is
   identity never status", "no ship gets red - that's Wolves-only"), a
   `--fleet-dim` destroyed-state color, and a ready-to-use
   `res://core/ship_colors.gd` constants block. **Still open**: Endeavour,
   Maliades, Pallas, and Voyage 33-0 (the small-ship/craft colors this
   item was originally about) aren't in `ship_colors.md` either - it only
   covers the 6 capital ships. [x] **Reconciled**: `ui/tv/wolf_attack_tokens
   .gd`'s `SHIP_COLOR` dict previously used its own slightly different hex
   values for the same six ships (e.g. Dione `#8B5CF6`, Icebreaker
   `#C2703C`) - now updated in place to match `ship_colors.md` exactly, so
   there's one canonical set of values even though they still live in two
   files (the `.md` doc and this `ui/`-layer dict - no `core/ship_colors.gd`
   was added, since the only current consumer is `ui/tv/wolf_attack_display
   .gd`; revisit if ESP32/web clients ever need the same values, per
   `ship_colors.md`'s own cross-surface-use section).
4. [x] **Whether small ships appear on the Wolf Attack targeting table -
   no, confirmed from the real player-facing rules sheet, not just
   inferred.** Every team's "Rules Reference" card (e.g. the AEGIS
   Admiral's Team Brief and Role Guide) prints the actual Targeting Table
   handed to players: a 1d6 roll mapping 1-6 to the six core ships only
   (`1 AEGIS, 2 Dione, 3 Icebreaker, 4 Quellon, 5 Shepherd, 6 Refinery
   124`) - there is no 7th+ entry and no separate table for Small Ships or
   craft. This matches `core/combat/wolf_ship_definitions.gd`'s
   `TARGETING_TABLE` exactly. `FleetRow`/`LaneRow` can be built assuming
   `n_lanes` is always exactly 6 - Small Ships are never valid Wolf Attack
   targets, full stop, not just "probably not."

## Done (structural pass; polish deferred) — Wolf Attack TV display v3: lane layout

**Landed**: the full lane rebuild described below - `LaneRow` of per-ship
`Lane` controls (`Wash`, manually-positioned `Stack`, `IncomingLine`,
restyled `FleetCard`), a single-`_draw()` `LaneSpines` overlay replacing
the bezier `AttackVectors`, a single-`_draw()` `ImpactArc` replacing the
three-band `RangeBands`/gutter labels, the `§8` wolf force tally, and a
structurally-correct (if practically unreachable, see below) staging
pool. `range_bands.gd` and `targeting_lines.gd` are deleted per the
spec's own §7 instruction, not just unused.

**New files**: `ui/tv/wolf_lane_layout.gd` (`WolfLaneLayout`, `RefCounted`,
zero Node dependency) holds every derivation the spec's §11 says belongs
outside `core/` but is still pure enough to unit-test headlessly - lane
grouping, tier selection (`§5.1`'s A/B/C/D/D+ table), the
descending-capacity/ascending-uid/destroyed-sink-to-top ordering rule,
bottom-up-left-to-right multi-column slot math, overflow-chip slot
reservation, and the two projected-incoming numbers (damage, boarding
parties). `tests/ui/wolf_lane_layout_test.gd` (29 tests) covers all of
it directly, including a regression guard for a real bug this pass found
(see below). 38 test files total, still all green.
`ui/tv/impact_arc.gd`, `ui/tv/lane_spines.gd`, `ui/tv/strike_through.gd`
are the new small single-purpose `Control`s, matching this project's
existing pattern (`WolfCodePips`, `ShipIcon`).

**A design decision the spec left open, resolved by the user**: the .md
spec and its own README disagreed on destroyed-token rendering - whole-
token `alpha 0.3` + strikethrough (`.md` §4.4) vs. full opacity with only
the contents dimmed (README). The user's explicit call was the former;
`WolfCodePips` was extended so a destroyed token renders with **every**
pip hollow (not just the ones matching `damage_taken` at the moment it
died), matching the "nothing remains" reading the `.md` spec asks for.

**Real bugs caught before this ever reached a live window** (this
project has no way to screenshot a running Godot instance, so a headless
driving script - `verify_v3.gd`, deliberately not committed, matching
this project's established "throwaway diagnostic" pattern - instantiated
the real `wolf_attack_display.tscn` against synthetic rosters at every
acceptance-checklist tier, including a 30-wolves-on-one-ship case built
specifically to force the D+ overflow chip):
- `StyleBoxFlat` has no `set_content_margin_individual()` - the real API
  is `set_content_margin(side, value)` per side. Would have crashed the
  very first compact token drawn in real play.
- `ImpactArc._draw()` assigned `Dictionary.get()`'s `null` miss straight
  into a strictly-typed `Dictionary` var, which GDScript rejects before
  the following `null` check ever runs - fixed to check `CURVES.has()`
  first. Harmless today only because `queue_redraw()` never fires for an
  invisible node in the phases where this would have mattered; still a
  real crash waiting for the first code path that changes that.
- A boolean built from three chained `Variant` dictionary lookups
  (`phase == ... and wolf["class"] == ... and not wolf["destroyed"]`)
  failed static type inference outright - GDScript couldn't prove the
  expression was a `bool`. Fixed by typing the two dictionary reads
  first. Not a runtime bug, a straight compile failure - would have
  blocked the scene from loading at all.
- The damage bar's fill `ColorRect` set only `anchor_right`, leaving
  `anchor_bottom` at its default (0), which gives the fill zero height -
  every fleet card's damage bar would have rendered as an invisible
  sliver.
- Adding the destroyed-state `StrikeThrough` overlay as a direct child of
  the token's own `VBoxContainer`/`PanelContainer` would have made that
  *container* try to lay it out as another row/item instead of drawing it
  on top - fixed by wrapping token content in a plain `Control` holder so
  the strikethrough can sit as an independent anchored sibling.
- `WolfLaneLayout.incoming_bp_for_lane()` deliberately does **not** reuse
  `WolfAttackView`'s own `"boarders"` field - that field is only
  populated while `attack.phase` is one of the three range phases
  (`_build_wolf_ships`'s `in_range_phase` gate), so it always reads 0
  during `"targeting"` even for an Assault Transport that already has a
  target. Derived from the hull constant instead, so the incoming line is
  correct at every STANDING phase, targeting included - the same class of
  gap the v2 fleet card's boarding chip had already hit once before (see
  the P0/P1 entry above), caught here by a dedicated regression test
  (`test_incoming_bp_ignores_core_range_phase_gating`) rather than by
  someone noticing a blank number on a live screen.

**Two more spec inconsistencies resolved in favor of the stated formula
over an unreconciled table number**, same reasoning already applied once
in this project (choosing `lane_width`'s formula over its own table,
which don't actually agree for `n≠4` - see the "Open questions" entries
below): the incoming line's y-offset uses the README's explicit
`impactY + 8` rather than the `.md` table's unexplained `652`, and the
wolf tally omits `N DESTROYED` when zero (the `.md`'s own rule) rather
than showing README's "NONE DESTROYED".

**Deliberately not built, documented rather than silently skipped** (see
`wolf_attack_display.gd`'s own file-header comment):
- **Token pooling and the targeting-phase tween-from-staging-pool
  spectacle** (§6.1/§11). This project's established pattern for a first
  structural pass is data/geometry-correct now, animation polish later
  (the v2 P0/P1/P2 split did the same) - a tween's feel can't be judged
  without a human watching a live window. Every lane rebuilds fresh each
  refresh, same as v2's `WolfForceRow`/`FleetRow` always did.
- **The staging pool is structurally unreachable in this project's real
  `WolfAttack` state machine**, not just unbuilt: targets are pre-rolled
  the instant a wolf ship is added and revealed in full the moment the
  attack leaves `Phase.INCOMING` (`WolfAttackView`'s `targets_visible`
  gate), so no wolf ever actually reaches `"targeting"` with an empty
  `target_ship_id`. The render path is still implemented correctly for a
  wolf that genuinely has none - worth keeping in mind if `core/`'s
  targeting flow ever becomes incremental instead of instant-reveal.
- The impact arc's ±14px phase-change "settle" tween.
- Everything already-known-blocked before this pass started: Gorgoneion/
  Vulcan footer entries (Small Ships still aren't `core/` objects),
  Endeavour/Maliades/Pallas/Voyage 33-0 signature colors, and the `BS`/
  `CR` Long-range labels question (already closed - see below).

**Verified**: `tests/ui/wolf_lane_layout_test.gd` unit-tests every pure
derivation directly. The throwaway driving script exercised the actual
`Control` tree end-to-end at 3/8/15/24 wolves spread normally, 12 and 30
wolves concentrated on one ship (the latter specifically to force the D+
tier's overflow chip - confirmed exactly 22 real tokens + 1 chip = 23
stack children, matching the unit test's own prediction), across both
`"targeting"` and a mid-range-phase state, checking lane count (always
6) and per-lane token counts with no crashes. Not verified, and not
verifiable without a human looking at a live window: actual pixel
geometry/color fidelity, the acceptance checklist's "legible at 2m from a
55\" panel" and "a stranger can point at a token and name its target
without tracing anything" items, and anything covering the deferred
tween/pooling behavior above.

**A real bug my synthetic testing didn't catch, found from the user's own
host-console use**: `_refresh_stat_line()` kept v2's `push_error("...
committed exceeds cap ... should not be reachable")` call, and it fired
in real logs the first time the host actually added a real-sized attack
- 15 committed against a pursuit-0 cap of 10. My verification script's
synthetic rosters happened to always test genuinely-broken states
(30-on-one-ship, etc.) where an error was arguably expected noise, so
this never stood out. It should never have been a `push_error` at all:
the base-10-plus-pursuit cap is advisory context for the host, not an
engine-enforced rule, and the Facilitator's Guide's own printed turn-1
example ("10 Wolf Fighter Wings and 5 Wolf Assault Transports") exceeds
a pursuit-0 cap of 10 on purpose - later attacks are sized by total
damage capacity (15-24) with no reference to this formula at all.
Removed the `push_error`; the CAP EXCEEDED chip (already built for
spec §10.1) is the correct level of signal for this - visible to the
host, not logged as if it were an engine bug.

**Two more real bugs, both from the user actually looking at a live
run** (neither showed up in the synthetic driving script, for two
different reasons - worth internalizing for next time):
- **Assault Transport read "PREVENTS 0 BP" instead of "PREVENTS 4 BP"**.
  `WolfLaneLayout.ability_label_full()`/`ability_abbrev()` read core's
  own `"boarders"` field directly for this one hull - the exact same
  phase-gating gap already fixed once for `incoming_bp_for_lane()`
  (`WolfAttackView` only populates `"boarders"` during a live range
  phase, so it reads 0 during `"targeting"`), just missed in the two
  label functions sitting right next to it. My driving script never
  caught it because it only ever checked *counts* (lane count, token
  count), never token *content* - a gap in what the script asserted, not
  in what it exercised. Fixed by deriving the boarding-party count from
  the hull constant in the label functions too, via a new shared
  `_assault_transport_boarders()` helper; both label functions now agree
  with `incoming_bp_for_lane()` by construction instead of by
  coincidence. New regression test:
  `test_ability_label_full_assault_transport_ignores_core_range_phase_gating`.
- **Shepherd's lane sat in position 4 while its own card read "5", and
  Quellon sat in position 5 while its card read "4"** - the two were
  swapped. Lanes were built by iterating `view["fleet_ships"]`, itself
  built from `ShipRegistry.all_ship_ids()`, which lists Shepherd before
  Quellon (`ship_registry.gd`'s own `DISPLAY_NAMES` order - deliberate
  for the Host Console/TV fleet-overview rows elsewhere in the project,
  per CLAUDE.md's own Ships table using that same order). The Wolf Attack
  Sheet's targeting-die order is different (4 Quellon, 5 Shepherd), and
  each fleet card's *index number* was always computed correctly from
  that table via `TARGETING_TABLE.find_key()` - only the lane's physical
  left-to-right *position* used the wrong order. Harmless in v2 (a card
  row with no positional meaning), but load-bearing in v3, whose entire
  premise is "lane position tells you the ship" - a card sitting in the
  wrong slot relative to its own printed number undermines exactly the
  thing this rebuild exists to fix. My driving script never caught this
  either: it checked lane *count*, never lane *order*. Fixed narrowly,
  not by reordering `ShipRegistry` globally (which the rest of the
  project intentionally relies on) - a new
  `WolfLaneLayout.sort_fleet_ships_by_targeting_order()` re-sorts the
  fleet-ship list by targeting-die index before lanes are built, scoped
  entirely to this screen. New regression test:
  `test_sort_fleet_ships_by_targeting_order_fixes_shepherd_quellon_swap`.

Both fixes verified against the real running scene (not just the unit
tests) with a second throwaway driving script: a single Assault
Transport targeting AEGIS during `"targeting"` now shows "PREVENTS 4 BP"
on its full-form token, and all six lanes now read index 1 through 6
left to right in order.

**A third real bug, this time from a screenshot** (`docs/Wolf_attack_v3_lanes.png`
- the user pointed a camera at a real run, not just described symptoms):
ability text (`SIEGE BATTERY`, `PREVENTS 1`, etc.) bled down out of the
full-form wolf token and overlapped the impact arc and incoming-damage
line below it. Root cause: `_build_full_token()`'s icon (52px) + code/pips
row (34px) + ability `Label` (whatever an 18px font naturally needs) were
all fixed guessed heights that summed to well over the tier's 100px slot
- `VBoxContainer`'s children don't get clipped to their parent's actual
rect when their combined minimum size exceeds it, so the ability text
just kept drawing past the token's bottom edge into whatever was
underneath. Neither driving script had caught this because both only
ever checked *counts* (lanes, tokens per lane) - never a single token's
actual rendered geometry - so this sat undetected through two rounds of
"verified against the real running scene."

Fixed by computing the icon's height as whatever's left over after the
other two rows' *real* sizes, not by guessing all three up front:
- The ability `Label` enforces its own true minimum size from Godot's
  own font metrics (`Font.get_height()`) regardless of what it's asked
  for, so that row has to use the real measured value or the label wins
  the size fight and overflows again - confirmed via a headless script
  that measured all three rows' actual combined minimum size afterward:
  31.3 + 35.7 + 25.0 + 2×4 gap = 100.0px exactly, matching the 100px
  slot with no residual overflow.
- `WolfCodePips`, unlike the label, is a bare `Control` with no
  intrinsic minimum size of its own (its `_draw()` just paints at fixed
  offsets regardless of the rect it's given), so it doesn't need the
  font's full technical line-height reserved for it either - a tight
  `font_size × 1.05` is enough, and freeing that difference back to the
  icon keeps it from shrinking more than necessary.
- `holder.clip_contents = true` was added as a defensive backstop on top
  of the real fix, not a substitute for it - if a future change to any
  of these three rows' sizing ever drifts out of budget again, the worst
  case is now a slightly cropped label, not text bleeding across
  unrelated UI elements below it.

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

**Open questions - do not guess** (spec §14, carried forward from v2's §9
list above - four of five now checked against the real card set, see that
entry for the full source citations; summarized here):
1. [x] **`BS`/`CR` Long range labels** - not a data gap. Battlestation has
   no Long-specific line (immune only at Short, 3 dmg any other range if
   destroyed); Cruiser's printed card says "No effect" at Long explicitly.
   Both already match `wolf_ship_definitions.gd` exactly.
2. **Gorgoneion/Vulcan footer rules** - the abilities/numbers are now
   known (Force Field Projector: flat -2 to one chosen ship, chosen
   pre-Targeting, if charged; Missile Array: 3d6 per range phase, 1 dmg
   per 6+/5+/4+, capped 1/target/phase; Laser Cannon: 2d6 at
   Medium+Short only, 1 dmg per 4+, if charged) - none implemented in
   `core/` yet. Still open: footer visibility (always-shown vs.
   only-when-charged) - a UI convention the source never states.
3. [~] **Signature colors** - the 6 core ships are answered by
   `ship_colors.md` (`docs/`; see the v2 §9 entry above for the hex
   values, the identity-not-status rules, and the `wolf_attack_tokens.gd`
   reconciliation note). Endeavour, Maliades, Pallas, and Voyage 33-0 -
   the four this item was actually about - are still unanswered; that
   file only covers the 6 capital ships.
4. [x] **Whether small ships appear on the targeting table - no.**
   Confirmed from the actual printed Targeting Table on every team's Rules
   Reference card (not just inferred): 1d6 → one of the 6 core ships,
   nothing else. `n_lanes` is always exactly 6.
5. [x] **Can a single wolf ship split its attack across two targets? No.**
   Checked against the real printed Wolf Ship cards (`DoWNE - A4 Double
   Sided v1.0 (1).pdf`, found at `C:\Users\lukas\Desktop\downe` - the
   Facilitator's Guide PDF itself only lists "Wolf Ship cards" as a
   battle-table component, it doesn't print their text). All 6 Wolf hull
   types (Battlestation, Fleet Strikecarrier, Fighter Wing, Cruiser,
   Destroyer, Assault Transport) print exactly one "Target" box and one
   "Damage Taken" box per card, and every damage line reads "damage to
   **target**" (singular) - including the Strikecarrier's "if not
   destroyed" clause, which buffs *other* Fighter Wings' damage by +1
   rather than redirecting its own. The AEGIS Admiral's briefing sheet's
   Targeting Table (1d6 → one of the 6 ships) also assigns exactly one
   target per roll. The one-wolf-one-lane partition v3 depends on is
   confirmed sound - safe to lock the design on this point.

**Acceptance checklist** (spec §13) is the real verification target once
built - synthetic rosters at 3/8/15/24/30 wolves, 4 and 10 lanes, and a
12-wolves-on-one-ship case, checking that the tallest stack is always the
most-attacked ship, destroyed wolves stay visibly dead but counted, phase
changes re-derive every ability label with no state push, and a host
reassigning a target from the admin console actually moves the token to
its new lane rather than the lane layout being a read-only derivation.

## Done (structural pass; STANDING phases only) — Wolf Attack TV display: damage ladder

**Landed**: the 4-cell Long/Medium/Short/Survives ladder replacing
`PREVENTS N` on every wolf token, the `↻`/`4BP`/`+N`/`⊘S` badges, and the
lane incoming line's floor/ceiling range + bar replacing v3's single
projection - across all four tiers (A headed/A2 headerless full-art,
B/C/D compact degraded forms) and the new Tier A/A2 boundary (`≤2`
headed 118px, exactly `3` headerless 100px, per the user's confirmed
call to follow the handoff README's deviation rather than the spec's
literal §4).

**New/changed files**: `core/wolf_damage.gd` (`WolfDamage`, pure,
re-derived from `wolf_ship_definitions.gd`'s already-verified
constants - `tests/core/wolf_damage_test.gd`, 5 tests) provides
`ladder()`/`damage_if_destroyed_now()`/`damage_if_survives()`.
`wolf_lane_layout.gd` gained `lane_ceiling()`/`lane_floor()` (replacing
`incoming_damage_for_lane()`), `live_strikecarrier_count()`, the four
`badge_*()` queries, and `ladder_cell_values()`/`ladder_cell_states()`
(the latter returns a `CellState` enum, not a `Color` - colour mapping
stays in `wolf_attack_display.gd` so this file keeps its established
zero-visual-dependency rule). `ability_label_full()`/`ability_abbrev()`
are gone entirely, along with the "prevents"/per-wolf "boarders" fields
`WolfAttackView` used to compute for them (dead once nothing read them -
confirmed via grep before removing); `WolfAttackView` gained
`destroyed_at_phase` instead, which the ladder needs to show a destroyed
wolf's actually-realised cell.

**A real ambiguity in the spec's own wording, resolved against primary
sources rather than guessed** (documented at length in
`core/wolf_damage.gd`'s file header): §8 says `damage_if_survives` "takes
live_fw_count because the Strikecarrier's contribution is 2 +
live_fw_count", which read literally would put the Fighter-Wing buff on
the *Strikecarrier's own* ceiling. That contradicts both the real printed
Strikecarrier card ("If not destroyed: 2 damage to target, **plus any
Wolf Fighter Wings that have not been destroyed do +1 damage**" - the
bonus is to *other* ships) and this project's own already-tested
`WolfAttack.compute_damage_tally()`, which adds the bonus to each
surviving Fighter Wing's own damage, never to the Strikecarrier's - and
the spec's very next paragraph ("Get the double-count right") agrees
with that reading. Followed the verified primary sources: a
Strikecarrier's own ceiling is always flat 2; a Fighter Wing's own
ceiling rises by `STRIKECARRIER_FIGHTER_BONUS` per live Strikecarrier
*anywhere in the attack* (matching `compute_damage_tally()`'s attack-wide
scope, not per-lane). Verified end-to-end against the real running
scene: two Fighter Wings alongside one live Strikecarrier correctly show
survives-cell `2` (not the static base `1`), and the Strikecarrier's own
survives cell stayed flat `2` regardless.

**A design gap the spec left unaddressed, filled with a documented
judgment call**: what does an *already-destroyed* wolf's ladder show
during a *later* live phase (not just at final Resolution, which the
spec does cover)? Extended the "resolve" treatment (realised cell in
CYAN, rest ghosted) to apply the moment any wolf is destroyed, regardless
of which phase is current now - a Cruiser killed at Medium keeps showing
its Medium cell highlighted through Short, rather than reverting to a
plain live-view once the attack moves on. `WolfLaneLayout.CellState`
(`PASSED`/`CURRENT`/`FUTURE`/`REALISED`/`GHOSTED`/`SURVIVES_LIVE`/
`SURVIVES_GHOSTED`) encodes this as one pure, fully-tested state machine
(`tests/ui/wolf_lane_layout_test.gd`'s `ladder_cell_states` tests).

**Real bug caught by the driving script - the exact same class of bug as
last time, in a new place**: `_ladder_row_height()`'s guessed
boxed-cell-border overhead (a StyleBoxFlat 1px border + 2px content
margin, estimated at a flat 4px) was 1px short of what the real
`PanelContainer` actually needed, so every full-form token's ladder row
overflowed its slot by exactly 1px the moment any cell got boxed (i.e.
every range phase, never during targeting - explaining why the earlier,
narrower structural check hadn't caught it). Found this time by a driving
script purpose-built to catch it: it walks each token's real Control
tree and compares `get_combined_minimum_size()` against the actual
assigned slot size, rather than only counting tokens/lanes like the
first driving script did. Fixed with a more generous empirically-verified
margin constant rather than a live-measured sample node (the earlier
fix's approach) - detached-Control minimum-size reliability off-tree
felt like an unnecessary risk for a 1px cosmetic budget, where a few
extra px of headroom costs nothing but a marginally shorter icon.

**Verified three ways**: `tests/core/wolf_damage_test.gd` (5 tests) and
the new additions to `tests/ui/wolf_lane_layout_test.gd` (39 test
functions in that file now, up from the v3 rebuild's smaller baseline)
cover every pure derivation directly. A geometry-focused driving script
(deliberately not committed,
same "throwaway diagnostic" pattern as before) walked the real Control
tree across every tier (1/2/3/6/10/18 wolves) and all four STANDING
phases plus a mid-attack kill, asserting no token's real measured content
exceeds its assigned slot - this is what caught the 1px bug above. A
second content-focused driving script dumped every rendered Label's text
and colour for a 5-wolf mixed roster (Strikecarrier + 2 Fighter Wings +
Assault Transport + Battlestation) at Medium range and hand-verified
every number against the real card values: Battlestation `3·3·—·3`ᶜʸᵃⁿᵃᵗᵐᵉᵈ,
Strikecarrier `2·2·2·2` plus a live `+2` badge (2 live Fighter Wings),
Assault Transport `0·0·0·0` plus a `4BP` chip, both Fighter Wings showing
a *boosted* survives cell (`2`, not the static base `1`, confirming the
live-Strikecarrier bonus reached the right row), and the lane's own `▼9`
ceiling matching a hand sum of all five ships' survives values exactly.
39 test files total, all still green.

**A fourth real bug, again from a screenshot** (`docs/wolf_attack_v4.png`,
taken against the just-shipped ladder above): full-form tokens rendered
with a tiny, dead-centred icon, and the `4BP`/`⊘S` badges appeared to
render on top of the code/pips text instead of beside it ("Troop
carriers have 4bp under them", "Battlestation has grey 2 letter under BS
initials"). One root cause explained all three symptoms:
`_build_full_token()` gave `WolfCodePips` `custom_minimum_size =
Vector2(0, code_row_height)` - zero WIDTH, no expand flag - inside its
`code_row` `HBoxContainer`, so it collapsed to nothing and every badge
appended after it drew stacked on the same spot as the code text instead
of laid out beside it. The tiny/centred icon was a separate, genuine
design request (not a bug) - the old layout stacked icon-on-top-of-text,
so the icon only ever got whatever vertical sliver was left after two
text rows, and sat centred over mostly-empty lane width the text never
used.

Fixed both at once by redesigning `_build_full_token()` from a vertical
stack to icon-left/text-right: a large `ShipIcon` sized off the full
token height sits on the left, with code/pips + badges + the ladder row
stacked in a column to its right - `code_pips.size_flags_horizontal =
SIZE_EXPAND_FILL` now, matching what the compact-form token already did
correctly the whole time. This also deleted `_ladder_row_height()`
(no longer needed - the icon no longer shares vertical space with the
text column, so there's nothing left to subtract measured row heights
from).

Verified with a throwaway driving script (same
`get_combined_minimum_size()`-vs-assigned-slot pattern as the two
earlier overflow bugs, extended to also check for horizontal overlap
between successive `code_row` children) across every wolf class and
badge combination - Assault Transport's `4BP`, Battlestation's `⊘S`,
Strikecarrier's `+N`, plus a destroyed Tier A2 token - at both Tier A
(118px, headed) and Tier A2 (100px, headerless): all six fit their slot
with zero overlap. Full test suite still green (39 files).

The `4BP` badge itself stays - it's an explicit spec-mandated rules-fact
badge (§3.3), and mirrors v3's own established precedent of showing "N
BP" in two places on purpose (per-token badge and the lane's aggregate
incoming-line chip) rather than one - not an oversight to remove.

**A fifth real bug, same feature, one more round of user testing**: the
user asked what `⊘S` (Battlestation's "cannot be damaged at Short"
badge) was for, whether it was needed, and reported it now overlapping
the `↻` returns glyph drawn inside `WolfCodePips` itself. Root cause was
one level deeper than the fourth bug's fix reached:
`WolfCodePips._draw()` draws unclipped, starting from local x=0,
regardless of whatever rect a parent container actually gives it - and
`WolfCodePips` had no `_get_minimum_size()` override, so no container in
the chain had any idea how wide its real content (code text + one arc
per pip + the trailing `↻` glyph) actually was. For a Battlestation
(capacity 6, the widest hull) the container guessed a narrower width
than the ~180px the content actually needed, so the tail end - the last
pips and the `↻` glyph - drew straight through the `⊘S` badge sitting to
its right. Fixed at the source with a real `_get_minimum_size()`
override on `WolfCodePips` (pure font-metric math, no tree dependency,
so it's reliable even before the node is added anywhere) - containers
now reserve the actual pixel width this control draws into, for any
code/capacity/returns-icon combination.

That fix alone surfaced a second, smaller problem: once the container
correctly accounted for a full-capacity Battlestation's real content
width (~180px) plus the `⊘S` badge (~29px more), the two together
*still* didn't fit next to the now-large icon within one 273px-wide Tier
A lane (icon 94px + separation + 209px of text > 273px available) - the
badge wasn't overlapping anymore, it was being clipped off-canvas
entirely by the token's own `clip_contents` holder, just as invisible as
before but for a different reason. Given `⊘S` was already documented as
redundant the moment it was added ("redundant with the ladder's own
Short cell already showing `—`" - true for every tier, not just Tier A),
and the user was independently asking whether it was needed at all, the
call was to drop it from the render rather than fight for the last few
pixels: `_append_badges()` no longer emits it.
`WolfLaneLayout.badge_cannot_be_damaged_at_short()` itself stays, still
covered by its own unit test - just unused by this caller now.

That still left a smaller, ~1px-scale overflow for a full-capacity
Battlestation with no badge at all (icon 94px + separation + 180px of
text ≈ 282px against a 273px lane) - the same class of bug as the
fourth fix's "guessed 0.8 height fraction had no relationship to how
much width the text actually needed," just a narrower margin. Fixed
properly this time rather than picking a smaller guessed constant:
`_build_full_token()` now builds the text column FIRST, measures what it
actually needs via `get_combined_minimum_size()` (both `WolfCodePips`
and the ladder row's minimum-size logic are pure font metrics, reliable
to query even off-tree, before either is added to any parent), and only
then sizes the icon with whatever lane width is left over - capped at
the old 0.8-of-height ceiling so small-content hulls (Fighter Wing,
Destroyer) still get a large icon, floored at 0.4 so a future
high-capacity hull can't shrink it to nothing, with a small fixed 2px
safety margin absorbing Godot's own sub-pixel container-rounding rather
than chasing it exactly. `_build_wolf_token()`/`_build_full_token()`
both gained a `lane_width` parameter to make this possible.

Verified with a driving script covering the actual worst case in the
game (Battlestation, capacity 6, undamaged, with its `↻` returns icon -
the widest content this screen ever draws) alongside Assault Transport
(`4BP`), Strikecarrier (`+N`), Fighter Wing, and Cruiser, at Tier A:
every case's real measured row width now fits its lane, with zero
overlap between `code_row`'s children. Full test suite still green (39
files).

**Deliberately not built, scope boundary carried over honestly, not
silently expanded**: this pass only touches the four STANDING phases
(`targeting`/`range_long`/`range_medium`/`range_short`) that already
render lanes. The spec's own §6 phase table also describes `boarding`
(ladder dims to alpha 0.4, `4BP` badges come forward) and `resolve`
(realised cell in CYAN, rest ghosted) behavior for the *lane* view - but
in this codebase, `"boarding"` and `"resolution"` have never rendered
lanes at all, using the separate `_boarding_panel`/`_resolution_panel`
simple-list views inherited from v2 (a **pre-existing v3-scope gap**,
not something this ladder pass introduced or was asked to fix - the v3
lane spec's own §6.4 describes lane behavior at `resolve` that was never
wired up either). The ladder's "realised cell" logic
(`CellState.REALISED`) is fully built and already correct for a wolf
destroyed mid-attack within the four STANDING phases; extending
`boarding`/`resolution` to render lanes at all remains separate,
undone work. Also still open: token pooling/tweening (unchanged from
v3), and Small Ship footer badges (Gorgoneion/Vulcan still aren't
`core/` objects - unrelated to the ladder specifically).

New handoff folder `ui/design_handoff_damage_ladder/` - **read
`spec/wolf_attack_damage_ladder.md` directly before starting**, it's the
authoritative addendum spec (same authority relationship as the lanes
handoff: `README.md` is a denser restatement with a few extra visual
details, `Wolf Attack Damage Ladder.dc.html` + `support.js` is browser-
openable reference pseudocode, not production code to port). It's an
*addendum* to `wolf_attack_tv_display_v3_lanes.md` (a copy sits alongside
it in `spec/` for convenience) - tokens, tiers, lanes, palette and
typography are otherwise unchanged from the v3 build just landed above.
Two duplicate files the extraction left in `docs/` (`Wolf ships
silhouette design.zip`, byte-identical to the handoff folder, and a
stray copy of the spec `.md`) were deleted as pure clutter - the handoff
folder itself is the one copy that matters.

**The problem being fixed**: `PREVENTS N` (the current red ability line
on every wolf token, built by `WolfLaneLayout.ability_label_full()`/
`ability_abbrev()`) is phase-derived, so the same number means different
things depending which range phase is active - a Cruiser's `PREVENTS 1`
at Short (already spent most of its value) and a Destroyer's `PREVENTS 1`
at any range (worth exactly that every phase) render identically despite
demanding opposite host decisions. The fix replaces that single scalar
with a **four-cell ladder** - Long/Medium/Short/Survives - so the shape
of the sequence (rising, flat, or dead-end) carries the tactic without
any legend:

```
CR   0 · 1 · 2 · 3      rising   → kill it now, value is bleeding
DE   1 · 1 · 1 · 2      flat     → no rush, worth the same later
BS   3 · 3 · — · 3      dead-end → killing it never helps the total
FW   0 · 0 · 1 · 1      rising   → free to kill early, pointless at Short
```

**New pure module needed**: `res://core/wolf_damage.gd` (spec §8) - a
`LADDER` const table (per-hull `[long, medium, short, survives]` cells,
`null` for Battlestation's un-damageable Short cell) plus
`damage_if_destroyed_now(hull, phase)`, `damage_if_survives(hull,
live_fw_count)`, `lane_floor(wolves, phase)`, `lane_ceiling(wolves,
live_fw_count)`. **The double-count trap the spec calls out by name**:
the Strikecarrier's live-fighter-wing buff (`+1` per surviving Wolf FW)
belongs on the **FW** rows' own ceiling, not added a second time to the
`SC` row's ceiling - `SC`'s badge just *displays* the current count for
legibility. This table substantially overlaps
`core/combat/wolf_ship_definitions.gd`'s existing `DAMAGE_IF_DESTROYED_AT`/
`DAMAGE_IF_SURVIVES`/`STRIKECARRIER_FIGHTER_BONUS` constants (already
verified against the real printed cards earlier this session) - worth
building `wolf_damage.gd` as a thin re-derivation from those rather than
a second hand-typed copy of the same six numbers, so there's one source
of truth instead of two that could drift.

**Badges replace the named-ability text**: `↻` (BS/FW returns), `4BP`
(AT, `ALERT_DEEP` filled chip, pulses at Boarding - matching the lane
incoming line's existing BP chip), `+N` (SC, live count of undestroyed
Wolf FW across the whole battle - not a constant, must recompute on
every push same as everything else on this screen), `⊘S` (BS, "cannot
be damaged at Short" - redundant with the Short cell already showing
`—`, spec says show only at Tier A).

**Lane incoming line becomes a range, not a projection**: `▼ ceiling`
number plus a bar (`floor` = solid `ALERT`, remainder up to `ceiling` =
outlined `ALERT` @ 0.35) - "is this lane already committed, or still
worth shooting at" is exactly the arithmetic-not-judgment split this
project already draws everywhere else on this screen (v3's own
`incoming_damage_for_lane()` becomes `lane_ceiling`; a new
`lane_floor()` sits next to it in `wolf_lane_layout.gd`, both backed by
the new `core/wolf_damage.gd`).

**[x] Tier A/B boundary - decided, go with the README's deviation, not
the spec's literal §4.** spec §4 says the Tier A/B boundary itself moves
to `max_stack ≤ 2` (tokens grow 100→118px to fit `L M S ✕` headers, so 3
no longer fits in the 332px stack zone: `3×118+2×10=374 > 332`). The
README overrides this in its own "Deviation from the spec" note: keep
Tier A's boundary at `≤3` (unchanged from v3, and matching
`WolfLaneLayout.TIERS`'s current `{"min":1,"max":3}` already built), drop
the `118px`/headers only at exactly 2-or-fewer, and render 3-stacked
lanes as 100px tokens with a headerless 4-cell ladder replacing the
ability line in the same space the single line used to occupy - reasoning
given: "so the common board still looks like the live game" (~3 per lane
is the typical case, and the spec's own boundary would make the *common*
case visually shrink every time). **User confirmed this call directly**
(not inferred) - build `WolfLaneLayout.TIERS`/`stack_zone_geometry()`
against the README's version: `{"min":1,"max":2}` for the headed 118px
form, `{"min":3,"max":3}` (or folded into the existing B range's logic,
implementer's call) for the headerless 100px form, `{"min":4,"max":8}`
tier B unchanged onward.

**Open item §10 ("verify before building, do not guess") is already
answered by this project's own existing code**, not something to go
re-check against source material: the spec asks whether wolf damage
lands all at once at Resolve, or phase-by-phase as each ship dies. The
`WolfAttack` state machine already implements the second reading -
`compute_damage_already_dealt()` sums *dying blows* from ships
destroyed during a completed range phase (locked in via
`ship.destroyed_at_phase`), used live for the fleet card's mid-attack
"damage this attack" readout; `compute_damage_tally()` adds full
survivor damage only once ships are confirmed to have lived to
Resolution. Fleet card damage numbers already tick up phase by phase
today, not lump-summed at the end - the ladder redesign can build on
this as settled fact rather than re-litigating it.

**Deliberate design constraint carried over from the spec's own §7**,
worth restating since it's exactly `CLAUDE.md`'s "a change that makes
the software cleverer but the room quieter is a regression" rule applied
to this specific screen: rules facts (`—`, `↻`, `4BP`) and derived
arithmetic (floor, ceiling, live FW count) are fair game; verdict labels,
urgency ranking, recommended-target highlighting, or sorting tokens by
"how much you should care" are explicitly not - target priority is
meant to be an argument the players have with each other, not something
the screen resolves for them. Token order stays the existing v3 rule
(descending hull capacity, stable by `uid`) - a fixed, explicable rule,
not a live recommendation.

**Acceptance checklist** (spec §9): a Cruiser at Long shows `0·1·2·3`
with the first cell boxed; the same Cruiser at Short shows `0·1·2·3`
with the third cell boxed and the first two greyed; a Battlestation
shows `—` in the Short cell, never a number; a Fighter Wing at Medium
visibly shows killing it now costs 1 vs. 0 at Short; a Strikecarrier's
`+N` badge decreases live as Wolf FW die, no state push beyond the
roster; a lane of three Destroyers reads mostly-solid-bar, a lane of
three Cruisers at Long reads mostly-outlined; Tier A capacity is 2 per
lane after the height increase (pending the boundary-vs-README decision
above); at Tier C the ladder collapses to e.g. `1▸3` and still reads
correctly when both values are equal; at `resolve` each token shows
which cell actually landed; no token anywhere carries a verdict,
ranking, or recommendation.

**What this reuses from the just-landed v3 work, unchanged**: lane
grouping/ordering/tier-selection scaffolding in `wolf_lane_layout.gd`,
`WolfCodePips` (pips rendering stays identical), `ShipIcon` (same
silhouettes), the destroyed-token whole-alpha+strikethrough treatment,
and the content-aware sizing fix from this session's overlap bug (the
ladder's cell row will need the same "measure the real font metric,
don't guess a fixed height" treatment `_build_full_token()` now uses,
given it's replacing the exact row that bug came from).

## Mostly done — Star Map TV display (core/map/, TV screen, and admin console built)

Two docs landed for this: `docs/star_map_tv_display.md` (the full spec -
purpose, hard constraints, layout, rendering layers, data contract, host
controls, Godot file structure, open questions) and `docs/star_charts.json`
(companion topology/letter/system data, written to ship as
`res://data/star_charts.json`). Read the spec directly before starting -
this entry is a pointer plus a reconciliation check against existing code,
not a substitute.

The full headless `core/map/` layer is built and tested (see below) -
`fleet_positions.gd`, `path_tree.gd`, `star_map_projection.gd`,
`reveal_state.gd`, plus the split-fleet pursuit model and the two
blockers under "Blockers" further down. The TV screen itself
(`ui/tv/star_map/`) is built too, structural pass, reachable via one
`HostConsole` button plus the §8 auto-show timing below. The admin
console is built as well, as a new `HostConsole` section rather than the
spec's proposed standalone `ui/admin/StarMapAdmin.tscn` - see that
entry's own note on why. What's left is genuinely minor: scout-range/
jump-range overlays (need state nothing tracks yet), visual polish, and
`res://data/star_charts.json` as an actual runtime data file (still just
living as reference docs).

**§8 show/hide timing - built, with one piece deliberately left open.**
`ui/main.gd` now starts (and restarts, so back-to-back jumps don't let
the map drop between them) a 45s one-shot `Timer` on every
`FleetPositions.changed`, forcing `StarMapScreen` visible for that
window regardless of the manual toggle - covers §8's "Automatically for
45s after every jump resolution." This codebase has no separate "jump
resolution" event to hook (`JumpResolver` isn't wired into any UI at
all, still true per the note further down this file) - `FleetPositions.
changed` is the closest real signal, since recording a unit's actual
arrival via the admin console's Move control *is* how a jump gets
recorded here. Wolf Attack still wins over everything, including an
open auto-show window (verified: starting an attack mid-window hides the
map, ending the attack while the window would still be open brings it
straight back, matching "the attack screen has absolute priority").
§8's "on demand during the Coordination Phase" is just the existing
manual toggle - nothing further needed.

**Deliberately not built**: §8's "idle screen between phases, at 60%
brightness" - genuinely skipped, not overlooked. That line only makes
sense if `StarMapScreen` is the TV's *default* idle screen, and in this
app `TVDisplay` already holds that role (fleet status + announcements) -
swapping the default out is a real product decision with a real user
(the host relies on that screen), not something to guess while "just
wiring." Flagging it here rather than picking one silently.

Verified with a throwaway driving script that booted the real `Main`
scene (not just calling `core/` methods): confirmed the default is
`TVDisplay`; a `move_unit()` call flips it to `StarMapScreen` and starts
the timer; stopping the timer (standing in for the real 45s elapsing,
without an automated test actually waiting that long) reverts to
`TVDisplay`; the manual toggle still works independently; starting a
Wolf Attack mid-auto-show-window hides the map in favor of
`WolfAttackDisplay`; ending that attack while the window would still be
open brings the map straight back. Full test suite still green (43
files - no `core/` changes this pass, pure `ui/main.gd` wiring).

### Overlap with existing code — reconcile before building

`core/star_chart.gd` already exists (built during the earlier Star systems
pass) and already covers most of what the spec's proposed
`core/map/star_chart.gd` asks for: the same 22-node/41-edge graph
(verified identical, edge-for-edge, against `docs/star_charts.json`'s
`edges` array), `PURSUIT_BAND` (coordinate → cumulative pursuit reduction,
-1 through -7 by tier depth), and `CHART_ASSIGNMENTS` for all three chart
letter variants. Building a second, separate `core/map/star_chart.gd` per
the spec's file layout would duplicate this - extend the existing file (and
decide whether it physically moves under `core/map/` to match the spec's
layout) rather than writing a new one from scratch.

**[x] A real bug, found by cross-checking `docs/star_charts.json` against
the existing, already-shipped, already symmetry-tested
`core/star_chart.gd`, fixed with the user's confirmation**:
`CHART_ASSIGNMENTS["A"]["1964"]` was `"P"` - it should have been `"M"`.
Chart A's own letter tally in the existing file had two `P`s (`1964` and
`4888`) and only three `M`s, but `docs/star_charts.json`'s
`variant_summary.A` says chart A has exactly 8 wolf systems (4 L + 4 M) and
exactly one each of N/O/P (P at `4888` only) - and every other node's
letter, on every other node across all three charts, matched exactly
between the two sources. Now `1964` reads `M`, matching the JSON's variant
summary precisely. The existing `tests/core/star_chart_test.gd` symmetry
test wouldn't have caught this - it checks graph symmetry, not per-chart
letter-count invariants - so a new `test_chart_letter_tallies_match_
variant_summary` was added alongside it, asserting the full L/M/N/O/P
tally for all three charts against the JSON's numbers, so this class of
bug can't recur silently. Full suite still green (39 files).

### What's needed to build the spec

- [~] Reconcile/extend `core/star_chart.gd` - the letter bug above is
      fixed; still open whether the file physically moves under
      `core/map/` to match the spec's layout. Left where it is for now -
      every new `core/map/` file below just references the global
      `StarChart` class name, which works regardless of which directory
      the script lives in.
- [x] **`core/map/fleet_positions.gd` - built.** Ground truth for all 7
      jump-capable units' chart positions and trail history, mutated
      only through `move_unit()`/`undo_last_move()` (§8's "Move unit"/
      "Undo last move") - never derived from `Ship.jump_coordinates`,
      which stays exactly what it always was (a scout's unvalidated,
      possibly-lying free text), per constraint 1.

      Groups (§4.2) are derived from current shared position every time
      `groups()` is called, not stored as a partition - what persists
      across a split/merge is each group's id/label/representative/
      pursuit. Since every mutator moves exactly one unit per call, a
      single relocation can only ever peel one unit off its old group
      and/or land it on an already-occupied node - never a multi-way
      split and multi-way merge at once - which is what keeps
      `_relocate()` a tractable "reason about the one unit that moved"
      function instead of a full partition-diff from scratch every
      time.

      **Split-fleet pursuit resolved as part of this, not separately**
      (folding the item below into this one - building `fleet_positions.gd`
      *is* the split-fleet pursuit model, they turned out to be the same
      piece of work): a group's pursuit isn't a sticky "has this ever
      diverged" flag - it's just "is this currently the only group."
      `sync_global_pursuit(value)` (wired to `GameState.pursuit_track.
      changed` in `core/game_state.gd`) only writes when exactly one
      group exists; the moment a split makes that untrue, the resulting
      groups are independently host-managed via `set_group_pursuit()`/
      `reconcile_group_pursuit()` from then on; the moment everything
      merges back into one group, that single group starts tracking the
      legacy `GameState.pursuit_track` again automatically, with no
      special "resume tracking" call needed anywhere. (First draft used
      a sticky per-group boolean instead - caught as wrong by a test
      that moves all 7 units to the same node one call at a time, the
      way jumps are actually reported in real play: each individual
      `move_unit()` call transiently splits and re-merges the fleet, so
      a sticky flag would have permanently and silently stopped tracking
      global pursuit after the *first* turn any two ships were reported
      separately - see `test_fleet_relocating_one_unit_at_a_time_ends_
      as_one_group_tracking_global_again` in
      `tests/core/map/fleet_positions_test.gd`.)

      Merge pursuit reconciliation matches §4.2/§8's "do not
      auto-resolve": the absorbed group's pursuit is stashed on
      `pending_merge_pursuits`, never averaged or discarded, until a host
      calls `reconcile_group_pursuit()`. Representative selection follows
      §4.1 exactly (AEGIS's group is always represented by AEGIS, no
      exception - `set_group_representative()` refuses to reassign it
      away; AEGIS's own departure from a group takes that group's
      identity with it; a non-AEGIS group picks a representative via the
      selection order and holds it for the group's life). `to_dict()`/
      `load_from_dict()` follow the existing `Ship`/`StarSystem` pattern;
      wired into `GameState.to_dict()`/`from_dict()` for crash recovery.
      **Not yet in `to_public_dict()`** - the raw positions/trails aren't
      actually secret (they're exactly what's printed on the blank paper
      chart per §3), but nothing consumes them over the network yet, and
      the leak-safe way to expose star map data is through
      `StarMapProjection.build()` (below), not this raw dict - same
      "wait for the thing that actually redacts it" reasoning as
      `star_systems`'s existing exclusion.

      16 tests in `tests/core/map/fleet_positions_test.gd`, all passing.
- [x] **`core/map/path_tree.gd` - built.** Deduplicates every unit's
      trail into the tree of *distinct* routes (§6.3): each tree edge is
      drawn once no matter how many units' trails pass through it,
      branches split only at a real fork, and a branch is "live" if any
      unit's *current* position still descends from it, "dead"
      otherwise. Static and stateless - takes plain trails +
      unit→group_id + which group is AEGIS's, doesn't touch
      `FleetPositions`/`GameState` directly, so it's independently
      testable against synthetic data.

      **Known, documented simplification**: a single unit backtracking
      over its own trail (revisiting an already-placed node) reuses the
      existing tree edge and just stops being "live" once that unit's
      current position no longer descends from it, rather than getting a
      second reverse copy of the same edge. This produces the same
      dead/live result the spec's own worked example wants (an abandoned
      detour renders as a dead stub) without needing to special-case
      round-trips - verified directly by
      `test_merge_produces_convergence_and_one_dead_abandoned_branch` in
      `tests/core/map/path_tree_test.gd`, which reproduces that exact
      scenario (one unit detours off the shared route and rejoins) and
      checks the dead branch is emitted exactly once. 4 tests total,
      covering the three cases §9 names by name (identical trails →one
      branch; a divergent trail → fork sharing the prefix exactly once;
      merge → convergence + one dead branch) plus a trivial root-only
      case.
- [x] **`core/map/star_map_projection.gd` - built, with the leak tests
      written first.** The C2 boundary: `build()` strips every unvisited
      node's `letter`/`name`/`class`/`consequence` at the source, keyed
      off `FleetPositions` trails/positions directly (`is_visited`/
      `is_occupied`), never off the display `state` string - so a host
      "force state" override (§8, constraint 5) can change what's
      *displayed* without ever becoming a path to leaking real content
      for a node the fleet hasn't actually reached. Covered directly by
      `test_forced_state_cannot_be_used_to_leak_a_letter` in
      `tests/core/map/star_map_projection_test.gd`, alongside the leak
      tests §9 asks for by name (only visited/occupied nodes carry
      `letter`; the serialized JSON never contains an unvisited system's
      name anywhere in the string; a claim on a node whose true letter is
      `M` round-trips its text unchanged without ever attaching `class`).
      8 tests total, all passing.

      `class`/`consequence` per node are *derived* from
      `StarSystemDefinition`'s existing flags (`is_new_eden_candidate`,
      `triggers_wolf_attack_on_arrival`, `rating`, etc.), not a second
      hand-typed table that could drift from `docs/star_charts.json`'s
      `systems[letter].class` values - cross-checked by hand against all
      13 card-based letters when this was written.

      **Deliberately scoped down from the full §7 schema** - `scout_rings`,
      `jump_ranges`, and `highlight` are left out. Each needs host-toggled
      overlay state (which scout ring is on, which group has jump-range
      shown, a set destination) that doesn't exist anywhere in `core/`
      yet - natural follow-up once the admin console (below) exists to
      actually set that state, not something to stub out blind.
      `orientation`/`show_bands` (display prefs, not game state) are also
      omitted for the same "nothing sets this yet" reason.

      New `core/ship_colors.gd` - `docs/ship_colors.md` had a ready-to-use
      `ShipColors` constants block written but never actually created as
      a file; created now (verbatim from that doc) since
      `_build_group()`'s representative colour needed a source, and the
      doc's own note says this is safe to live in `core/` (pure colour
      lookup, no Node dependency). `ui/tv/wolf_attack_tokens.gd` still
      keeps its own separate copy of the same six values - reconciling
      that duplicate is a separate, not-yet-done cleanup, noted in both
      files.
- [x] **`core/map/reveal_state.gd` - built.** Claims (host-published
      scout reports, §6.4's chips - verbatim text, never parsed or
      matched against `StarChart`, contradicting claims both kept rather
      than resolved) and `forced_states` (§8's "Force state" escape
      hatch, constraint 5). Deliberately does *not* store a "visited" set
      - visited-ness is fully derivable from `FleetPositions` trails, so
      storing it separately would just be a second place it could drift
      from the truth. 6 tests in `tests/core/map/reveal_state_test.gd`.

      Wired into `GameState` (`reveal_state` field, `to_dict()`/
      `from_dict()`, `changed` bubbling to `mutated`) alongside
      `fleet_positions` above; **not yet in `to_public_dict()`**, same
      reasoning as `fleet_positions`.

      All 4 new modules total 34 new tests; full suite is 43 test files,
      all passing (was 39 before this pass). One non-obvious step
      needed along the way and worth remembering for next time: adding
      new `class_name` scripts under a brand-new subdirectory
      (`core/map/`) isn't picked up by `godot --headless --script` on
      its own - it uses the existing `.godot/global_script_class_cache.cfg`,
      which only gets rebuilt by actually opening the project. Fixed by
      running `godot --headless --editor --quit` once before the test
      run; every SCRIPT ERROR the first attempt threw ("Identifier
      'FleetPositions' not declared", `MessageRouter.new()` on unrelated
      tests failing with "Nonexistent function 'new' in base 'GDScript'")
      was this cache being stale, not a real bug in any new file - worth
      trying this rebuild step first if a future session sees the same
      symptom before assuming the new code is broken.

      Verified two more ways beyond the test suite: booted the real
      `Main` scene headlessly (`godot --headless res://ui/main.tscn`) and
      confirmed it starts and keeps running with no script errors now
      that `GameState` constructs `FleetPositions`/`RevealState` in
      `_init()`; and manually traced `_relocate()`/`_merge_groups()`
      against several split/merge/AEGIS-departs/two-non-AEGIS-groups-merge
      scenarios by hand before writing each test, rather than writing
      tests only after the code already passed them.

- [x] **`ui/tv/star_map/` - built, structural pass.** `StarMapScreen.tscn/
      .gd` + `StarMapCanvas.gd` (one `_draw()`-based Control doing bands/
      edges/trails/nodes/group tokens/claim chips, matching this
      project's established Wolf Attack screen pattern of small
      draw-only helper Controls - `PursuitMeter`, `ImpactArc`,
      `LaneSpines`), consuming `StarMapProjection.build()`'s dict only.
      Read-only like `TVDisplay`/`WolfAttackDisplay` - never mutates
      `core/` state, rebuilds freely on every `GameState.mutated` since
      there's no editable input here to interrupt.

      Same structural-pass scoping already applied to the Wolf Attack
      screen's v1 build (see that section's own note above, and this
      file's header comment): correct data/geometry using plain drawing
      primitives, not the spec's pixel-exact node radii, draw-in
      animation, dashed-chip styling, or slow occupied-node pulse -
      those need a human looking at a live window to judge, which this
      environment can't do. Not split into the spec's more granular
      `StarNode.tscn`/`TrailLayer.gd`/`GroupCard.tscn`/`ClaimChip.tscn`
      file breakdown - one canvas draws nodes/trails together (band
      boundaries and trail liveness both key off the same per-node data
      already in hand) and group cards are built as plain `VBoxContainer`
      rows in `star_map_screen.gd`, same relationship `TVDisplay`'s
      fleet-status rows already have to their `.gd` file.

      **New `core/star_chart.gd` data**: `NODE_POSITION` (per-coordinate
      u/v screen-layout position, sourced from `docs/star_charts.json`'s
      pixel-analysis node table) and `node_position()` - genuinely
      missing before this; nothing anywhere had screen positions for the
      22 nodes. 2 new tests in `tests/core/star_chart_test.gd`.

      **New `GameState.chart_in_play`** (`"A"`/`"B"`/`"C"`, defaults
      `"A"`, persisted): the screen needs to know which chart variant is
      in play to resolve letters at all, and nothing tracked this
      before. `set_chart_in_play()` exists as the setter; no admin
      control calls it yet (see `ui/admin/StarMapAdmin` below) - it just
      sits at the default until that's built.

      **Bands/trails are derived, not hardcoded**, per spec §6.1's own
      instruction: tier boundaries come from `StarChart.
      pursuit_reduction_at()` grouped by each tier's actual node
      x-positions, not fixed pixel values; a branch renders as a straight
      line when its endpoints are a real `StarChart` graph edge, and as a
      dashed bowed quadratic arc (manually interpolated, not
      `Vector2.bezier_interpolate` - avoided an unverified API surface
      given this project's history of exactly that kind of Godot-API
      assumption breaking a build, see the Wolf Attack v3 section above)
      when they aren't - a multi-hop jump or host correction stays
      visually distinct from a normal one-hop trail, per §6.3.

      **Reachable end to end, not just instantiated**: `HostConsole`
      gained one new button ("Show Star Map (TV)", `star_map_toggle_
      pressed` signal) - deliberately the *minimum* reachable trigger,
      not the full `ui/admin/StarMapAdmin` this file's next item still
      asks for. `ui/main.gd` now instantiates and wires `StarMapScreen`
      as a third TV-window child alongside `TVDisplay`/
      `WolfAttackDisplay`, extending the existing visibility-swap
      pattern to three screens: `WolfAttackDisplay` still has absolute
      priority the instant an attack starts (constraint 3 / spec §8's
      "never during a Wolf Attack"); otherwise the toggle picks
      `TVDisplay` or `StarMapScreen`. The richer §8 show/hide policy
      (auto-show for 45s after a jump, idle at 60% brightness) was built
      in a follow-up pass - see the "§8 show/hide timing" writeup near
      the top of this section.

      Verified against the real running app three ways: a throwaway
      driving script (deliberately not committed, same pattern as every
      other TV-screen verification in this project) instantiated the
      real scene against a fresh fleet, confirmed 22 nodes and 1 group
      card build correctly, moved a unit and confirmed the group card
      list and canvas view both picked up the resulting split (2 groups)
      on the next `GameState.mutated`, published a claim on an unvisited
      node and confirmed it read `"reported"` with no `letter` key
      anywhere in the projection reaching the canvas, and forced a
      `_draw()` redraw pass at every stage to confirm the drawing code
      itself doesn't crash on real data (a real, if minor, timing bug
      was caught this way first - setting `.game_state` in the same
      call as `add_child()` hit `@onready` vars before `_ready()` had
      run; fixed by awaiting a frame first, matching `ui/main.gd`'s own
      already-documented "`add_child()` first" ordering rule). Separately
      booted the real `Main` scene headlessly
      (`godot --headless res://ui/main.tscn`) with all three TV screens
      and the new host-console button wired, confirmed no script errors
      and the process stays running rather than crashing. Full test
      suite still green (43 files - 2 new tests landed in the existing
      `star_chart_test.gd` for `NODE_POSITION`; no new test files, since
      `ui/` scenes aren't unit-tested in this project's suite - same
      reason `HostConsole`'s own panels have no test file either).
- [x] **Admin console - built as a new `HostConsole` section, not a
      separate `ui/admin/StarMapAdmin.tscn`.** Every other admin feature
      in this project (Wolf Attack control, Players, ship/craft panels)
      is already a section inside the single `HostConsole` scene, not
      its own top-level window - the spec's own reasoning for keeping
      this off the TV ("a scene that is explicitly not the TV scene and
      never routed to the second monitor") is satisfied by that just as
      well as a standalone scene would, so a new `StarMapSection` inside
      `host_console.gd`/`.tscn` matches the codebase's actual convention
      instead of introducing a second admin-UI pattern.

      **`core/map/star_map_projection.gd` gained `build_ground_truth()`**
      - a second entrypoint (not a flag on `build()`) that always
      attaches every node's letter/name/class/consequence regardless of
      visited state. Deliberately kept as a separate function rather than
      a parameter: the TV/network path only ever calls `build()`, so
      there's no flag anywhere in that call chain that could accidentally
      get flipped to ground truth - the redacted path is structurally
      unable to reach the unredacted one. `_build_group()` also gained
      `member_ids` (raw unit ids) and `representative.id`, needed for the
      admin console's dropdowns to actually call
      `set_group_representative()` - not secret (capital ship names are
      public), just previously-unneeded plumbing. 2 new tests.

      **Covers every §8 row that has real state to control**: chart in
      play (A/B/C), move unit + undo last move (adjacency not enforced,
      per spec), publish/retract claim, set group label/pursuit/
      representative (locked to AEGIS for AEGIS's group, per §4.1),
      merge-pursuit reconciliation (shows the absorbed value(s), lets the
      host pick the resolved number - "do not auto-resolve"), force node
      state, clear override. Reuses `StarMapCanvas` directly (the same
      TV-screen drawing code, just fed `build_ground_truth()`'s dict
      instead of the redacted one) for a visual ground-truth map inside
      the console, plus letter-annotated coordinate dropdowns built from
      the same ground-truth view.

      **Not built** (§8's remaining two rows): "Toggle scout ring" /
      "Toggle jump range" - both need scout-range/jump-range overlay
      state that doesn't exist anywhere in `core/` yet, the same gap
      `StarMapProjection`'s own header comment already flags for
      `scout_rings`/`jump_ranges`. Nothing here can toggle a state that
      isn't tracked; the earlier "Show Star Map" toggle button already
      covers the show/hide row.

      **Rebuild policy**: the whole section rebuilds unconditionally on
      every `GameState.mutated` (`CONNECT_DEFERRED`, same "a button
      inside the freed subtree triggered the mutation" crash the Wolf
      Attack section already solved this way) rather than the ship/craft
      panels' refresh-on-expand pattern - matches Wolf Attack's own
      precedent for a control surface that's taps/dropdowns/short entries
      rather than a 180-field surface where a background mutation
      mid-edit would be costly.

      Verified with a throwaway driving script against the real
      `HostConsole` scene (not just calling `core/` setters directly):
      selected Icebreaker and a target coordinate in the built Move
      controls and pressed Move, confirmed `FleetPositions.positions`
      and the group count updated and the section rebuilt with the new
      group; published a claim through the built Publish Claim row on
      the coordinate for chart A's true `M`, confirmed it landed in
      `RevealState`; pressed the resulting claim's own Retract button
      and confirmed it cleared; changed the Chart in play dropdown and
      confirmed `GameState.chart_in_play` updated. One real bug caught
      this way and fixed before it shipped: a copy-paste edit had
      dropped `_build_resolution_section()`'s own `return section` line
      (a genuine "not all code paths return a value" parse error) and
      left a stray orphaned `return section` at the very end of the
      file - the driving script wouldn't even load the scene until both
      were fixed. Full test suite still green (43 files).
- [ ] `res://data/star_charts.json` — copy/adapt `docs/star_charts.json`
      into the runtime data path the spec's §9 file layout expects.
      Existing `core/` precedent (`star_chart.gd`, `craft_definitions.gd`,
      `star_system_definitions.gd`) hardcodes data as GDScript constants
      rather than loading JSON at runtime - decide whether this feature
      keeps that pattern (fold the JSON's content into the extended
      `star_chart.gd` instead) or is the first thing in this project to
      actually load a runtime data file, since the spec's file tree
      assumes the latter.
- [ ] `test_split_fleet.gd` from the spec's §9 list specifically (host
      reassigning a representative mid-game, a merge prompt scenario end
      to end) - most of what it would cover is already exercised by
      `fleet_positions_test.gd`'s split/merge/representative tests above;
      revisit once the admin console exists to test the actual host-facing
      flow rather than calling the setters directly.

### Blockers — resolve before implementing trails (spec's own §10, items 1-3)

1. [x] Short/medium/long jump = hop count on the chart - **already
   resolved** per the spec itself (§6.7), and already consistent with
   `core/`'s existing `PURSUIT_BAND` cumulative-per-tier data (see the
   -1..-7 table above).
2. [x] **Does pursuit fall by 1 per jump, or by 1 per tier crossed?
   Confirmed with the user: cumulative per tier** (a jump to a tier-4
   destination falls pursuit by the full -4, matching the printed band
   labels - not a flat -1 regardless of distance). Wired into
   `core/jump.gd`: `JumpResolver.resolve()` no longer takes a
   `moves_away_from_wolves` bool with a hardcoded flat amount - it now
   takes a signed `pursuit_delta` the *caller* supplies. Deliberately
   not derived inside `JumpResolver` from `ship.jump_coordinates` -
   doing that would mean the engine looking up the scout's typed text
   against `StarChart` to compute a magnitude, which is exactly the
   auto-verification constraint 1 forbids (this file's own "Star
   systems" section already flagged this risk before the fix landed).
   The host adjudicates where a ship actually went and calls
   `StarChart.pursuit_reduction_at()` themselves to get the magnitude -
   `test_resolve_falls_pursuit_track_by_the_full_cumulative_tier_
   magnitude` in `tests/core/jump_test.gd` covers exactly this path.
   **Still open**: no UI calls `JumpResolver.resolve()` yet at all (confirmed via
   grep - it's only ever invoked from tests) - the host-adjudication
   control that supplies `pursuit_delta` doesn't exist, whether in the
   admin console being planned above or elsewhere.
3. [x] **Pursuit reconciliation on group merge - built.** Spec's own
   answer was a host prompt (safe default), never auto-resolved -
   `FleetPositions._merge_groups()` stashes the absorbed group's pursuit
   on `pending_merge_pursuits` rather than combining it, and
   `reconcile_group_pursuit()` is what the host calls to pick a number.
   The admin console's Star Map section surfaces this directly (shows
   the pending absorbed value(s), a SpinBox, and a "Reconcile" button per
   group with something pending).

Open question 6 (system E's reward printing "code W1 or W2," which
doesn't match any real system letter) reads as still-open in the spec, but
**is already resolved** elsewhere in this file - see "Done — Star systems"
above: replaced with a reward that reveals the location of the real Wolf
systems L and M instead, confirmed with the user at the time. The spec's
own open questions 4, 5, 7, 8, 9 (scout claims on TV vs. admin-only,
Voyage 33-0's signature colour, the missing -5 band label being a
print-file fix, re-scouting stacking vs. replacing, how long dead branches
persist) are all lower priority per the spec's own framing - "easy to
change either way," worth a look at first playtest rather than deciding
now.

## Backlog — Star Map TV visual redesign (data layer + first rendering pass done)

A full design handoff arrived at `res://ui/design_handoff_star_map/` -
same pattern as the Wolf Attack lane-layout handoff earlier in this file
(a `.md` spec, a browser-openable `.dc.html` reference prototype +
`support.js`, now also real ship-silhouette `.svg` art, all self-
contained under one folder per its own `README.md`). Read
`star_map_tv_visual_implementation.md` first - it's explicitly authoritative
over §5-§6 of the original `docs/star_map_tv_display.md` wherever they
disagree ("derived from a built and measured 1920×1080 reference"), not
the other way around. The handoff's `reference/star_map_tv_display.md`
and `reference/star_charts.json` are byte-identical copies of
`docs/star_map_tv_display.md`/`docs/star_charts.json` (diffed - no new
content there, safe to read either copy).

**This is a redesign of the screen just built, not a fresh feature.**
`reference/before-current-build.png` is a screenshot of the actual
running app from this session's earlier structural pass (recognizable
directly - "MERGE PENDING - HOST MUST RECONCILE", the coordinate/ring
node style, all match `star_map_canvas.gd` exactly). Same "playtest a
structural pass, get a visual gap spec back" cycle the Wolf Attack
screen already went through twice (v2, v3) - see those sections above
for how that work was scoped (structural correctness first, polish only
once a human has actually looked at a live window).

**Playtest complaint that drove this, verbatim** (matches the Wolf
Attack v2 pass's own opening move of quoting the user directly): *"hard
to see where the players are, hard to see where the wolves are, not
sure what the yellow line is and it's hard to see. If the screen is bad
the numbers will not be seen."*

### Two deliberate overrides vs. the original spec - build to these, not §5/§6

1. **Node u/v scale factors are no longer uniform** (§2.1: 1.353 u /
   0.617 v against paper px, not the original 1.153/1.152). The
   original uniform mapping crushed the deepest tiers against the rail
   and wasted ~200px of vertical space. `core/star_chart.gd`'s
   `NODE_POSITION` dict (the u/v values themselves) doesn't change -
   only the screen-space multiplier in `star_map_canvas.gd`'s
   `_screen_pos()` does. New pixel positions for all 22 nodes are given
   directly in §2.1's table - use those, don't re-derive.
2. **Scout-claim text moves off the map entirely, rail-only.** A real
   behavior change from what's currently built:
   `star_map_canvas.gd`'s `_draw_nodes()` currently draws claim text
   directly under the node (`REPORTED · %s: "%s"` - visible in the
   screenshot above, and it's illegible, matching the complaint). The
   new design keeps only a dashed chip on the map reading a **claim
   count** (`2 CLAIMS · CONFLICT` when claims disagree, else
   `N CLAIM(S)`) - verbatim text moves to a new rail block (§6.3),
   already correctly scoped as "never resolves the contradiction, just
   moves where it's readable."

### What's new to build with (not present before this handoff)

- `res://ui/design_handoff_star_map/svg/capital-*.svg` - hand-authored
  silhouettes for all 6 capital ships, for the group token's hull glyph
  (§4.3). No fighter/craft/Voyage 33-0 silhouette - group tokens only
  ever show a *capital ship* silhouette (the representative), consistent
  with `FleetPositions`' own representative-selection rules.
- A single enforced colour table (§3) - `FLEET`/`FLEET_ALT`/`WOLF`/
  `CLAIM`/`HAZARD`/`KNOWN`/`POOR`/`EDEN`/`UNKNOWN` - replacing
  `star_map_canvas.gd`'s current ad hoc `CLASS_TINT` dict. Explicit rule
  worth keeping close during implementation: "amber may never appear on
  a solid stroke, and no other colour may appear on a dashed one except
  the relocation arc" - this is the actual fix for "not sure what the
  yellow line is", not a restyle for its own sake.

### Priority order, per the spec's own framing (§1) - [x] 1, 3, 4, 5 built; 2 partial

1. [x] **One colour, one meaning** (§3) - built. New `ui/tv/star_map/
   star_map_tokens.gd` (matches `wolf_attack_tokens.gd`'s "one table,
   not per-scene literals" pattern) holds the full `FLEET`/`FLEET_ALT`/
   `WOLF`/`CLAIM`/`HAZARD`/`KNOWN`/`POOR`/`EDEN`/`UNKNOWN` table exactly
   as specced; `star_map_canvas.gd`'s old ad hoc `CLASS_TINT` dict is
   gone. Group tokens/cards/trails all now read `FLEET`
   (AEGIS)/`FLEET_ALT` (everyone else) instead of each ship's own
   accent hex - the deliberate "no colour does two jobs" trade the spec
   asks for, dropping per-ship identity colour from this screen
   entirely (still lives in `docs/ship_colors.md`/`core/ship_colors.gd`
   for whatever else wants it).
2. [~] **Fleet-as-beacon** (§4.2/§4.3) - partially built. Landed: corner
   brackets on the occupied node (in the occupying group's `FLEET`/
   `FLEET_ALT` accent), a soft radial glow approximated with concentric
   fading circles (no shader - see `_draw_soft_glow()`'s own comment),
   and the group token now shows the representative's actual hull
   silhouette (reusing `ShipIcon._TEXTURES` directly -
   `res://ui/design_handoff_star_map/svg/capital-*.svg` is byte-
   identical to the Wolf Attack screen's existing copy, confirmed by
   diff, so no new preload list was needed) tinted dark ink, plus the
   AEGIS white outline. **Not built**: the animated pulse ring itself
   (drawn as a static ring at rest scale instead - same "structural now,
   Tween later" call already made for the Wolf Attack screen's v1 pass),
   the token's index disc (rail-linkage badge - moot until the rail
   redesign below happens), and the "damaged member" bottom-edge/`DMG`
   tag (needs a definition of "ship damaged" this project hasn't settled
   - a ship has per-console damage, not a single damaged flag).
3. [x] **Wolves are loud** (§4 node styling + glow layer) - built for the
   *map* half. Wolf nodes get the 5px `WOLF` ring + tinted fill + the
   radial glow. **The rail's Wolf Presence block (§6.2) is not built** -
   see "Also needed" below, folded into the rail-redesign deferral.
4. [x] **Numbers survive a bad panel** - built. Two node sizes
   (76px/84px), coordinate drawn inside the circle for `unknown`/
   `reported` nodes, moved into the info chip below (or above, for
   `0000` only, per §4.1's explicit exception) once a node is
   `visited`/`occupied`. Nothing under 18px.
5. [x] **Permanent legend bar** (§7) - built, all 8 items with a real
   swatch per item (ring/dashed ring/line/dotted/dashed arc), not just
   text.

**Second deliberate override, actually implemented this pass (the
README's first override, non-uniform node scale factors, already
landed earlier - see `core/star_chart.gd`'s history)**: scout-claim text
moved off the map entirely. `star_map_canvas.gd`'s info chip now shows
only a claim *count* (`2 CLAIMS · CONFLICT` when claims disagree, else
`N CLAIM(S)`/`1 CLAIM`), dashed, in `CLAIM`. Verbatim claim text moved to
a new **Scout Reports rail block** in `star_map_screen.gd`
(`_rebuild_scout_reports()`) - newest first, stacked, never resolving a
contradiction, scanning `view["nodes"]` for a `"claims"` key (the same
leak-safe object the map itself reads, not a second path to the raw
`RevealState`). This was necessary, not optional, to land in the same
pass as the map-side change: removing claim text from the map without
somewhere else to read it would have made claims silently unreadable,
not just less prominent - a real regression, not a partial improvement.

**Bug fixed in passing, found by tracing the old code rather than by a
test**: dead (abandoned) branches that happened to run along a real
graph edge were drawn as a **solid** grey line, not dashed - the
original `_draw_trails()` only branched on `is_dead` for colour/width,
not for the solid-vs-dashed choice, which was keyed on adjacency alone.
Per §5, a dead branch should read as "still history, no longer
competing" regardless of whether the specific segment happens to be a
direct edge - now always dotted (`_draw_dashed_line()` for the adjacent
case, `_draw_dashed_arc()` for non-adjacent), matching live branches'
solid-if-adjacent/dashed-arc-if-not split only when the branch is
actually live.

**`ui/host/host_console.gd`'s admin ground-truth map picked up the same
redesign for free** - it instantiates the same `StarMapCanvas` class the
TV screen uses, just fed `build_ground_truth()`'s dict instead of the
redacted one, so there's one rendering implementation, not two to keep
in sync.

Verified with a throwaway driving script exercising every new code path
at once against the real scene tree (not just checking it doesn't throw
on a fresh fleet): a wolf-system visit (glow + ring), a 3-way fleet
split, two contradicting claims on one node plus a third claim
elsewhere, a non-adjacent relocation (dashed arc + "JUMP FAILURE"
label), the idle veil toggling, and the admin console's reused canvas -
all redrawn without error. Full test suite still green (44 files, no
`core/` changes this pass beyond what the projection-additions commit
already covered).

### Projection data contract additions (§9) - four fields, `core/` work - [x] built

All four landed, with real new plumbing for three of them, not just a
formatting pass:

- [x] **`short_name` / `consequence_summary` per node - content authored
  and reviewed with the user before landing** (drafted in-conversation,
  two of the eighteen draft values changed on review - G's `SURVIVABLE`
  → `LVL 5 PLANET`, P's `SPACE STATION` → `ANCIENT STATION` - see git
  history for the reasoning). Live on `StarSystemDefinition` (`core/
  star_system_definition.gd`), not in `ui/` or `star_map_projection.gd`,
  per the spec's own instruction. `consequence_summary` only set for the
  7 letters with a real standing/on-arrival rule (G, I, J, K, L, M, P),
  matching `StarMapProjection._consequence()`'s existing derivation
  rather than a second hand-typed flag. Same iff-visited absence rule as
  `letter`/`name`/`class` - the leak test now covers both explicitly
  (`test_only_visited_nodes_carry_letter_name_class`,
  `test_serialized_projection_never_contains_an_unvisited_systems_name`,
  `test_a_claim_round_trips_without_leaking_the_true_letter` all
  extended). 2 new tests in `tests/core/star_system_definitions_test.gd`
  checking every letter has a short_name ≤16 chars and
  consequence_summary is present iff the letter actually has a rule.
- [x] **`left_turn` per node - built on new `FleetPositions.visited_turns`
  turn-stamped history**, resolving the design decision this item used
  to flag as open: `move_unit()`/`undo_last_move()` now take the current
  turn number (`GameState.turn_manager.turn_number`, threaded through
  from `HostConsole`'s Move/Undo buttons) and record it into `coordinate
  -> Array[int]` (deduped per turn), matching `docs/star_map_tv_display.md`
  §7's own data contract, which already specced a `visited_turns` field
  on the node dict that had never actually been built. `left_turn =
  visited_turns.back()`, omitted while the node is `occupied` (the rail
  shows who's there instead, per §6.2) - computed directly in
  `star_map_projection.gd`, not stored twice. `0000` seeds
  `visited_turns = [0]` in `FleetPositions._init()`, matching the
  original spec's own worked example. Persisted (`to_dict()`/
  `load_from_dict()`) for crash recovery. 7 new tests split across
  `tests/core/map/fleet_positions_test.gd` (the underlying recording:
  arrival turns, same-turn dedup, accumulation across separate visits,
  the `0000` seed, round-trip) and `tests/core/map/star_map_projection_test.gd`
  (`left_turn` present/absent correctly across occupied/departed/never-
  visited states).
- [x] **`scouts` per group - built on a new `StarChart.reachable_within()`
  BFS and a new `core/map/scout_ranges.gd`.** `reachable_within(from,
  hops)` (5 new tests in `tests/core/star_chart_test.gd`) fills the gap
  this item flagged - `graph_distance()` only ever gave point-to-point
  distance, nothing computed a reachable *set*. `ScoutRanges` holds the
  three scouts' ranges (Starlight 2, Hummingbird 3, Endeavour unlimited)
  as reference data, explicitly not a rule the engine enforces - same
  "public information, not a scout-honesty check" reasoning `core/craft/
  abilities/scout_system.gd`'s own comment already establishes for these
  exact numbers (5 new tests in `tests/core/map/scout_ranges_test.gd`).
  `StarMapProjection` now takes a `craft: Dictionary` parameter (all
  three `build()`/`build_ground_truth()`/call sites updated) and joins
  each scout's *live* `CraftState.docked_ship_id` against `FleetPositions`'
  current groups - deliberately not each scout's home ship, so a
  redeployed scout (the `redeploy` ability) follows its craft to
  whichever group its new host ship is actually in. 2 new tests cover
  both the normal case and the redeploy-follows-the-craft case.
- [x] **`band_tint` per group** - the easy one, exactly as scoped: derived
  from which group's tier each render pass is already computing, AEGIS's
  group winning ties for a shared tier. 2 new tests.

**One real bug caught by the tests, not the implementation**: the first
draft of the AEGIS-wins-a-shared-tier test picked "the first non-AEGIS
group in the array" to check against band_tint being false, and failed -
tracing it showed the test's own fixture (moving only 2 of 7 units)
produces *three* groups, not two, and the array's first non-AEGIS entry
was the uncontested tier-0 remainder (correctly band_tint=true), not the
tier-1 group actually sharing AEGIS's band. Fixed by selecting the
group by membership (`"Icebreaker" in members`) instead of by array
position - `_band_tint_winners()` itself was already correct.

All new/changed code verified against the real running app, not just
unit tests: a throwaway driving script drove `HostConsole`'s actual Move
button (confirmed `visited_turns` recorded the real current turn) and
instantiated the real `StarMapScreen` (confirmed `scouts` populated
correctly with `craft` threaded all the way through from `GameState`).
44 test files total (was 43), all green.

### Also needed, not called out as its own numbered item but real work

- [x] Idle mode (§10) - built, as literally the one flag the spec asks
  for: `StarMapScreen.idle_dim` toggles a `%IdleVeil` `ColorRect` over
  the whole screen. Draw-in suppression and "pulse kept" are both moot
  right now (neither the draw-in animation nor the locator pulse exist
  yet - see priority 2 above), so this is honestly simpler than the
  spec's full description until those land. **Nothing calls
  `idle_dim = true` yet** - `ui/main.gd`'s show/hide policy would need
  to decide when "idle" actually applies, which is the same open
  question already logged above (StarMapScreen isn't the TV's default
  idle screen today, TVDisplay is) - the mechanism exists, the trigger
  doesn't.
- [x] Title bar's `FLEET SPLIT · n GROUPS` chip (§8) - built, appended
  to the title text when `groups.size() > 1`, nothing further when the
  fleet is whole.
- [ ] **New test file** `tests/test_star_map_layout.gd` (§11), still not
  built - explicitly requested by name with 6 concrete checks (no two
  text elements overlap >6px on both axes; nothing renders past
  x1920/y1080 - "the first build lost a whole rail section this way";
  rail column bottom < y1010 at both the densest realistic state *and*
  the empty state; every info chip closer to its own node than any
  other node's centre; no text under 18px; minimum node-centre
  separation ≥160px for all 22 nodes) - "run it headless against the
  projection fixtures, not against a screenshot," matching this
  project's own established geometry-driving-script pattern (the Wolf
  Attack lane/ladder passes' "measure `get_combined_minimum_size()`
  against the assigned slot" scripts), but as a real committed test
  file this time, not a throwaway. Natural next step - the geometry
  this would check now actually exists to check.
- [ ] **Full rail redesign (§6)** - still not built. The group card kept
  its existing simple layout (just recoloured to `FLEET`/`FLEET_ALT`,
  see priority 1 above) rather than the spec's full reformat (title/
  coordinate/letter-badge row, consequence-summary line, scout-reach
  lines, pursuit pips instead of a bare number). **The Wolf Presence
  block (§6.2) is entirely unbuilt** - a filtered, C1-safe list of only
  `visited`/`occupied` wolf systems the room should care about, with
  "LEFT Tn" (now buildable - `left_turn` exists) or "HERE" per system.
  The Scout Reports block (§6.3) *is* built (see above) since removing
  claim text from the map without it would have been a regression, not
  a partial improvement - it just isn't styled to the spec's exact
  dashed-border/wash treatment yet.

### Explicitly out of scope per the design itself, not a gap in this pass

`README.md`'s own words: the scout-range wash over reachable nodes
(display spec §6.6) and 2/3-hop jump badges were "judged clutter against
the readability goal" and deliberately cut, addable behind host toggles
later if asked for. Matches this file's own `scout_rings`/`jump_ranges`
deferral already logged under `StarMapProjection`'s "what's needed"
section above - still nothing to build there, now doubly confirmed as
intentional rather than just unstarted.

**One thing worth flagging: the handoff's own README is stale against
this session's actual progress**, not wrong about the design work. It
says the original spec's "pursuit per jump vs per tier" and "merge
reconciliation" questions "are untouched by this pass and remain
blockers on the data model, not on rendering" - both are already
resolved and built earlier in this same session (see the "Blockers"
list above: cumulative-per-tier confirmed and wired into `JumpResolver`,
merge reconciliation built into `FleetPositions`/the admin console).
The README was written against the pre-this-session state of the
project; nothing here blocks starting the visual work.
