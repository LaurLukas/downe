# Open questions, answered from the source documents

Sources: *Facilitator Guide v1.0.1* (FG), *A3 Single Sided v1.0* (ship sheets),
*A4 Single Sided v1.0.1* (star charts, star system data, shuttle/wing cards),
*A4 Double Sided v1.0.1* (Wolf ship cards, role briefs, rules reference).

Where the source is silent or self-contradictory it says so explicitly. Do not
let those gaps get filled by invention.

---

# 1. Star systems

## 1.1 The map is a fixed graph with three letter assignments

This is the key structural finding: **the node graph and the coordinates never
change**. Three organiser charts (A, B, C) exist, and they differ *only* in which
system letter sits on which node. So the data model is one topology plus three
scenario variants — not three maps.

There are 22 nodes: `0000` (START) plus 21 lettered systems. Every chart uses the
same 21 nodes and the same edges.

### Nodes, coordinates and pursuit bands

Pursuit reduction is a property of the **node**, not the chart. Jumping to a node
in the −3 band sets pursuit reduction of 3 for that jump.

| Coordinate | Band | Chart A | Chart B | Chart C |
|---|---|---|---|---|
| `0000` | start | START | START | START |
| `5143` | −1 | L | E | L |
| `1413` | −1 | A | L | L |
| `9997` | −2 | C | L | D |
| `6837` | −2 | D | B | E |
| `0488` | −2 | L | L | C |
| `6931` | −3 | L | I | L |
| `4454` | −3 | M | L | L |
| `4753` | −4 | E | K | G |
| `1096` | −4 | I | F | M |
| `6964` | −4 | G | J | I |
| `2580` | −5 † | F | G | J |
| `3068` | −5 † | M | M | H |
| `0853` | −5 † | L | M | M |
| `6943` | −5 † | K | L | F |
| `6798` | −6 | N | M | N |
| `8378` | −6 | J | M | O |
| `1964` | −6 | P | P | K |
| `1380` | −7 | M | O | M |
| `1836` | −7 | H | M | M |
| `0408` | −7 | O | N | M |
| `4888` | −7 | P | H | P |

† **The band between −4 and −6 is unlabelled on all three printed charts.** I
checked the artwork directly at the right margin — there is simply no label
there. By position it must be −5. Treat that as a printing omission, confirm it,
and hardcode −5 with a comment pointing at this note.

Note which letters are absent per chart: **A has no B; B has no A, C or D; C has
no A or B.** Systems A, B, C and D are the low-value "Poor"/"Neutral" starter
systems, so each chart drops some of them. The New Eden candidates N, O and P
appear on every chart, always in the −6/−7 bands.

### Edges

Transcribed from Chart A's artwork. The topology is shared by B and C.

```
0000: 5143, 1413
5143: 0000, 1413, 9997, 6837
1413: 0000, 5143, 6837, 0488
9997: 5143, 6931
6837: 5143, 1413, 0488, 6931, 4454
0488: 1413, 6837, 4454
6931: 9997, 6837, 4454, 4753, 1096
4454: 6837, 0488, 6931, 1096, 6964
4753: 2580, 3068, 1096, 6931
1096: 6931, 4454, 4753, 3068, 0853, 6964
6964: 4454, 1096, 0853, 6943
2580: 6798, 4753
3068: 6798, 8378, 0853, 4753, 1096
0853: 8378, 1964, 3068, 1096, 6964
6943: 1964, 6964
6798: 1380, 1836, 2580, 3068
8378: 1836, 0408, 1964, 3068, 0853
1964: 8378, 0408, 4888, 0853, 6943
1380: 1836, 6798
1836: 1380, 6798, 8378
0408: 8378, 4888, 1964
4888: 0408, 1964
```

41 edges. **Verify this against the printed chart before trusting it** — I read it
off the artwork, and a missed line here would silently break scout range checks.
Add a test that asserts the adjacency list is symmetric.

