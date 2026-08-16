extends SceneTree

## Headless rules-engine test runner.
## Usage: godot --headless --script res://tests/run_tests.gd

const TEST_DIR := "res://tests/core/"

func _init() -> void:
	var failures: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("No tests found at %s" % TEST_DIR)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with("_test.gd"):
			var script: GDScript = load(TEST_DIR + file_name)
			var test_case: TestCase = script.new()
			for failure: String in test_case.run():
				failures.append("%s: %s" % [file_name, failure])
		file_name = dir.get_next()
	dir.list_dir_end()

	if failures.is_empty():
		print("All tests passed.")
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL " + failure)
		printerr("%d failure(s)" % failures.size())
		quit(1)
