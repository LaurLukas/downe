# Ship Registry

Every vessel in DoWNE, in one place. Sources: *A3 Single Sided v1.0* (the six
core ship sheets), *A4 Single Sided v1.0.1* and *A4 Double Sided v1.0.1* (extra
ships, small craft), *Facilitator Guide v1.0.1*.

Three classes of vessel exist and they follow different rules:

- **Ships** — the six core vessels. Own hold, own survivor population, take
  damage via a per-ship damage deck, run a 6-or-7 step maintenance cycle.
- **Small Ships** — the five extra vessels. Own population and unrest, own jump
  drive, run a 4-step cycle, **cannot take damage**, must be docked with a Ship
  during every Team Phase and Wolf Attack, and draw resources from their host.
- **Small craft** — shuttles, fighters and fighter wings. Indexed at the bottom;
  full data lives in the shuttle brief.

---

## Quick index

| ID | Display name | Class | Nation | In play |
|---|---|---|---|---|
| `aegis` | I.C.S.S. "AEGIS" | Ship — Battleship | Interstellar Council | always |
| `dione` | F.S.C. "Dione" | Ship — Luxury Cruiser | F.A.S. | always |
| `icebreaker` | C.S.V. "Icebreaker" | Ship — Mining Vessel | C.P.A. | always |
| `shepherd` | R.S.S. "Shepherd" | Ship — Deep Space Supply Vessel | Rosal | always |
| `quellon` | P.V. "Quellon" | Ship — Water Hauler | Proxima | always |
| `refinery_124` | G.I.V. "Refinery 124" | Ship — Fuel Refinery | Gliese | always |
| `gorgoneion` | I.C.S.S. Gorgoneion | Small Ship — Frigate | Interstellar Council | optional |
| `capybara` | S.A.N.S. Capybara | Small Ship — Supply Ship | S.A.N. | optional |
| `warrior` | R.S.S. Warrior | Small Ship — Salvage Vessel | Rosal | optional |
| `vulcan` | P.V. Vulcan | Small Ship — Prison Ship | Proxima | optional |
| `voyage_33_0` | G.I.V. Voyage 33-0 | Small Ship — Damaged Star Cruiser | Gliese | crisis only |

---

# Core ships

## `aegis` — I.C.S.S. "AEGIS"

**Battleship.** The Interstellar Council Navy's warship. Supplies the fleet with
firepower, protection and exploration.

| | |
|---|---|
| Length / Tonnage | 250 m / 80,000 |
| Crew / Passenger capacity | 3,000 / 100 |
| Starting population | **2,500** (lowest in the fleet) |
| Maintenance steps | **1–7** (only ship with 7) |
| Reactor charge | 5 consoles |
| Jump cost (short/med/long) | 2 / 3 / 6 (cheapest in the fleet) |
| Shuttle bays | **2** — Zeta and Omega |
| Damage deck suit | ♥ |
| Starting resources | 0 ore, 4 fuel, 8 food, 6 water, 1 material, **9 security teams** |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| A♥ | Fighter Bay Alpha | Charged: launch a fighter wing |
| 2♥ | Fighter Bay Bravo | Charged: launch a fighter wing |
| 3♥ | Command and Control | After targeting, force 1 Wolf ship to retarget the AEGIS. Upgraded: at end of attack 1 ship takes −1 damage |
| 4♥ | Missile Launchers | Long: 2 damage to 1 target. Medium: 4 dice, 1 damage per 5+ to different targets. Upgraded: +1 long damage, +1 medium die |
| 5♥ | Point Defence Lasers | Medium: 2 dice, 1 damage per 4+. Short: 2 dice, 1 damage per 2+. Upgraded: +1 target |
| 6♥ | Armoured Hull I | Damaged: do not lose survivors; card reshuffles into the deck |
| 7♥ | Armoured Hull II | As Hull I |
| 8♥ | Storage | Step 1 |
| 9♥ | Jump Drive | 2 / 3 / 6 |
| 10♥ | Reactor | Step 5, charge 5. Damaged: −3 |
| J♥ | Construction Bay | Charged: add fighters at 1 material each, max 4 per wing (6 upgraded) |
| Q♥ | Shuttle Bay Zeta | Step 6 |
| K♥ | Shuttle Bay Omega | Step 7 |