"Within N jumps" for scouting (Starlight 2, Hummingbird 3) means graph distance
from the fleet's current node, not coordinate arithmetic.

## 1.2 System descriptions and away mission opportunities

Skills in use: `exploration`, `mining`, `salvage`, `science`, `engineering`,
`search_and_rescue`. Note that `exploration` is a sixth skill not listed in
`CLAUDE.md`'s glossary — add it.

Difficulty written `X/Y` means **X = success threshold, Y = critical threshold**.
A single number means that opportunity has no critical tier, and correspondingly
no "Critical:" line in its reward.

| Sys | Name | Rating | Deal | Opportunities (difficulty, skill) | Rewards, in order |
|---|---|---|---|---|---|
| A | Lichen-Covered Asteroids | Poor | 6 cards / 2 opps | 17 exploration; 24 mining | 8 food; 3 strytium ore |
| B | Ice Asteroids | Poor | 6 / 2 | 17 exploration; 24/30 mining | 6 water; 8 water, crit 1 material |
| C | Rare Element Moon | Poor | 6 / 2 | 20 mining **and** exploration; 25 science | 2 materials ‡; Endeavour crosses out 1 research box of choice |
| D | Abandoned Explorer Outpost | Neutral | 6 / 3 | 14/20 salvage; 14/20 salvage; 24 science | 10 food, crit 8 water; 6 strytium ore, crit 3 material; explore 2 star systems |
| E | I.C.S.S. Athena Survivors | — | 6 / 3 | 8/15 search & rescue; 14/25 salvage; 24 science | 750 survivors, crit +500; 4 materials, crit +3; explore 2 wolf star systems (code W1 or W2) |
| F | Abandoned Refuelling Station | — | 6 / 3 | 8 engineering; 14/25 salvage; 14 science | 10 strytium fuel; 7 strytium ore, crit +4; upgrade 1 or repair 2 consoles on Refinery 124 |
| G | Level 5 Survivable Planet | — | 8 / 3 | 17 search & rescue; 17 engineering; 24/30 salvage | 20 food; 20 water; 6 materials, crit upgrade 1 console |
| H | Derelict Research Vessel | — | 8 / 3 | 17 salvage; 17 science; 28 science | 6 materials and 4 strytium fuel; Endeavour crosses out 2 research boxes; fully unlock 1 research |
| I | Ion Nebula | — | 8 / 3 | 17 engineering; 17 engineering; 28 science | fleet no longer takes nebula damage; ships don't consume fuel jumping out; unlock ECM and Jump Drive research |
| J | Unstable Star | — | 3 / 1, **repeatable each turn** | 14/25 mining | 12 strytium ore, crit +10 |
| K | Abandoned Wolf Supply Outpost | — | 3 / 1, **repeatable each turn** | `<Unknown>` search & rescue | see below |
| L | Active Wolf Outpost | — | 6 / 3 | 15/20 salvage; 15/20 search & rescue; 25 science | 10 materials, crit +5; 10 strytium ore, crit +5; upgrade 2 weapon consoles |
| M | Active Wolf Fortress | — | 6 / 3 | 15/20 salvage; 15/20 search & rescue; 25 science | 12 materials, crit +6; 12 strytium ore, crit +6; upgrade 3 weapon consoles |

‡ The system card says "2 minerals". There is no such resource. It means
materials. Do not add a `minerals` type.

**Standing effects that are not away missions** — these belong on `StarSystem`,
not on opportunities:

- **G**: jumping here does not reduce the Pursuit Track.
- **I**: the Pursuit Track is not raised while in the nebula; each ship takes
  damage on a 3+ during the maintenance phase.
- **J**: each ship takes damage on a 4+ during the maintenance phase.
- **L**: on arrival, immediately trigger a Wolf attack with ≥1 battlestation and
  20 damage capacity of other ships. The fleet is attacked continually until the
  base is destroyed or the fleet jumps away, and **the away mission cannot be run
  while the base is operational**.
