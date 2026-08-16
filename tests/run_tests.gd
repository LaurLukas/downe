extends SceneTree

## Headless rules-engine test runner. Recursively runs every *_test.gd
## under res://tests/.
## Usage: godot --headless --script res://tests/run_tests.gd

const TEST_ROOT := "res://tests/"

func _init() -> void:
	var test_files: Array[String] = []
	_collect_test_files(TEST_ROOT, test_files)
	test_files.sort()

	var failures: Array[String] = []
	for path: String in test_files:
		var script: GDScript = load(path)
		var test_case: TestCase = script.new()
		for failure: String in test_case.run():
			failures.append("%s: %s" % [path.get_file(), failure])

	if failures.is_empty():
		print("All tests passed (%d file(s))." % test_files.size())
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL " + failure)
		printerr("%d failure(s)" % failures.size())
		quit(1)

static func _collect_test_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := dir_path + entry
			if dir.current_is_dir():
				_collect_test_files(full_path + "/", out)
			elif entry.ends_with("_test.gd"):
				out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
