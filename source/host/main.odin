package main

import "../app"
import "core:dynlib"

main :: proc() {
	lib, ok := dynlib.load_library(app.DLL_FILE)
	assert(ok, "could not load the app library")

	ptr, found := dynlib.symbol_address(lib, "app_update")
	assert(found, "app_update not exported")

	(cast(proc())ptr)()
	dynlib.unload_library(lib)
}
