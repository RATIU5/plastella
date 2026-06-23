package app

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:time"

APP_NAME :: "app"
DLL_EXT :: ".dylib" when ODIN_OS == .Darwin else ".dll" when ODIN_OS == .Windows else ".so"
DLL_FILE :: APP_NAME + DLL_EXT

App_API :: struct {
	lib:                dynlib.Library,
	version:            int,
	mod_time:           time.Time,
	init:               proc(),
	update:             proc(),
	shutdown:           proc(),
	should_run:         proc() -> bool,
	force_reload:       proc() -> bool,
	force_restart:      proc() -> bool,
	memory:             proc() -> rawptr,
	hot_reloaded:       proc(m: rawptr),
	memory_size:        proc() -> int,
	memory_layout_hash: proc() -> u64,
}

App_Memory :: struct {
	counter: int,
}
mem: ^App_Memory

@(export)
app_init :: proc() {
	mem = new(App_Memory)
}

@(export)
app_update :: proc() {
	fmt.println("hello from app")
}

@(export)
app_shutdown :: proc() {
	free(mem)
	mem = nil
}

@(export)
app_memory :: proc() -> rawptr {
	return mem
}

@(export)
app_hot_reloaded :: proc(m: rawptr) {
	mem = (^App_Memory)(m)
}


load :: proc(version: int) -> (api: App_API, ok: bool) {
	dll := DLL_FILE

	mod, mod_err := os.last_write_time_by_name(dll)
	if mod_err != nil {
		fmt.eprintfln("cannot stat", dll, mod_err)
		return
	}

	copy_name := fmt.tprintf("%s_%d%s", APP_NAME, version, DLL_EXT)
	data, read_err := os.read_entire_file(dll, context.allocator)
	if read_err != nil do return
	defer delete(data)
	if os.write_entire_file(copy_name, data) != nil do return

	count, syms_ok := dynlib.initialize_symbols(&api, copy_name, "app_", "lib")
	if !syms_ok || count == 0 do return

	api.version = version
	api.mod_time = mod
	return api, true
}
