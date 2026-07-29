package main

import app "../app"
import platform "../platform"
import "core:fmt"

#assert(ODIN_OS == .Darwin, "macOS-only support at this time")

main :: proc() {
	device := app.app_device_create()
	if device == nil {
		fmt.eprintf("failed to create device")
		return
	}
	app.app_init(device)
	for app.app_should_run() {
		app.app_update(device)
		free_all(context.temp_allocator)
	}
	app.app_shutdown()
	app.app_device_destroy(device)
}
