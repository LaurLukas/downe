extends TestCase

func test_index_html_exists() -> void:
	assert_true(FileAccess.file_exists("res://web/index.html"), "web/index.html should exist so HttpStaticFiles can serve it")

func test_app_js_exists() -> void:
	assert_true(FileAccess.file_exists("res://web/app.js"), "web/app.js should exist")

func test_style_css_exists() -> void:
	assert_true(FileAccess.file_exists("res://web/style.css"), "web/style.css should exist")

func test_resolve_path_root_points_to_an_existing_file() -> void:
	var resolved := HttpStaticFiles.resolve_path("/")
	assert_true(FileAccess.file_exists(resolved), "HttpStaticFiles.resolve_path('/') should point at a file that actually exists")