- **M**: as L, but ≥2 battlestations and 25 damage capacity.
- **K**: difficulty is generated at runtime. Secretly roll 1d6 = X. Difficulty is
  5X, critical at 5X+10. Success gives 2X food, 2X water, 2X strytium fuel and X
  materials. **Immediately triggers a Wolf attack unless the result is a
  critical success.** The `<Unknown>` on the card is deliberate — the players are
  not told the difficulty. Your UI must be able to show an unknown difficulty
  without leaking the rolled value.

### New Eden candidates (N, O, P) — not ordinary away missions

These have bespoke completion conditions, not card-based opportunities.

- **N — Ancient Jump Ring.** *Repair*: 10 materials, an Engineering Shuttle, and
  5 different console upgrades or science devices on the Endeavour research lab,
  each with 4 crosses. *Fuel*: 5 strytium fuel per ship passing through. The ring
  can then be sabotaged from the far side to stop the Wolf fleet following.
- **O — Deep Nebula.** Scout missions can be launched into the nebula if in
  range; each raises the success chance. To settle, each ship performs a long
  jump and rolls 1d6 +1 per scouting mission performed here. **9 or more = New
  Eden reached**; otherwise that ship is lost, and each lost ship adds +1 to
  subsequent ships' rolls. FG adds: do not show players the accrued bonus, so a
  Wolf Agent can lie about having scanned the nebula. **Design-critical — the
  accumulated bonus must not appear on any player-facing surface.**
- **P — Ancient Space Station.** On arrival, trigger a Wolf attack with ≥1
  battlestation and 20 damage capacity; surviving wolves attack again repeatedly
  until destroyed. *Liberate*: defeat all Wolf forces. *Power*: cannibalise ships
  with Reactor consoles supplying at least 18 consoles' worth of power.

FG: there are 3 New Eden candidates in the game; track which have been found and
whether the fleet has a plan by turn 6.

## 1.3 Away mission resolution

- Deck: any 3 suits of a standard deck with the 2s and 3s removed — **33 cards**.
- Steps: select mission leader → receive cards → discard one → assign cards to
  opportunities → add one random card to each opportunity → total.
- Scoring: A–10 are worth +1 to +10. Face cards are **−5**. Add shuttle bonuses.
- Missions can be run once per new destination, except J and K which repeat every
  turn.
- If a mission overruns into the Team Phase, the shuttles stay on the mission and
  the players keep going until it completes.

Per the constraints in the shuttle brief: automate the totalling and threshold
comparison only. Dealing, discarding and assignment stay physical.

## 1.4 Unresolved

**"Explore 2 wolf star systems (code W1 or W2)"** in system E's reward. No W1 or
W2 appears on any chart or in any system data. Either it's vestigial from an
earlier map version, or wolf systems have hidden codes not present in these PDFs.
Ask before modelling it.

---

# 2. Starting fleet setup

Starting resources and populations are already covered in `resources.md`. This
section covers the consoles.

## 2.1 The damage deck is the console index

Each console carries a **playing card** in its corner. The rules reference says a
damaged console is covered by a card, removed on repair. Every console on a ship
has a unique card *within that ship's suit range*, so **each ship has its own
damage deck consisting of exactly its own console cards**. Damage is dealt by
drawing.

Confirmation from the AEGIS's Armoured Hull consoles: "shuffle the card back into
the damage deck, unless that deck is empty". So the deck is finite, per-ship, and
depletes. This is load-bearing — model the deck, not a random console picker.

Suit allocation: AEGIS ♥, Refinery 124 ♦, Shepherd ♠A–7, Icebreaker ♠8–K plus
Q♦/K♦, Quellon ♣A–7, Dione ♣8–K plus 10♦/J♦.

## 2.2 Console rosters

**AEGIS** — Battleship. Maintenance steps 1–7. Reactor charges 5. Jump 2/3/6.
Two shuttle bays. Consoles split across the ship sheet and a separate Battle
Sheet the First Officer takes to the battle table.

