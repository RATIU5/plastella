package main

import app "../app"
import "core:dynlib"
import "core:fmt"
import "core:os"

main :: proc() {
	version := 0
	api, ok := app.load_api(version)
	assert(ok)

	version += 1

	api.init()

	for {
		api.update()

		mod, err := os.last_write_time_by_name(app.APP_NAME + app.DLL_EXT)
		if err == os.ERROR_NONE && mod != api.mod_time {
			reload(&api, &version)
		}

		free_all(context.temp_allocator)
	}
}

reload :: proc(api: ^app.App_API, version: ^int) {
	new_api, ok := app.load_api(version^)
	if !ok do return

	state := api.memory()
	old := api^

	api^ = new_api
	api.hot_reloaded(state)
	version^ += 1

	dynlib.unload_library(old.lib)
	err := os.remove(old.path)
	if err != os.ERROR_NONE {
		fmt.printfln("failed to delete old lib %s", old.path)
	}
}
