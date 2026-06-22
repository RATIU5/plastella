package main

import app "../app"
import "core:dynlib"

main :: proc() {
	api, ok := app.load()
	assert(ok, "no symbols found")

	api.update()
	dynlib.unload_library(api.lib)
}