| Card | Console | Notes |
|---|---|---|
| A♥ | Fighter Bay Alpha | charged → launch a fighter wing |
| 2♥ | Fighter Bay Bravo | charged → launch a fighter wing |
| 3♥ | Command and Control | after targeting, force 1 Wolf ship to retarget the AEGIS. Upgraded: at end of attack, 1 ship takes −1 damage |
| 4♥ | Missile Launchers | Long: 2 damage to 1 target. Medium: 4 dice, 1 damage per 5+ to different targets. Upgraded: +1 long damage, +1 medium die |
| 5♥ | Point Defence Lasers | Medium: 2 dice, 1 damage per 4+. Short: 2 dice, 1 damage per 2+. Upgraded: +1 target |
| 6♥ | Armoured Hull I | damaged → do not lose survivors; card reshuffles |
| 7♥ | Armoured Hull II | as above |
| 8♥ | Storage | maintenance step 1 |
| 9♥ | Jump Drive | 2/3/6 fuel |
| 10♥ | Reactor | step 5, charge up to 5 |
| J♥ | Construction Bay | charged → add fighters at 1 material each, max 4 per wing (6 upgraded) |
| Q♥ | Shuttle Bay Zeta | step 6 |
| K♥ | Shuttle Bay Omega | step 7 |

Also on the battle sheet, not a console: at the start of a Wolf attack, spend 5
strytium ore from the AEGIS's hold to enrich warheads — +1 damage at Long Range,
and Medium range hits on 4+ instead of 5+. Boarding: the AEGIS may re-roll up to
3 dice to repel boarders.

**Dione** — Luxury Cruiser. Steps 1–6. Reactor charges 4. Jump 2/4/8.

| Card | Console |
|---|---|
| 8♣ | Storage (step 1) |
| 9♣ | Reactor (step 5, charge 4) |
| 10♣ | Shuttle Bay (step 6) |
| J♣ | Hydroponics — charged: 1 water → 3 food. Upgraded +2 food |
| Q♣ | Water Reclamation — charged: 2 water. Upgraded +2 |
| K♣ | VIP Lounge — charged: draw a VIP card |
| 10♦ | Fighter Bay — charged: launch the Maliades |
| J♦ | Jump Drive — 2/4/8 |

**Icebreaker** — Mining Vessel. Steps 1–6. Reactor charges 4. Jump 3/6/12.

| Card | Console |
|---|---|
| 8♠ | Storage |
| 9♠ | Reactor (charge 4) |
| 10♠ | Shuttle Bay |
| J♠ | Hydroponics — 1 water → 3 food. Upgraded +2 |
| Q♠ | Water Reclamation — 2 water. Upgraded +2 |
| K♠ | Mining Drone Control — charged: 3 materials. Upgraded +2 |
| Q♦ | Jump Drive — 3/6/12 |
| K♦ | Ram Scoop — on jump, if charged: 10/15/20 strytium ore for short/medium/long. Upgraded +5 |

**Shepherd** — Deep Space Supply Vessel. Steps 1–6. Reactor charges 3. Jump 3/6/12.

| Card | Console |
|---|---|
| A♠ | Storage |
| 2♠ | Reactor (charge 3) |
| 3♠ | Shuttle Bay |
| 4♠ | Water Reclamation — 2 water. Upgraded +2 |
| 5♠ | Advanced Hydroponics — 2 water → 12 food. Upgraded +4 |
| 6♠ | Advanced Hydroponics — as above |
| 7♠ | Jump Drive — 3/6/12 |

**Quellon** — Water Hauler. Steps 1–6. Reactor charges 3. Jump 2/4/8.

| Card | Console |
|---|---|
| A♣ | Storage |
| 2♣ | Reactor (charge 3) |
| 3♣ | Shuttle Bay |
| 4♣ | Hydroponics — 1 water → 3 food. Upgraded +2 |
| 5♣ | Water Production — 12 water. Upgraded +4 |
| 6♣ | Water Production — as above |
| 7♣ | Jump Drive — 2/4/8 |

