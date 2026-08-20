class_name RollText
extends RefCounted

## Server-side human-readable outcome sentence for a stamped roll
## result - docs/dice_engine_spec.md §7: "text is a short human-readable
## outcome computed server-side, so the ESP32 firmware does not need to
## embed rules logic." Kept as its own tiny file rather than folded
## into RollService: RollService itself only owns the generic stamp/
## log/broadcast mechanics (see its own comment) and stays reason-
## agnostic beyond dispatch; this is exactly the per-reason game
## meaning layered on top, and it only needs to read a stamped result
## dict, nothing from GameState.

## Reads generic shape fields (band/successes) rather than a caller-
## stamped extra (unrest_gain/hits) wherever the two are equivalent -
## that keeps text correct for an overridden roll too, whose recomputed
## dict (RollService.override_roll()) only carries what Dice.
## classify_*() derives, not whatever a caller's original augment
## callback happened to add. "damaged" (maintenance_riot) is the one
## exception - it's a genuine external-context comparison (against the
## ship's unrest), not derivable from the roll shape alone, so an
## override of that reason needs its own augment supplying it fresh -
## see ui/host/host_console.gd's Dice Log override control.
static func describe(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"maintenance_unrest":
			# Mirrors MaintenanceCycle.UNREST_THRESHOLDS' band meaning
			# ([12, 20]: band 0 -> +2, band 1 -> +1, band 2 -> nothing).
			# Kept as a small literal mapping here, not a MaintenanceCycle
			# reference, so this stays a generic "describe any stamped
			# roll" helper rather than depending on one reason's owning
			# module.
			var gain := 0
			match int(result.get("band", -1)):
				0: gain = 2
				1: gain = 1
			if gain > 0:
				return "+%d unrest" % gain
			return "no unrest gained"
		"maintenance_riot":
			if result.get("damaged", false):
				return "riot - draw a card and mark that console damaged"
			return "no riot damage"
		"weapon_fire":
			var hits: int = result.get("successes", 0)
			return "%d hit%s" % [hits, "" if hits == 1 else "s"]
		_:
			return ""
