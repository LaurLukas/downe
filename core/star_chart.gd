class_name StarChart
extends RefCounted

## The jump graph: 22 nodes (`0000` plus 21 lettered systems), one
## fixed topology shared by three "organiser chart" variants that
## differ only in which system letter sits on which node -
## open_questions_answered.md §1.1. Which variant is in play is a
## setup-time host choice (matching the physical game's three printed
## charts), not something core/ decides - see StarSystemSetup.
##
## Transcribed from Chart A's artwork; the source doc itself flags this
## as unverified against the printed original ("a missed line here
## would silently break scout range checks") and asks for a symmetry
## test, which tests/core/star_chart_test.gd provides. That test can
## catch a transcription error that breaks symmetry; it cannot catch
## one that doesn't (a wrong-but-symmetric edge). Re-check against the
## physical chart before relying on this for a real game.

const START := "0000"

## coordinate -> pursuit reduction for jumping there (negative). 0000
## has no entry - it's the start, not a destination.
const PURSUIT_BAND: Dictionary[String, int] = {
	"5143": -1, "1413": -1,
	"9997": -2, "6837": -2, "0488": -2,
	"6931": -3, "4454": -3,
	"4753": -4, "1096": -4, "6964": -4,
	# The band between -4 and -6 is unlabelled on all three printed
	# charts - by position it must be -5. Treated as a printing
	# omission per the source doc's own recommendation, not a guess
	# invented here.
	"2580": -5, "3068": -5, "0853": -5, "6943": -5,
	"6798": -6, "8378": -6, "1964": -6,
	"1380": -7, "1836": -7, "0408": -7, "4888": -7,
}

## coordinate -> adjacent coordinates. Both directions are listed
## explicitly (not derived) so the symmetry test actually exercises
## the transcription rather than assuming it.
const EDGES: Dictionary[String, Array] = {
	"0000": ["5143", "1413"],
	"5143": ["0000", "1413", "9997", "6837"],
	"1413": ["0000", "5143", "6837", "0488"],
	"9997": ["5143", "6931"],
	"6837": ["5143", "1413", "0488", "6931", "4454"],
	"0488": ["1413", "6837", "4454"],
	"6931": ["9997", "6837", "4454", "4753", "1096"],
	"4454": ["6837", "0488", "6931", "1096", "6964"],
	"4753": ["2580", "3068", "1096", "6931"],
	"1096": ["6931", "4454", "4753", "3068", "0853", "6964"],
	"6964": ["4454", "1096", "0853", "6943"],
	"2580": ["6798", "4753"],
	"3068": ["6798", "8378", "0853", "4753", "1096"],
	"0853": ["8378", "1964", "3068", "1096", "6964"],
	"6943": ["1964", "6964"],
	"6798": ["1380", "1836", "2580", "3068"],
	"8378": ["1836", "0408", "1964", "3068", "0853"],
	"1964": ["8378", "0408", "4888", "0853", "6943"],
	"1380": ["1836", "6798"],
	"1836": ["1380", "6798", "8378"],
	"0408": ["8378", "4888", "1964"],
	"4888": ["0408", "1964"],
}

## chart letter ("A", "B", "C") -> {coordinate -> system letter}.
## "0000" is always the start, listed here as "START" for completeness.
##
## Chart A's "1964" entry was originally transcribed as "P" (a
## duplicate - "4888" is also "P" on chart A), which put chart A at 3 M
## and 2 P against docs/star_charts.json's variant_summary of 4 L/4 M/
## one each of N,O,P. Corrected to "M" per that JSON's cross-check;
## every other node on every other chart already matched it exactly.
const CHART_ASSIGNMENTS: Dictionary[String, Dictionary] = {
	"A": {
		"0000": "START",
		"5143": "L", "1413": "A", "9997": "C", "6837": "D", "0488": "L",
		"6931": "L", "4454": "M", "4753": "E", "1096": "I", "6964": "G",
		"2580": "F", "3068": "M", "0853": "L", "6943": "K",
		"6798": "N", "8378": "J", "1964": "M",
		"1380": "M", "1836": "H", "0408": "O", "4888": "P",
	},
	"B": {
		"0000": "START",
		"5143": "E", "1413": "L", "9997": "L", "6837": "B", "0488": "L",
		"6931": "I", "4454": "L", "4753": "K", "1096": "F", "6964": "J",
		"2580": "G", "3068": "M", "0853": "M", "6943": "L",
		"6798": "M", "8378": "M", "1964": "P",
		"1380": "O", "1836": "M", "0408": "N", "4888": "H",
	},
	"C": {
		"0000": "START",
		"5143": "L", "1413": "L", "9997": "D", "6837": "E", "0488": "C",
		"6931": "L", "4454": "L", "4753": "G", "1096": "M", "6964": "I",
		"2580": "J", "3068": "H", "0853": "M", "6943": "F",
		"6798": "N", "8378": "O", "1964": "K",
		"1380": "M", "1836": "M", "0408": "M", "4888": "P",
	},
}