**Refinery 124** — Fuel Refinery. Steps 1–6. Reactor charges 4. Jump 2/4/8.

| Card | Console |
|---|---|
| A♦ | Storage |
| 2♦ | Reactor (charge 4) |
| 3♦ | Shuttle Bay |
| 4♦ | Hydroponics — 1 water → 3 food. Upgraded +2 |
| 5♦ | Water Reclamation — 2 water. Upgraded +2 |
| 6♦ | Fuel Refinery — spend up to 10 ore, 1 fuel per ore. Upgraded +5 ore |
| 7♦ | Fuel Refinery — as above |
| 8♦ | Fighter Bay — charged: launch the P.D.F. Escort Fighter Wing |
| 9♦ | Jump Drive — 2/4/8 |

Universal console rules: **Damaged** Jump Drive fails on 1–3; upgraded, it uses 1
less fuel and only fails on a 1. **Damaged** Reactor charges 2 fewer consoles on
Shepherd/Quellon, 3 fewer elsewhere. Upgraded Reactor charges +1. Production
consoles cannot be charged while damaged. Upgrade cost tracks show 5 boxes on
most production consoles, 4 on the Dione's VIP Lounge.

## 2.3 Ration tables

Per ship, and **replaced when population drops to a red square** (see FG,
Population Changes). Format: spend → unrest dice bonus.

| Ship | Food: none / minimal / short / normal | Water: none / minimal / short / normal |
|---|---|---|
| AEGIS | 0 / 3 / 5 / 8 | 0 / 2 / 3 / 6 |
| Dione | 0 / 6 / 12 / 18 | 0 / 6 / 11 / 14 |
| Icebreaker | 0 / 4 / 9 / 13 | 0 / 4 / 7 / 10 |
| Shepherd | 0 / 4 / 8 / 12 | 0 / 3 / 6 / 9 |
| Quellon | 0 / 4 / 8 / 12 | 0 / 3 / 6 / 9 |
| Refinery 124 | 0 / 3 / 7 / 11 | 0 / 2 / 5 / 8 |

Bonuses are always +0 / +3 / +6 / +9 respectively, for both food and water, on
every ship. Only the costs vary.

## 2.4 Still unspecified

- **Starting console charge state.** Not stated. The role briefs imply everything
  starts uncharged and the first Team Phase runs the first maintenance cycle.
- **Starting console damage.** Presumably none. Not stated.
- **Hold capacities.** None printed. Uncapped.
- **Extra ships** (ICSS Gorgoneion, SANS Capybara, RSS Warrior, PV Vulcan, GIV
  Voyage 33-0) use the *Small Ship* rules: they must dock with a regular ship
  each Team Phase and Wolf Attack, run a 4-step maintenance cycle, draw resources
  from their host, cannot take damage, and jump for 1 fuel short/medium and 2
  long. Adding one means adding ~3 damage capacity of Wolf ships per attack.

---

# 3. Wolf Attack data

## 3.1 Wolf ship roster

Every card carries a "Target" and a "Damage Taken" tracker.

| Ship | Capacity | Destroyed at Long | Destroyed at Medium | Destroyed at Short | If it survives |
|---|---:|---|---|---|---|
| Wolf Battlestation | 6 | 3 damage to target | 3 damage to target | **cannot be damaged at Short Range** | 3 damage to target, and it returns in the next attack |
| Wolf Fleet Strikecarrier | 5 | 2 damage | 2 damage | 2 damage | 2 damage, and surviving Wolf Fighter Wings do +1 damage |
| Wolf Cruiser | 3 | no effect | 1 damage | 2 damage | 3 damage |
| Wolf Destroyer | 2 | 1 damage | 1 damage | 1 damage | 2 damage |
| Wolf Fighter Wing | 1 | no effect | no effect | 1 damage | 1 damage, and it returns in the next attack |
| Wolf Assault Transport | 2 | no effect | no effect | no effect | **4 Wolf Boarding Parties** attack the target in the Boarding Phase |

