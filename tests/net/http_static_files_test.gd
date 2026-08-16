extends TestCase

func test_root_resolves_to_index() -> void:
	assert_eq(HttpStaticFiles.resolve_path("/"), "res://web/index.html", "/ should resolve to index.html")

func test_normal_path_resolves_under_web_root() -> void:
	assert_eq(HttpStaticFiles.resolve_path("/app.js"), "res://web/app.js", "a normal path should resolve under res://web/")

func test_query_string_is_stripped() -> void:
	assert_eq(HttpStaticFiles.resolve_path("/app.js?v=2"), "res://web/app.js", "query strings should be stripped before resolving")

func test_path_traversal_is_rejected() -> void:
	assert_eq(HttpStaticFiles.resolve_path("/../../secret.txt"), "", "parent-directory segments should be rejected")

func test_path_not_starting_with_slash_is_rejected() -> void:
	assert_eq(HttpStaticFiles.resolve_path("app.js"), "", "a request path must start with /")

func test_content_type_known_extension() -> void:
	assert_eq(HttpStaticFiles.content_type_for("res://web/app.js"), "text/javascript; charset=utf-8", "js should map to a javascript content type")

func test_content_type_unknown_extension_falls_back() -> void:
	assert_eq(HttpStaticFiles.content_type_for("res://web/data.bin"), HttpStaticFiles.DEFAULT_CONTENT_TYPE, "unknown extensions should fall back to octet-stream")

func test_build_response_header_shape() -> void:
	var header := HttpStaticFiles.build_response_header(200, "OK", "text/plain", 5)
	assert_true(header.begins_with("HTTP/1.1 200 OK\r\n"), "header should start with the status line")
	assert_true(header.find("Content-Length: 5") != -1, "header should include the content length")