Consoles A♥–5♥ live on a separate **Battle Sheet** the Executive Officer takes to
the battle table, not on the A3 ship sheet.

**Off-console abilities.** At the start of a Wolf attack, spend 5 strytium ore
from the hold to enrich warheads: +1 damage at Long Range, and Medium hits on 4+
instead of 5+. During Boarding, the AEGIS may re-roll up to 3 dice.

**Rations** — Food 0/3/5/8, Water 0/2/3/6 for +0/+3/+6/+9.

**Small craft**: Fighter Wing Alpha, Fighter Wing Bravo, Starlight, Pallas.

**Roles**: Admiral, Executive Officer, Wing Commander. Replacement role: Comms
Officer.

**Notes for implementation.** The AEGIS is the only ship that can refuel two
shuttles per turn, one per bay. It produces no food or water at all, so it is
structurally dependent on the Shepherd and Quellon — a good early signal if the
fleet's trade network has broken down.

---

## `dione` — F.S.C. "Dione"

**Luxury Cruiser.** Carries the Interstellar Council President and the bulk of
the fleet's survivors.

| | |
|---|---|
| Length / Tonnage | 550 m / 500,000 |
| Crew / Passenger capacity | 4,000 / 12,000 |
| Starting population | **100,000** (45% of the fleet) |
| Maintenance steps | 1–6 |
| Reactor charge | 4 consoles |
| Jump cost | 2 / 4 / 8 |
| Shuttle bays | 1 |
| Damage deck suit | ♣ (8–K) plus 10♦, J♦ |
| Starting resources | 0 ore, 3 fuel, 13 food, 14 water, 0 materials, 2 security teams |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| 8♣ | Storage | Step 1 |
| 9♣ | Reactor | Step 5, charge 4. Damaged: −3 |
| 10♣ | Shuttle Bay | Step 6 |
| J♣ | Hydroponics | Charged: 1 water → 3 food. Upgraded +2 |
| Q♣ | Water Reclamation | Charged: 2 water. Upgraded +2 |
| K♣ | VIP Lounge | Charged: draw a VIP card. 4 upgrade boxes, not 5 |
| 10♦ | Fighter Bay | Charged: launch the Maliades |
| J♦ | Jump Drive | 2 / 4 / 8 |

**Rations** — Food 0/6/12/18, Water 0/6/11/14. By far the most expensive to feed,
which is the whole political weight of the ship.

**Small craft**: Philia (engineering shuttle), Maliades (escort fighter).

**Roles**: Captain, Engineer, President. Replacement role: VIP Host.

**Presidential powers** (not a console): a Political Capital track; each turn the
President may address the fleet at the start of the Team Phase and invite one
extra speaker; during the Coordination Phase they may spend 1 political capital
to reduce a ship's unrest by 1. Crises are issued to them by a facilitator, and
resolving one grants a point of political capital.

---

## `icebreaker` — C.S.V. "Icebreaker"

**Mining Vessel.** Supplies the fleet with materials and strytium ore.

| | |
|---|---|
| Length / Tonnage | 800 m / 1,200,000 (largest in the fleet) |
| Crew / Passenger capacity | 10,000 / 100 |
| Starting population | 40,000 |
| Maintenance steps | 1–6 |
| Reactor charge | 4 consoles |
| Jump cost | 3 / 6 / 12 (most expensive, tied with Shepherd) |
| Shuttle bays | 1 |
| Damage deck suit | ♠ (8–K) plus Q♦, K♦ |
| Starting resources | 0 ore, 4 fuel, 11 food, 9 water, **3 materials**, 2 security teams |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| 8♠ | Storage | Step 1 |
| 9♠ | Reactor | Step 5, charge 4. Damaged: −3 |
| 10♠ | Shuttle Bay | Step 6 |
| J♠ | Hydroponics | Charged: 1 water → 3 food. Upgraded +2 |
| Q♠ | Water Reclamation | Charged: 2 water. Upgraded +2 |
| K♠ | Mining Drone Control | Charged: 3 materials. Upgraded +2 |
| Q♦ | Jump Drive | 3 / 6 / 12 |
| K♦ | Ram Scoop | On jump, if charged: 10 / 15 / 20 strytium ore for short / medium / long. Upgraded +5 |

