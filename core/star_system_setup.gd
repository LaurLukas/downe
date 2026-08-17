class_name StarSystemSetup
extends RefCounted

## Populates a fresh GameState with all 16 star systems (A-P).
##
## Deliberately data-only: this does not wire star system data into
## jump resolution or scout range checks. JumpResolver's pursuit-track
## consequence is a bool the host judges, not something computed from
## what a scout typed - CLAUDE.md constraint 1 forbids validating typed
## coordinates against real map data, and auto-deriving pursuit
## consequences from StarChart would be exactly that. Nothing in the
## engine tracks the fleet's actual current node yet either, which
## wiring scout range checks would also need - a separate piece of
## follow-up work, not silently done here. See TODO.md.
##
## Which of the three organiser charts (StarChart.CHART_ASSIGNMENTS) is
## in play for a given game is left to whoever wires that up; every
## StarChart lookup takes an explicit chart argument rather than
## GameState storing an unused default ahead of any code that reads it.

static func populate_star_systems(game_state: GameState) -> void:
	for letter: String in StarSystemDefinitions.all_letters():
		game_state.add_star_system(StarSystem.new(letter))
