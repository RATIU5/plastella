package app

import "core:dynlib"
import "core:fmt"

APP_NAME :: "plastella"
DLL_EXT :: ".dylib" when ODIN_OS == .Darwin else ".dll" when ODIN_OS == .Windows else ".so"

App_API :: struct {
	lib:      dynlib.Library,
	init:     proc(),
	update:   proc(),
	shutdown: proc(),
}

App_Memory :: struct {
	counter: int,
}

mem: ^App_Memory

load :: proc() -> (api: App_API, ok: bool) {
	count, _ := dynlib.initialize_symbols(&api, APP_NAME + DLL_EXT, "app_", "lib")
	return api, count > 0
}

@(export)
app_init :: proc() {
	mem = new(App_Memory)
}

@(export)
app_update :: proc() {
	mem.counter += 1
	fmt.printfln("counter: %d", mem.counter)
}

@(export)
app_shutdown :: proc() {
	free(mem)
}

@(export)
app_memory :: proc() -> rawptr {
	return mem
}

app_hot_reloaded :: proc(m: rawptr) {
	mem = (^App_Memory)(m)
}