**Rations** — Food 0/4/9/13, Water 0/4/7/10.

**Small craft**: Blacksmith (engineering shuttle), Highwall (mining shuttle).

**Roles**: Captain, Engineer, Miner. Replacement role: C.P.A. Commissar.

**Notes.** The Ram Scoop is the fleet's main ore source and it only fires on
jumps, so the Icebreaker's incentive to keep moving is mechanical, not political.
It starts with 3 of the fleet's 4 materials.

---

## `shepherd` — R.S.S. "Shepherd"

**Deep Space Supply Vessel.** Supplies the fleet with food and upgrades.

| | |
|---|---|
| Length / Tonnage | 700 m / 750,000 |
| Crew / Passenger capacity | 4,000 / 4,000 |
| Starting population | 30,000 |
| Maintenance steps | 1–6 |
| Reactor charge | **3 consoles** (joint lowest) |
| Jump cost | 3 / 6 / 12 |
| Shuttle bays | 1 |
| Damage deck suit | ♠ (A–7) |
| Starting resources | 0 ore, 4 fuel, 10 food, 8 water, 0 materials, 2 security teams |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| A♠ | Storage | Step 1 |
| 2♠ | Reactor | Step 5, charge 3. Damaged: −2 |
| 3♠ | Shuttle Bay | Step 6 |
| 4♠ | Water Reclamation | Charged: 2 water. Upgraded +2 |
| 5♠ | Advanced Hydroponics | Charged: 2 water → 12 food. Upgraded +4 |
| 6♠ | Advanced Hydroponics | As above |
| 7♠ | Jump Drive | 3 / 6 / 12 |

**Rations** — Food 0/4/8/12, Water 0/3/6/9.

**Small craft**: Black Sheep (service shuttle), Endeavour (science shuttle).

**Roles**: Captain, Engineer, Scientist.

**Notes.** Carries the **Endeavour Science Lab sheet** as a separate component —
the research and console-upgrade track, with two science devices purchasable
during the Team Phase, up to 3 research choices per turn, and up to twice per turn
the Scientist may spend 5 strytium ore from the Shepherd's hold for an extra
research pick. Only 3 reactor charges against 7 consoles means the Shepherd is
always running something cold.

---

## `quellon` — P.V. "Quellon"

**Water Hauler.** Supplies the fleet with water and exploration.

| | |
|---|---|
| Length / Tonnage | 600 m / 700,000 |
| Crew / Passenger capacity | 6,500 / 10 |
| Starting population | 30,000 |
| Maintenance steps | 1–6 |
| Reactor charge | **3 consoles** |
| Jump cost | 2 / 4 / 8 |
| Shuttle bays | 1 |
| Damage deck suit | ♣ (A–7) |
| Starting resources | 0 ore, 3 fuel, 10 food, 8 water, 0 materials, 2 security teams |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| A♣ | Storage | Step 1 |
| 2♣ | Reactor | Step 5, charge 3. Damaged: −2 |
| 3♣ | Shuttle Bay | Step 6 |
| 4♣ | Hydroponics | Charged: 1 water → 3 food. Upgraded +2 |
| 5♣ | Water Production | Charged: **12 water**. Upgraded +4 |
| 6♣ | Water Production | As above |
| 7♣ | Jump Drive | 2 / 4 / 8 |

**Rations** — Food 0/4/8/12, Water 0/3/6/9.

**Small craft**: Condor (service shuttle), Hummingbird (exploration shuttle).

**Roles**: Captain, Engineer, Explorer. Replacement role: Doctor.

**Notes.** Passenger capacity of 10 against a population of 30,000 — the capacity
figures on the sheets are flavour and must not be enforced as a rule. The
Quellon's brief also credits it with "upgrades", but the upgrade machinery lives
on the Shepherd's Endeavour; treat the brief text as flavour.

---

## `refinery_124` — G.I.V. "Refinery 124"

**Fuel Refinery.** Supplies the fleet with strytium fuel and aids in its defence.

