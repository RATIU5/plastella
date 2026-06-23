package main

import "../app"
import "core:dynlib"
import "core:fmt"
import "core:os"

main :: proc() {
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
			hard_restart(&api, &version)
		case recompiled || api.force_reload():
			reload(&api, &version)
		}

		free_all(context.temp_allocator)
	}
	api.shutdown()
}

reload :: proc(api: ^app.App_API, version: ^int) {
	new_api, ok := app.load_api(version^ + 1)
	if !ok do return

	if new_api.memory_size() != api.memory_size() ||
	   new_api.memory_layout_hash() != api.memory_layout_hash() {
		fmt.eprintln("App_Memory layout changed - hard reset (state reset)")
		do_restart(api, version, new_api)
		return
	}

	state := api.memory()
	old := api^
	api^ = new_api
	api.hot_reloaded(state)
	version^ += 1

	dynlib.unload_library(old.lib)
	os.remove(fmt.tprintf("%s_%d%s", app.APP_NAME, old.version, app.DLL_EXT))
}

hard_restart :: proc(api: ^app.App_API, version: ^int) {
	new_api, ok := app.load_api(version^ + 1)
	if !ok do return
	do_restart(api, version, new_api)
}

@(private = "file")
do_restart :: proc(api: ^app.App_API, version: ^int, new_api: app.App_API) {
	api.shutdown()
	old := api^
	api^ = new_api
	api.init()
	version^ += 1
	dynlib.unload_library(old.lib)
	os.remove(fmt.tprintf("%s_%d%s", app.APP_NAME, old.version, app.DLL_EXT))
}
