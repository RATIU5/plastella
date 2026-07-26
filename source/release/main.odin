package main

import "core:fmt"
import app "../app"

#assert(ODIN_OS == .Darwin, "macOS-only support at this time")

main :: proc() {
	window := app.app_window_create()
	if window == nil {
		fmt.eprintf("failed to create window")
		return
	}
	app.app_init(window)
	for app.app_should_run() {
		app.app_update()
		free_all(context.temp_allocator)
	}
	app.app_shutdown()
	app.app_window_destroy(window)
}
