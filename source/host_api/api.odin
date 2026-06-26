package host_api

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:time"

APP_NAME :: "plastella"
DLL_EXT :: "." + dynlib.LIBRARY_FILE_EXTENSION
DLL :: APP_NAME + DLL_EXT

App_API :: struct {
	lib:           dynlib.Library,
	version:       int,
	mod_time:      time.Time,
	init:          proc(),
	update:        proc(),
	shutdown:      proc(),
	should_run:    proc() -> bool,
	force_reload:  proc() -> bool,
	force_restart: proc() -> bool,
	memory:        proc() -> rawptr,
	hot_reloaded:  proc(m: rawptr),
	memory_size:   proc() -> int,
}

load_api :: proc(version: int) -> (api: App_API, ok: bool) {
	mod, mod_err := os.last_write_time_by_name(DLL)
	if mod_err != nil {fmt.eprintln("cannot stat", DLL, mod_err); return}

	copy_name := fmt.tprintf("./%s_%d%s", APP_NAME, version, DLL_EXT)
	data, read_err := os.read_entire_file(DLL, context.allocator)
	if read_err != nil do return
	defer delete(data)
	if os.write_entire_file(copy_name, data) != nil do return

	count, syms_ok := dynlib.initialize_symbols(&api, copy_name, "app_", "lib")
	if !syms_ok || count == 0 do return
	if !api_complete(api) {
		fmt.eprintln("dll missing exports - stale or misnamed build?")
		if api.lib != nil do dynlib.unload_library(api.lib)
		os.remove(copy_name)
		return
	}
	api.version = version
	api.mod_time = mod
	return api, true
}

api_complete :: proc(a: App_API) -> bool {
	a := a
	base := uintptr(&a)
	for field in reflect.struct_fields_zipped(App_API) {
		if reflect.type_kind(field.type.id) != .Procedure do continue
		if (^rawptr)(base + field.offset)^ == nil do return false
	}
	return true
}
