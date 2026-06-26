package main

import "../app"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:os"

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	track.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for bad in track.bad_free_array do fmt.eprintfln("bad free at %v", bad.location)
		for _, leak in track.allocation_map do fmt.eprintfln("leaked %d bytes at %v", leak.size, leak.location)
		mem.tracking_allocator_destroy(&track)
	}

	version := 0
	api, ok := app.load_api(version)
	assert(ok, "could not load the app library")
	api.init()

	for api.should_run() {
		api.update()
		mod, err := os.last_write_time_by_name(app.DLL)
		recompiled := err == nil && mod != api.mod_time

		switch {
		case api.force_restart():
			hard_restart(&api, &version, &track)
		case recompiled || api.force_reload():
			reload(&api, &version, &track)
		}

		free_all(context.temp_allocator)
	}
	api.shutdown()
}

reload :: proc(api: ^app.App_API, version: ^int, track: ^mem.Tracking_Allocator) {
	new_api, ok := app.load_api(version^ + 1)
	if !ok do return

	if new_api.memory_size() != api.memory_size() {
		fmt.eprintln("App_Memory size changed — hard restart (state reset)")
		do_restart(api, version, new_api, track)
		return
	}

	state := api.memory()
	old := api^
	api^ = new_api
	api.hot_reloaded(state)
	version^ += 1
	dynlib.unload_library(old.lib)
	os.remove(fmt.tprintf("%s_%d%s", app.APP_NAME, old.version, app.DLL_EXT))
	check_reload_leaks(track)
}

@(private = "file")
hard_restart :: proc(api: ^app.App_API, version: ^int, track: ^mem.Tracking_Allocator) {
	new_api, ok := app.load_api(version^ + 1)
	if !ok do return
	do_restart(api, version, new_api, track)
}

@(private = "file")
do_restart :: proc(
	api: ^app.App_API,
	version: ^int,
	new_api: app.App_API,
	track: ^mem.Tracking_Allocator,
) {
	api.shutdown()
	old := api^
	api^ = new_api
	api.init()
	version^ += 1
	dynlib.unload_library(old.lib)
	os.remove(fmt.tprintf("%s_%d%s", app.APP_NAME, old.version, app.DLL_EXT))
	check_reload_leaks(track)
}

@(private = "file")
check_reload_leaks :: proc(track: ^mem.Tracking_Allocator) {
	for bad in track.bad_free_array do fmt.eprintfln("bad free during reload at %v", bad.location)
	clear(&track.bad_free_array)
	fmt.eprintfln("live allocations after reload: %d", len(track.allocation_map))
}
