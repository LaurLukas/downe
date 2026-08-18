# Starting Resources

Source: *DoWNE Facilitator Guide v1.0.1*, page 5 ("Starting Resources").
Column headers in the printed table are icons; they are, left to right:
strytium ore (red gem), strytium fuel (fuel pump), food (green), water (droplet),
materials (grey diamond), security teams.

| Ship | Strytium Ore | Strytium Fuel | Food | Water | Materials | Security Teams |
|---|---:|---:|---:|---:|---:|---:|
| AEGIS | 0 | 4 | 8 | 6 | 1 | 9 |
| Dione | 0 | 3 | 13 | 14 | 0 | 2 |
| Icebreaker | 0 | 4 | 11 | 9 | 3 | 2 |
| Shepherd | 0 | 4 | 10 | 8 | 0 | 2 |
| Quellon | 0 | 3 | 10 | 8 | 0 | 2 |
| Refinery 124 | 12 | 5 | 9 | 4 | 0 | 6 |
| **Fleet total** | **12** | **23** | **61** | **49** | **4** | **23** |

Notes on the shape of this:

- Only Refinery 124 starts with strytium ore, and it is the only ship that can
  refine ore into fuel. The Icebreaker starts with none despite being the mining
  vessel — it generates ore via the Ram Scoop on jumps, not at setup.
- Materials are scarce at setup (4 across the whole fleet). Repairs cost 4
  materials per console, so the fleet cannot afford a single console repair on
  turn 1 without the Icebreaker's Mining Drone Control or the Highwall.
- The AEGIS holds 9 of the 23 security teams; Refinery 124 holds 6. The other
  four ships have 2 each.

## Machine-readable form

```gdscript
const STARTING_RESOURCES := {
    "aegis":        {"strytium_ore":  0, "strytium_fuel": 4, "food":  8, "water":  6, "materials": 1, "security_teams": 9},
    "dione":        {"strytium_ore":  0, "strytium_fuel": 3, "food": 13, "water": 14, "materials": 0, "security_teams": 2},
    "icebreaker":   {"strytium_ore":  0, "strytium_fuel": 4, "food": 11, "water":  9, "materials": 3, "security_teams": 2},
    "shepherd":     {"strytium_ore":  0, "strytium_fuel": 4, "food": 10, "water":  8, "materials": 0, "security_teams": 2},
    "quellon":      {"strytium_ore":  0, "strytium_fuel": 3, "food": 10, "water":  8, "materials": 0, "security_teams": 2},
    "refinery_124": {"strytium_ore": 12, "strytium_fuel": 5, "food":  9, "water":  4, "materials": 0, "security_teams": 6},
}
```

Key naming: the `CLAUDE.md` glossary lists the fifth resource as **material**
(singular) while the printed sheets say **materials**. Pick one and make it
consistent across the rules engine, the terminal firmware and the phone pages —
a mismatch here will silently drop transfers. This file uses `materials`.

## Starting survivor population

Not on page 5. Taken from the top value of each ship's Survivor Population track
on the A3 ship sheets. The Facilitator Guide's evacuation rule confirms the top
of the track is also the ceiling: no ship may exceed its starting population.

| Ship | Starting / max population | Crew capacity | Passenger capacity |
|---|---:|---:|---:|
| AEGIS | 2,500 | 3,000 | 100 |
| Dione | 100,000 | 4,000 | 12,000 |
| Icebreaker | 40,000 | 10,000 | 100 |
| Shepherd | 30,000 | 4,000 | 4,000 |
| Quellon | 30,000 | 6,500 | 10 |
| Refinery 124 | 20,000 | 5,000 | 0 |
| **Fleet total** | **222,500** | | |

Crew and passenger capacity are flavour on the ship sheets and do not constrain
the population track — the Dione carries 100,000 against a stated capacity of
16,000. Do not enforce capacity as a rule.

## Starting unrest

Every ship starts at unrest 0. At 8 or more, the facilitator is called (mutiny).

## Not specified in the source

- **Shuttle starting cargo.** The shuttle resource sheets have tick tracks but no
  setup values are given anywhere in the guide. Assume all shuttles start empty
  and unfuelled, but confirm before this reaches playtest.
- **Shuttle cargo caps.** No per-shuttle maximum is printed. Treat as uncapped
  until decided.
- **Ship hold caps.** Likewise none printed. Treat as uncapped.
- **Starting console state.** The guide does not say which consoles begin charged.
  The role briefs imply ships begin with consoles uncharged and run their first
  maintenance cycle in turn 1's Team Phase.
- **Starting fighter counts.** The wing tracks run 0–4 but no setup value is
  given. Full wings (4 each) is the likely intent given the Construction Bay
  exists to replace losses, but confirm.