## Screen-layout position per node: u = depth from START (0 = start, 1 =
## deepest tier), v = lateral position on the paper (0 = left edge, 1 =
## right edge). Same for all three chart variants - only the letters
## differ. Sourced from docs/star_charts.json's "nodes" array (pixel
## analysis of the printed charts), not re-derived here - see that
## file's own "coordinate_space" note for the rotation convention ui/
## applies (paper rotated 90° clockwise: screen x from u, screen y from
## v - docs/star_map_tv_display.md §5.1).
const NODE_POSITION: Dictionary[String, Vector2] = {
	"0000": Vector2(0.0, 0.509),
	"1413": Vector2(0.1198, 0.6372),
	"5143": Vector2(0.1937, 0.3038),
	"0488": Vector2(0.2595, 0.8231),
	"6837": Vector2(0.282, 0.5064),
	"9997": Vector2(0.3126, 0.1077),
	"6931": Vector2(0.4099, 0.3141),
	"4454": Vector2(0.4369, 0.7026),
	"1096": Vector2(0.5414, 0.441),
	"4753": Vector2(0.564, 0.141),
	"6964": Vector2(0.564, 0.8795),
	"3068": Vector2(0.6676, 0.2782),
	"6943": Vector2(0.6676, 1.0),
	"0853": Vector2(0.6892, 0.6385),
	"2580": Vector2(0.7108, 0.0),
	"1964": Vector2(0.7946, 0.8462),
	"6798": Vector2(0.8216, 0.1141),
	"8378": Vector2(0.8459, 0.541),
	"4888": Vector2(0.9279, 0.9744),
	"1380": Vector2(0.9297, 0.009),
	"1836": Vector2(0.9514, 0.3038),
	"0408": Vector2(1.0, 0.6731),
}

static func node_position(coordinate: String) -> Vector2:
	return NODE_POSITION.get(coordinate, Vector2.ZERO)

static func all_coordinates() -> Array[String]:
	var coordinates: Array[String] = [START]
	coordinates.append_array(PURSUIT_BAND.keys())
	return coordinates

static func neighbors_of(coordinate: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(EDGES.get(coordinate, []))
	return result

## Negative int, or 0 if the coordinate isn't a recognized destination
## (including 0000, which is never a jump target).
static func pursuit_reduction_at(coordinate: String) -> int:
	return PURSUIT_BAND.get(coordinate, 0)

static func system_letter_at(chart: String, coordinate: String) -> String:
	return CHART_ASSIGNMENTS.get(chart, {}).get(coordinate, "")

## Coordinate of the node carrying system_letter on the given chart, or
## "" if that letter doesn't appear on this chart (e.g. "B" on chart A -
## "A has no B" per the source doc).
static func coordinate_of_system(chart: String, system_letter: String) -> String:
	for coordinate: String in CHART_ASSIGNMENTS.get(chart, {}):
		if CHART_ASSIGNMENTS[chart][coordinate] == system_letter:
			return coordinate
	return ""

## Graph distance (fewest jumps) between two coordinates, or -1 if
## unreachable. Used for scout range checks ("within N jumps" means
## graph distance, not coordinate arithmetic - source doc §1.1).
static func graph_distance(from: String, to: String) -> int:
	if from == to:
		return 0
	var visited: Dictionary[String, bool] = {from: true}
	var frontier: Array[String] = [from]
	var distance := 0
	while not frontier.is_empty():
		distance += 1
		var next_frontier: Array[String] = []
		for coordinate: String in frontier:
			for neighbor: String in neighbors_of(coordinate):
				if visited.has(neighbor):
					continue
				if neighbor == to:
					return distance
				visited[neighbor] = true
				next_frontier.append(neighbor)
		frontier = next_frontier
	return -1
