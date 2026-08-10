package main

import "../app"
import "core:fmt"

#assert(ODIN_OS == .Darwin, "macOS-only support at this time")

main :: proc() {
	device := app.app_device_create()
	if device == nil {
		fmt.eprintfln("failed to create device")
		return
	}
	app_ok := app.app_init(device)

	defer app.app_device_destroy(device)
	defer app.app_shutdown()

	if !app_ok do return

	for app.app_should_run() {
		app.app_update(device)
		free_all(context.temp_allocator)
	}
}
