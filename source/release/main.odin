package main

import app "../app"

main :: proc() {
	window := app.app_window_create()
	app.app_init(window)
	for app.app_should_run() {
		app.app_update()
		free_all(context.temp_allocator)
	}
	app.app_shutdown()
	app.app_window_destroy(window)
}
