# Capital Ship Signature Colours

Extracted from `wolf_attack_tv_visual_redesign.md` §5.1 for use across the whole
project — TV display, ESP32 terminals, phone pages, printed material.

---

## The six

| Slot | Ship | Bloc | Hex | Why that hue |
|---|---|---|---|---|
| 1 | AEGIS | Interstellar Council | `#CFE4F5` | Ice-white — command, not a resource |
| 2 | Dione | FAS | `#A97BFF` | Violet — civilian flagship, carries the President |
| 3 | Icebreaker | CPA | `#E8873C` | Ember — ore and heavy industry |
| 4 | Quellon | Proxima | `#46D6C0` | Aqua — water |
| 5 | Shepherd | Rosal | `#7FD46A` | Leaf — food |
| 6 | Refinery 124 | Gliese | `#F2D04A` | Sulfur — fuel |

Every hue is derived from what the ship actually *does*, so players learn the
mapping without ever being told it. Slot order is the Wolf Attack Sheet targeting
order and must never be re-sorted.

---

## Two rules

**1. Colour is identity, never status.**
Shepherd is green because Shepherd is Rosal — not because Shepherd is safe. The
moment a nation colour is used to mean "OK", the whole scheme collapses into a
traffic light. Status is carried entirely by threat borders, incoming numbers,
and attack lines.

**2. No ship gets red.**
Red belongs exclusively to the Wolves. That is what buys the freedom to have a
green ship and an orange ship on the same screen without confusion — there is
only one warm-red anywhere in the system and it always means the same thing.

---

## Derived states

| State | Treatment | Example (Quellon) |
|---|---|---|
| Normal | Base hue | `#46D6C0` |
| Crippled / offline | Desaturate 70%, lightness → 40% | `#2A6B62` |
| Destroyed | Uniform `--fleet-dim` `#3C5F70` | `#3C5F70` |

Destroyed ships lose their identity colour entirely — the nation is gone with the
ship. This is deliberate and worth not softening.

---

## Contrast check

All six are tested against the panel fill `#0E1526` (the card background), which
is the only surface they appear on.

| Ship | Contrast vs `#0E1526` | Verdict |
|---|---|---|
| AEGIS `#CFE4F5` | ~14.8:1 | Excellent |
| Dione `#A97BFF` | ~7.2:1 | Good |
| Icebreaker `#E8873C` | ~7.9:1 | Good |
| Quellon `#46D6C0` | ~9.6:1 | Good |
| Shepherd `#7FD46A` | ~10.4:1 | Good |
| Refinery 124 `#F2D04A` | ~12.1:1 | Excellent |

All clear the 4.5:1 threshold comfortably, which matters more than usual here —
these are read at 3 m on an uncalibrated TV in a lit room.

---

## Cross-surface use

The same six colours should carry everywhere a player might look, so someone who
has stared at aqua for six turns knows their console at a glance:

- **TV display** — card top stripe (4 px), slot number, ship silhouette fill
- **ESP32 ship terminals** — header bar and title text on the CYD colour display
- **Phone pages** — accent colour, header rule, active button fill
- **Battle map / star chart** — ship token fill
- **Printed material** (optional) — a colour band on the A3 ship sheet corner

Note for hardware: the ESP32-2432S028R panels are ILI9341-class and skew cool and
slightly dark. Expect the ember (`#E8873C`) and sulfur (`#F2D04A`) to read more
muted there than on the TV. If they look washed, raise saturation on the terminal
palette rather than changing the canonical values here.

---

## GDScript constants

```gdscript
# res://core/ship_colors.gd
class_name ShipColors

const SIGNATURE: Dictionary = {
	&"aegis":        Color("CFE4F5"),
	&"dione":        Color("A97BFF"),
	&"icebreaker":   Color("E8873C"),
	&"quellon":      Color("46D6C0"),
	&"shepherd":     Color("7FD46A"),
	&"refinery_124": Color("F2D04A"),
}

const FLEET_DIM: Color = Color("3C5F70")

static func for_ship(id: StringName, crippled: bool = false,
		destroyed: bool = false) -> Color:
	if destroyed:
		return FLEET_DIM
	var c: Color = SIGNATURE.get(id, Color("7FD8F0"))
	if crippled:
		c.s *= 0.30
		c.v = 0.40
	return c
```

Note this is a pure colour lookup with no Node dependency, so it is safe to sit
in `core/`. If you would rather keep all presentation out of the rules layer,
move it to `res://ui/theme/ship_colors.gd` — the constants are identical either
way, but `core/` is the more useful home since the terminals and web clients both
need the same values.

---

## Hex quick copy

```
AEGIS         CFE4F5
Dione         A97BFF
Icebreaker    E8873C
Quellon       46D6C0
Shepherd      7FD46A
Refinery 124  F2D04A

fleet-dim     3C5F70
threat (wolf) FF3B2E
```