Extra rule on the Fighter Wing card: **during the Short Range phase, all fleet
damage must be assigned to Wolf Fighter Wings first.** That is a hard targeting
constraint, not advice.

Physical deck contents: 2 Battlestations, 2 Strikecarriers, 4 Cruisers, 4
Destroyers, 22 Fighter Wings, 8 Assault Transports — **80 total damage capacity**.
That is the hard ceiling on any single attack.

## 3.2 Attack strength scaling

Three different numbers govern this, from three places. They are consistent if
you read them as different authorities:

- **Turn 1, scripted** (FG p10): exactly 10 Wolf Fighter Wings and 5 Wolf Assault
  Transports. That is 20 damage capacity, weighted heavily toward boarding.
- **Facilitator-run attacks** (FG p10): 1–2 further attacks across the game, each
  with 15–24 total damage capacity.
- **Wolf Commander player, if in play**: each turn they may marshal
  **10 damage capacity + the current Pursuit Track value**. This is the only
  explicit formula in the documents, and it is the one to implement as the
  pursuit-scaling rule. At pursuit 0 that's 10; at pursuit 9 it's 19 — which
  lands inside the facilitator's 15–24 band.
- **System-triggered attacks**: L → ≥1 battlestation + 20 capacity of other
  ships. M → ≥2 battlestations + 25. P → ≥1 battlestation + 20, repeating until
  all wolves are destroyed. K → an attack unless the away mission critically
  succeeded.
- **Per extra ship in play**: add ~3 damage capacity.

FG p10 also notes: pre-lay the attack cards and pre-roll the targeting dice
before announcing, and if players spot the pattern, just keep an attack
permanently set up. Worth knowing if your host console is going to prepare
attacks — the preparation being visible is explicitly fine.

## 3.3 Battle table numbers

**Steps**: 1 Targeting → 2 Long Range → 3 Medium Range → 4 Short Range → 5
Boarding Action. After the Boarding Action all surviving Wolf ships damage their
targets and then jump away.

**Targeting table** (1d6 per Wolf ship):

| Roll | Target |
|---:|---|
| 1 | AEGIS |
| 2 | Dione |
| 3 | Icebreaker |
| 4 | Quellon |
| 5 | Shepherd |
| 6 | Refinery 124 |

This is why fighter and Maliades abilities that shift a target number by ±1 say
"1s and 6s wrap around — 0s hit Refinery 124 and 7s hit the AEGIS".

**Boarding Defence table** (1d6 per engagement):

| Roll | Result |
|---:|---|
| 1 | Security Team dies |
| 2–3 | No effect |
| 4+ | Wolf Assault Team dies |

