# Wolf Attack — Damage Ladder (handoff)

Open `Wolf Attack Damage Ladder.dc.html` in a browser. `support.js` must sit beside it.
All ship art is inline SVG `<symbol>` — no external image requests, no `svg/` folder needed.

## What this build changes
Replaces `PREVENTS N` (v3) with the four-cell damage ladder, per `spec/wolf_attack_damage_ladder.md`.

- **Ladder** `L · M · S · ✕` on every wolf token. Cell = total damage dealt if destroyed in that
  phase; 4th cell = damage if never destroyed.
  Current phase boxed in CYAN, passed phases INK_GHOST, future INK_DIM, survives always ALERT.
  `BS` renders `—` at Short (cannot be damaged), never a number.
- **Badges** replace the named ability line: `↻` returns, `4BP` (pulses at Boarding),
  `+N` live Wolf FW buff on `SC`, `⊘S` on `BS` at Tier A only.
- **Lane incoming** is a range, not a projection: `▼ ceiling` + `MIN floor`, with a bar above the
  fleet card — solid ALERT = unpreventable floor, outlined = still preventable this phase.
  Legend sits bottom-centre. No attackers: `NO CONTACT`, no bar.
- **Phase behaviour**: targeting = no cell boxed; long/medium/short = current cell boxed;
  boarding = ladder at 0.4 alpha, BP badges forward; resolve = realised cell in CYAN, rest ghosted.

## Ladder degradation by tier
| Tier | max stack | Token | Ladder |
|---|---|---|---|
| A | ≤ 2 | 118px, full art | 4 cells **with** `L M S ✕` headers |
| A | 3 | 100px, full art | 4 cells, no headers |
| B | 4–8 | 36px row | 4 compact cells, current boxed |
| C | 9–16 | 30px row, 2 cols | `now ▸ survives` |
| D | 17+ | 26px row, 3 cols | survives only, ALERT |

Deviation from the spec: Tier A keeps full art at a 3-stack (headers drop instead), so the
common board still looks like the live game. Spec's `≤2` boundary applies to the headed form only.

## Damage source of truth (pure, portable to `res://core/wolf_damage.gd`)
```
bs [3, 3, null, 3]  returns
sc [2, 2, 2,    2]  fw_buff
cr [0, 1, 2,    3]
at [0, 0, 0,    0]  4 boarding parties
de [1, 1, 1,    2]
fw [0, 0, 1,    1]  returns
```
`damage_if_survives(fw) = 1 + live_fw_buff` — the `+1` per fighter wing belongs to the **FW** rows,
never added to `SC`'s own ceiling. `lane_floor` = Σ damage_if_destroyed_now,
`lane_ceiling` = Σ damage_if_survives.

## Tweaks
`scenario` (7 rosters, incl. the live board and each over-cap tier) and `phase` (6 phases).

## Held design line
No urgency labels, no recommended targets, no threat sorting. Token order stays descending hull
capacity, stable by uid. Facts and arithmetic on screen; judgment stays in the room.