| | |
|---|---|
| Length / Tonnage | "500 km" / 450,000 — the length is a typo on the sheet, read as 500 m |
| Crew / Passenger capacity | 5,000 / **0** |
| Starting population | 20,000 |
| Maintenance steps | 1–6 |
| Reactor charge | 4 consoles |
| Jump cost | 2 / 4 / 8 |
| Shuttle bays | 1 |
| Damage deck suit | ♦ |
| Starting resources | **12 ore**, 5 fuel, 9 food, 4 water, 0 materials, **6 security teams** |

**Consoles**

| Card | Console | Effect |
|---|---|---|
| A♦ | Storage | Step 1 |
| 2♦ | Reactor | Step 5, charge 4. Damaged: −3 |
| 3♦ | Shuttle Bay | Step 6 |
| 4♦ | Hydroponics | Charged: 1 water → 3 food. Upgraded +2 |
| 5♦ | Water Reclamation | Charged: 2 water. Upgraded +2 |
| 6♦ | Fuel Refinery | Charged: spend up to 10 ore, gain 1 fuel per ore. Upgraded +5 ore |
| 7♦ | Fuel Refinery | As above |
| 8♦ | Fighter Bay | Charged: launch the P.D.F. Escort Fighter Wing |
| 9♦ | Jump Drive | 2 / 4 / 8 |

**Rations** — Food 0/3/7/11, Water 0/2/5/8.

**Small craft**: Chacau (engineering shuttle), Chepu (assault shuttle), P.D.F.
Escort Fighter Wing.

**Roles**: Captain, Engineer, PDF Colonel. Replacement role: PDF Fighter Ace.

**Notes.** The only ship holding strytium ore at setup, and the only one that can
convert ore to fuel — so every jump in the game routes through this table. It is
also the only non-AEGIS ship with a Fighter Bay. The Facilitator Guide flags that
the PDF Colonel is under-occupied outside Wolf attacks and is therefore the usual
candidate for the Intelligence Agent, a Wolf Agent, or the Universal Arbourage
leader.

---

# Small Ships (extra vessels)

Shared rules for all five: docked with a Ship during every Team Phase and Wolf
Attack; **cannot take damage**; no consoles to damage; own unrest and population
tracks; 4-step maintenance cycle; resources drawn from the host ship's hold.

**Small Ship maintenance cycle** (differs from Ships — no Storage step, and the
riot step costs population rather than damage):

| Step | Action |
|---:|---|
| 1 | Select ration levels for food and water |
| 2 | Roll 2d6 + ration bonuses. Under 12 → +2 unrest; under 20 → +1 unrest |
| 3 | Roll 1d6. If lower than current unrest, **lose population equal to the die value and skip step 4 this turn** |
| 4 | Charge up to N consoles |

**Jump Drive** is identical on all five: 1 strytium fuel for a short or medium
jump, 2 for long, drawn from the docked host.

Facilitator Guide: adding an extra ship makes the fleet stronger, so add roughly
**3 damage capacity of Wolf ships per extra role introduced**.

## `gorgoneion` — I.C.S.S. Gorgoneion

**Frigate.** Interstellar Council. Population 1,000. Charges 2 consoles.

| Console | Effect |
|---|---|
| Missile Array | Charged: roll 3 dice at **each** of Long, Medium and Short Range; 1 damage per 6+ / 5+ / 4+ respectively. No individual target may be damaged more than once per phase by this attack |
| Force Field Projector | Charged: before the Targeting step, choose 1 ship; at the end of the Wolf Attack it takes 2 less damage |
| Repair Drones | Charged: once per Coordination Phase, spend 3 materials from a ship to repair one of its consoles |
| Mission Support | Away Mission: before cards are dealt, look at the top 5 cards and put each back on the top or bottom of the deck |
| Jump Drive | 1 / 1 / 2 |

Rations — Food 0/3/5/8, Water 0/2/3/6.

**Notes.** Repair Drones at 3 materials undercuts the engineering shuttles' 4.
Mission Support is a strong deck-manipulation effect and worth watching in
playtest.

## `capybara` — S.A.N.S. Capybara

**Supply Ship.** South American Nations. Population 2,000. Charges 2 consoles.