**Pursuit Track**: 0–10. **+2 per turn. −1 per jump away from `0000`** (i.e. the
node's band value; see §1.1). At 10 the Wolves envelop the fleet and the game
ends in failure. Not raised while in the Ion Nebula (I). Not reduced by jumping
to the Level 5 Survivable Planet (G). If the fleet splits, each part tracks its
own pursuit score independently.

**Wolf Commander abilities** (replacement role, if in play): re-roll any targeting
dice once, before the AEGIS's Command and Control; adjust one ship's targeting
die by 1 in each range phase (6↔1 wrap); optionally lead a boarding action
personally for +2 boarding parties, decided *before* the Pallas and Chepu
abilities are used. They may also offer amnesty to any ship that surrenders by
making a medium jump to `0101` — note that `0101` is not a node on any chart.

**Damage consequences**: survivors die from all damage a ship takes, including
riot damage in the maintenance cycle. If a ship is destroyed, escape pods save
roughly its crew+passenger capacity; the players keep their shuttles and can
scavenge the ship's resources.

**Overrun rule**: if an attack runs into the Team Phase, shuttles stay docked
wherever they were left and maintenance cycles are completed without moving
resources.

---

# 4. Suspicion and secret objectives

## 4.1 What actually exists in the documents

**Suspicion is a per-player integer with a documented starting value per loyalty
and one documented consumer.** There is no per-player "secret objective" system
distinct from the loyalty cards — the objectives *are* on the loyalty and role
briefs. Both are paper.

| Loyalty | Starting suspicion | Count |
|---|---|---|
| Fleet Loyalist | 0 (most), plus **two 5s and one 10** included every game | default |
| Wolf Agent | 0 | 1 at 8–13 players, 2 at 14–18 |
| Intelligence Agent | 6 | 1, usually the PDF Colonel, if any Wolf Agent is in play |
| Universal Arbourage leader | 10 (brief prints 5 — see below) | 0–1, experienced groups |
| Wolf Cult leader | 15 | replaces a second Wolf Agent |
| Android | 5 (brief prints N/A — see below) | optional, for nervous players |
| Friend (pairs) | 0 | optional |

**Two contradictions between the Facilitator Guide and the printed loyalty
cards.** FG p9 lists Universal Arbourage at 10 and Android at 5; the printed
cards say 5 and N/A respectively. Pick one source and record the decision — I'd
take the FG, since it's the operational document, but it's your call.

The deliberate inclusion of loyalists starting at 5 and 10 is the whole point of
the system: a nonzero suspicion score is not evidence of anything. Any UI must
not imply otherwise.

## 4.2 The clue table — the one mechanical consumer of suspicion

Triggered **only when a Wolf Agent gains suspicion**, not other loyalties. Roll
1d6 and add it to their *new* suspicion level:

| Total | Facilitator action |
|---:|---|
| 0–6 | No effect |
| 7–11 | Point out the change to someone, framed as natural or accidental |
| 12–15 | Point out the wolf activity to someone |
| 16–19 | Point out the wolf activity, and give a hint |
| 20–23 | Give someone a strong hint |
| 24+ | Give someone the name of the traitor |

## 4.3 Arrests

Posse size required = **6 players (including the accuser), minus 1 per 5
suspicion on the target, plus 1 per player who stands up for them.**

FG is explicit: **tell the players the number required, never the suspicion
value.** Facilitators may adjust by ±1 if they think players are gaming it.
Prisoners must be released or executed by the end of the next Team Phase.

That constraint is the whole design of any suspicion UI you build: the host
console shows the number, the players' phones show nothing.

## 4.4 The Intelligence Agent's investigation

Once per turn they may investigate one player. They are told, **with 80%
accuracy**, whether that player is a Wolf Agent. This raises their own suspicion
by 2.

The 20% error rate is the mechanic. If you automate this, the roll must be
genuinely random per query and must **not** be cached — asking twice about the
same player should be able to return different answers, and the host must not be
shown the true value alongside the reported one in a way that could leak.

## 4.5 Secret information held per role

Not a separate system, but this is what your phone pages would carry:

- **Wolf Agent**: objectives, a code word for recognising other agents, and the
  knowledge that they don't know who the others are.
- **Wolf Cult leader**: location of an active Wolf fortress, location of
  abandoned supplies, the identity of the other Wolf agent, and the code word.
- **Universal Arbourage leader**: three "visions", some of which are probably
  true — a safe location, a dangerous location, and a suspicious player.
- **Friend**: the role name of their guaranteed-innocent partner.
- **Android**: may show their sheet to anyone as definitive proof of innocence.
- **Intelligence Agent**: their investigation results.

Note the Android's card is explicitly showable and the Friend's is mirrored
between two players. If loyalty stays on paper, this all stays on paper, and the
phone pages carry only suspicion and any facilitator-issued clues.

## 4.6 Team objectives

Every role brief carries the same three-part team objective, varying only by
nation: contribute to the fleet's survival; keep this ship and its nation's
survivors safe; ensure this nation has a say and isn't taken for granted. These
are open-ended and unscored — FG is explicit that there are no victory points and
"how well a player did is for them to interpret".

**Recommendation:** don't build a scoring model for these. Building one would
create an authoritative answer to a question the game deliberately leaves open.

---

# 5. Turn phase structure

## 5.1 Two phases, with an internal step sequence inside the Team Phase

- **Team Phase — 5 minutes.** All players stay at their ship's table. The ship
  runs its Maintenance Cycle. Extended by 5 minutes on turn 1.
- **Coordination Phase — 15 minutes.** Free movement and communication. Shuttle
  operations, jumps, away missions, Wolf attacks. Extended by 10 minutes on turn
  1, with a Wolf attack triggered about 10 minutes in.

6–8 turns.

## 5.2 The Maintenance Cycle steps

The steps are numbered badges on the ship sheets. Each step is either a console
that owns it or a table-wide action.

| Step | Owner | Action |
|---:|---|---|
| 1 | Storage console | **If damaged**, discard half the ship's resources, including those on docked shuttles. Round losses down |
| 2 | Ration table | Select a ration level separately for food and water. Spend that amount, gain both bonuses for step 3 |
| 3 | — | Roll 2d6 + ration bonuses. Total under 12 → gain 2 unrest. Total under 20 → gain 1 unrest |
| 4 | — | Roll 1d6. If lower than current unrest, the ship takes 1 damage from rioting |
| 5 | Reactor | Charge up to N consoles (5 AEGIS, 4 Dione/Icebreaker/Refinery 124, 3 Shepherd/Quellon). Upgraded +1. Damaged −2 or −3 |
| 6 | Shuttle Bay | Spend 1 strytium fuel to refuel one docked shuttle. Damaged → cannot refuel |
| 7 | Shuttle Bay Omega | **AEGIS only.** A second refuel |

So: `TurnManager` needs Team Phase to expose an ordered walkthrough of 6 steps
for five ships and 7 for the AEGIS, run **per ship in parallel**, not fleet-wide
in lockstep — each table works through its own cycle simultaneously.

**Source error to be aware of:** on the AEGIS sheet, Shuttle Bay Omega carries the
step badge **7** but its body text reads "Maintenance Step 6", copied from Zeta.
The header ("perform maintenance steps 1–7") and the badge agree, so 7 is right.

**Extra/small ships** run a 4-step cycle with no Storage step: 1 ration selection,
2 unrest roll, 3 riot roll, 4 charge. Their riot step differs — they lose
population equal to the die value and skip step 4 that turn, rather than taking
damage.

## 5.3 End-of-turn processing

From the FAQ: **any unused console charge, and any unused shuttle fuel, is lost
at the end of the turn**, whether or not it was used. That's a single sweep in
end-of-turn.

## 5.4 Things that hang off the phase boundaries

- Pursuit +2 per turn; the assistant facilitator updates pursuit and the survivor
  census during the Team Phase.
- The President may address the fleet at the start of each Team Phase, and may
  invite one extra speaker.
- The Wolf Commander, if in play, may address the fleet for up to 30 seconds at
  the start of each turn, and marshals their attack force during the Team Phase.
- The Endeavour's research and console purchases happen during the Team Phase.
- Jumps, away missions and shuttle abilities are Coordination Phase only.
- Fighter exchange between Wings Alpha and Bravo is Coordination Phase.

---

# Summary of what still needs a decision from you

1. The −5 pursuit band label, absent from all three printed charts.
2. Verification of the 41-edge adjacency list against the printed chart.
3. What "W1 or W2" wolf star system codes refer to (system E's third reward).
4. Universal Arbourage starting suspicion: 10 (FG) or 5 (card)?
5. Android starting suspicion: 5 (FG) or N/A (card)?
6. Starting console charge and damage state at setup.
7. Whether to model team objectives at all — recommendation above is no.
