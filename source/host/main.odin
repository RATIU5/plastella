package main

import "../app"
import "core:dynlib"

App_API :: struct {
	lib:      dynlib.Library,
	init:     proc(),
	update:   proc(),
	shutdown: proc(),
}

load :: proc() -> (api: App_API, ok: bool) {
	count, _ := dynlib.initialize_symbols(&api, app.DLL_FILE, "app_", "lib")
	return api, count > 0
}

main :: proc() {
	api, ok := load()

	(cast(proc())api.update)()
	dynlib.unload_library(api.lib)
}