| Console | Effect |
|---|---|
| Water Reclimator | Charged: 4 water |
| Hydroponics | Charged: 1 water → 4 food |
| Fuel Processor | Charged: spend up to 5 ore, 1 fuel per ore |
| Cargo transfer | Coordination Phase: transfer security teams, ore, fuel, food, water and materials to and from docked ships |
| Bulk Haulage | Away Mission: any resources gained from an opportunity you contributed a card to grant **1 additional resource of each type** |
| Jump Drive | 1 / 1 / 2 |

Rations — Food 0/3/5/8, Water 0/2/3/6.

**Notes.** The only vessel outside Refinery 124 that can convert ore to fuel.
Console names as printed: "Water Reclimator" is a typo for Reclamator — normalise
the ID but keep the display string faithful if you're reproducing the sheet.

## `warrior` — R.S.S. Warrior

**Salvage Vessel.** Rosal. Population 2,000. Charges **1** console.

| Console | Effect |
|---|---|
| Salvage Drones | After a Wolf Attack, if charged: roll 1 die for every damage dealt **by either side** during the attack; gain 1 material per 5+ |
| Repair Drones | Charged: once per Coordination Phase, spend 6 materials from one ship to repair up to **two** of its consoles |
| Cargo transfer | Coordination Phase: full resource transfer to and from docked ships |
| Reclamator | Away Mission: discard all your cards and salvage any 1 opportunity instead of anyone assigning cards to it. Gain either 1 material and 1 food, or 1 material and 1 water, **per card discarded** |
| Jump Drive | 1 / 1 / 2 |

Rations — Food 0/3/6/10, Water 0/2/4/7.

**Notes.** Only 1 console charge against 2 chargeable consoles, so the Warrior
always chooses between salvage and repair. Salvage Drones scale off *total*
attack damage including damage the fleet dealt, which makes a big battle
lucrative — check that in playtest.

## `vulcan` — P.V. Vulcan

**Prison Ship.** Proxima. Population 15,000. Charges 2 consoles.

| Console | Effect |
|---|---|
| Additional Labour | Charged: once per Coordination Phase, charge one console on another ship. Consoles with an immediate maintenance-cycle effect trigger now instead |
| Additional Labour | As above (two copies) |
| Laser Cannon | Charged: roll 2 dice at medium and short range, 1 damage each on a 4+ |
| Jump Drive | 1 / 1 / 2 |

Rations — Food 0/3/6/10, Water 0/2/4/7.

**Notes.** Two Additional Labour consoles and only 2 charges, so it can run both
but nothing else. The Captain's brief frames the prisoners as people to
rehabilitate, which is the role's tension — the mechanics reward using them.

## `voyage_33_0` — G.I.V. Voyage 33-0

**Damaged Star Cruiser.** Gliese. Population **40,000**. Charges **1** console.

| Console | Effect |
|---|---|
| Water Reclimator | Charged: 4 water |
| Hydroponics | Charged: 1 water → 4 food |
| Jump Drive | 1 / 1 / 2 |

Rations — Food 0/4/9/13, Water 0/4/7/10.

**Notes.** This is the **Approaching Vessel crisis** ship, not a general extra
ship. It arrives with 40,000 survivors — a 18% increase to the fleet population —
against 1 console charge and a ration table matching the Icebreaker's. It is
designed to be an enormous drain. The Refinery 124 team (fellow Gliese citizens)
and the Doctor replacement role are both briefed to want it brought along at all
costs. Whether it is real or a Wolf trap is a facilitator decision made on the
fly, so **the host console must be able to introduce or destroy it mid-game**.

---

# Small craft index

Full data in the shuttle implementation brief. Listed here so the registry is
complete.

