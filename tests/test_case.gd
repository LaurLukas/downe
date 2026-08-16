class_name TestCase
extends RefCounted

## Base class for res://tests/core/*_test.gd. Subclasses define methods
## named test_* with no arguments; run() calls each and collects failures.

var failures: Array[String] = []

func run() -> Array[String]:
	failures = []
	for method in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			call(method_name)
	return failures

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, expected, actual])
