package main

import app "../app"

main :: proc() {
	api, ok := app.load()
	api.init()
	assert(ok, "no symbols found")
	for _ in 0 ..< 5 {
		api.update()
	}
	api.shutdown()
}