| Craft | Type | Home ship | Operator |
|---|---|---|---|
| I.C.S.S. "Starlight" | Exploration Shuttle | AEGIS | Wing Commander |
| I.C.S.S. "Pallas" | Assault Shuttle | AEGIS | Executive Officer |
| I.C.S.S. Fighter Wing Alpha | Fighter Wing | AEGIS | Wing Commander |
| I.C.S.S. Fighter Wing Bravo | Fighter Wing | AEGIS | Wing Commander |
| F.S. "Philia" | Engineering Shuttle | Dione | Engineer |
| F.S.F. "Maliades" | Escort Fighter | Dione | Engineer |
| C.S.S. "Blacksmith" | Engineering Shuttle | Icebreaker | Engineer |
| C.S.S. "Highwall" | Mining Shuttle | Icebreaker | Miner |
| R.S.S. "Black Sheep" | Service Shuttle | Shepherd | Engineer |
| R.S.S. "Endeavour" | Science Shuttle | Shepherd | Scientist |
| P.S. "Condor" | Service Shuttle | Quellon | Engineer |
| P.S. "Hummingbird" | Exploration Shuttle | Quellon | Explorer |
| G.S. "Chacau" | Engineering Shuttle | Refinery 124 | Engineer |
| P.D.S. "Chepu" | Assault Shuttle | Refinery 124 | PDF Colonel |
| P.D.F. Escort Fighter Wing | Fighter Wing | Refinery 124 | PDF Commander |
| U.S. "Ally" | Engineering Shuttle | **unassigned** | JEU Engineer |
| U.S. "Wobbly" | Service Shuttle | **unassigned** | JEU Engineer |

The two Joint Engineering Union shuttles have no printed home ship. The JEU roles
replace the Engineer on two ships and move freely between them during Team Phase
— at 14–18 players the pairings are Quellon/Refinery and Shepherd/Icebreaker — so
the shuttles likely follow their operator rather than having a fixed berth.
Confirm before fixing a default.

---

# Cross-ship reference

## Jump costs

| Ship | Short | Medium | Long |
|---|---:|---:|---:|
| AEGIS | 2 | 3 | 6 |
| Dione | 2 | 4 | 8 |
| Quellon | 2 | 4 | 8 |
| Refinery 124 | 2 | 4 | 8 |
| Icebreaker | 3 | 6 | 12 |
| Shepherd | 3 | 6 | 12 |
| All Small Ships | 1 | 1 | 2 |

A full-fleet long jump costs **54 strytium fuel** against a starting stock of 23.
Fuel, not food, is the binding constraint in the early game.

## Reactor charges vs. console count

| Ship | Charges | Consoles | Always cold |
|---|---:|---:|---:|
| AEGIS | 5 | 13 | 8 |
| Dione | 4 | 8 | 4 |
| Icebreaker | 4 | 8 | 4 |
| Refinery 124 | 4 | 9 | 5 |
| Shepherd | 3 | 7 | 4 |
| Quellon | 3 | 7 | 4 |

Storage, Shuttle Bay and the Reactor itself don't take charge, so the practical
shortfall is smaller than the raw difference — but every ship is choosing what to
leave off every single turn. That choice is the core of the Team Phase and should
be front and centre in the terminal UI.

## Damage deck sizes

Each ship's deck is exactly its own console cards, so deck size equals console
count: AEGIS 13, Refinery 124 9, Dione 8, Icebreaker 8, Shepherd 7, Quellon 7.
The AEGIS's two Armoured Hull cards reshuffle on resolution rather than staying
out, so its effective deck never empties while a hull is intact.

## Nations

| Nation | Ship | Type |
|---|---|---|
| Interstellar Council | AEGIS, Gorgoneion | — |
| F.A.S. | Dione | Old Nation |
| C.P.A. | Icebreaker | Old Nation |
| S.A.N. | Capybara | Old Nation |
| Rosal | Shepherd, Warrior | New Nation (first to gain independence, from F.A.S.) |
| Proxima | Quellon, Vulcan | New Nation (peaceful independence) |
| Gliese | Refinery 124, Voyage 33-0 | New Nation (former Earth colony) |

## Open items

- Home ship for `ally` and `wobbly`.
- Refinery 124's printed length of "500 km" is a typo.
- Whether `voyage_33_0` should exist in `GameState` from setup (dormant) or be
  instantiated when the crisis fires. Dormant-from-setup is simpler and avoids a
  mid-game schema change.
- Small Ships "cannot take damage" — confirm this means immune to Wolf attack
  damage entirely, including being a valid target on the targeting table. The
  targeting table lists only the six core ships, which suggests they are never
  targeted at all.
