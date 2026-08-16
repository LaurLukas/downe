extends TestCase

func test_parse_request_path_extracts_path() -> void:
	var request := "GET /app.js HTTP/1.1\r\nHost: example\r\n\r\n"
	assert_eq(NetServer._parse_request_path(request), "/app.js", "should extract the path from the request line")

func test_parse_request_path_defaults_to_root_on_malformed_request() -> void:
	assert_eq(NetServer._parse_request_path("garbage"), "/", "a malformed request line should default to /")
