package app

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:time"

APP_NAME :: "plastella"
DLL_EXT :: ".dylib" when ODIN_OS == .Darwin else ".dll" when ODIN_OS == .Windows else ".so"

App_API :: struct {
	version:      int,
	path:         string,
	mod_time:     time.Time,
	lib:          dynlib.Library,
	init:         proc(),
	update:       proc(),
	shutdown:     proc(),
	memory:       proc() -> rawptr,
	hot_reloaded: proc(m: rawptr),
}

App_Memory :: struct {
	counter: int,
}

mem: ^App_Memory

load_api :: proc(version: int) -> (api: App_API, ok: bool) {
	mod, err := os.last_write_time_by_name(APP_NAME + DLL_EXT)
	if err != os.ERROR_NONE do return

	copy_name := fmt.tprintf(APP_NAME + "_%d" + DLL_EXT, version)
	if os.copy_file(copy_name, APP_NAME + DLL_EXT) != nil do return

	count, _ := dynlib.initialize_symbols(&api, copy_name, "app_", "lib")
	api.version = version
	api.mod_time = mod
	api.path = copy_name

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
