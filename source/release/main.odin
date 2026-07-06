package main

import app "../app"

main :: proc() {
	app.app_init()
	for app.app_should_run() {
		app.app_update()
		free_all(context.temp_allocator)
	}
	app.app_shutdown()
}
