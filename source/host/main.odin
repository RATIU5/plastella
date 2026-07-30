package main

import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:reflect"
import "core:time"

APP_NAME :: "plastella"
DLL_EXT :: "." + dynlib.LIBRARY_FILE_EXTENSION
DLL :: APP_NAME + DLL_EXT

App_API :: struct {
	lib:                dynlib.Library,
	version:            int,
	mod_time:           time.Time,
	device_create:      proc() -> rawptr,
	device_destroy:     proc(d: rawptr),
	init:               proc(d: rawptr) -> bool,
	update:             proc(d: rawptr),
	shutdown:           proc(),
	should_run:         proc() -> bool,
	force_reload:       proc() -> bool,
	force_restart:      proc() -> bool,
	memory:             proc() -> rawptr,
	hot_reloaded:       proc(m: rawptr),
	memory_size:        proc() -> int,
	memory_layout_hash: proc() -> u64,
}

#assert(ODIN_OS == .Darwin, "macOS-only support at this time")

/*
	This main can only run when `ODIN_DEBUG == true`
*/
main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	track.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for bad in track.bad_free_array do fmt.eprintfln("bad free at %v", bad.location)
		for _, leak in track.allocation_map do fmt.eprintfln("leaked %d bytes at %v", leak.size, leak.location)
		mem.tracking_allocator_destroy(&track)
	}

	version := 0
	api, ok := load_api(version)
	assert(ok, "could not load the app library")

	device := api.device_create()
	if device == nil {
		fmt.printf("Failed to create device")
		return
	}

	app_ok := api.init(device)

	defer api.device_destroy(device)
	defer api.shutdown()

	if !app_ok do return

	for api.should_run() {
		api.update(device)
		mod, err := os.last_write_time_by_name(DLL)
		recompiled := err == nil && mod != api.mod_time

		switch {
		case api.force_restart():
			hard_restart(&api, &version, &track, device)
		case recompiled || api.force_reload():
			reload(&api, &version, &track)
		}

		free_all(context.temp_allocator)
	}
}

@(require_results)
load_api :: proc(version: int) -> (api: App_API, ok: bool) {
	mod, mod_err := os.last_write_time_by_name(DLL)
	if mod_err != nil {
		fmt.eprintln("cannot stat", DLL, mod_err); return
	}

	copy_name := fmt.tprintf("./%s_%d%s", APP_NAME, version, DLL_EXT)
	data, read_err := os.read_entire_file(DLL, context.allocator)
	if read_err != nil do return
	defer delete(data)
	if os.write_entire_file(copy_name, data) != nil do return

	count, syms_ok := dynlib.initialize_symbols(&api, copy_name, "app_", "lib")
	if !syms_ok || count == 0 {
		os.remove(copy_name)
		return
	}
	if !api_complete(api) {
		fmt.eprintln("dll missing exports — stale or misnamed build?")
		if api.lib != nil do dynlib.unload_library(api.lib)
		os.remove(copy_name)
		return
	}
	api.version = version
	api.mod_time = mod
	return api, true
}

// Reject a partially-bound dll: initialize_symbols leaves missing procs nil and still
// returns ok. Reflection means this never needs editing as the contract grows.
@(require_results)
api_complete :: proc(a: App_API) -> bool {
	a := a
	base := uintptr(&a)
	for field in reflect.struct_fields_zipped(App_API) {
		if reflect.type_kind(field.type.id) != .Procedure do continue
		if (^rawptr)(base + field.offset)^ == nil do return false
	}
	return true
}

reload :: proc(api: ^App_API, version: ^int, track: ^mem.Tracking_Allocator) {
	new_api, ok := load_api(version^ + 1)
	if !ok do return

	incompatible :=
		new_api.memory_size() != api.memory_size() ||
		new_api.memory_layout_hash() != api.memory_layout_hash()

	if incompatible {
		fmt.eprintfln(
			"persistent memory layout changed - hot reload blocked; press F6 to restart (state will reset)",
		)
		api.mod_time = new_api.mod_time
		dynlib.unload_library(new_api.lib)
		os.remove(fmt.tprintf("%s_%d%s", APP_NAME, new_api.version, DLL_EXT))
		return
	}

	state := api.memory()
	old := api^
	api^ = new_api
	api.hot_reloaded(state)
	version^ += 1
	dynlib.unload_library(old.lib)
	os.remove(fmt.tprintf("%s_%d%s", APP_NAME, old.version, DLL_EXT))
	check_reload_leaks(track)
}

hard_restart :: proc(
	api: ^App_API,
	version: ^int,
	track: ^mem.Tracking_Allocator,
	device: rawptr,
) {
	new_api, ok := load_api(version^ + 1)
	if !ok do return
	do_restart(api, version, new_api, track, device)
}

do_restart :: proc(
	api: ^App_API,
	version: ^int,
	new_api: App_API,
	track: ^mem.Tracking_Allocator,
	device: rawptr,
) {
	api.shutdown()
	old := api^
	api^ = new_api
	app_ok := api.init(device)
	if app_ok {
		version^ += 1
		dynlib.unload_library(old.lib)
		os.remove(fmt.tprintf("%s_%d%s", APP_NAME, old.version, DLL_EXT))
	}
	check_reload_leaks(track)
}

check_reload_leaks :: proc(track: ^mem.Tracking_Allocator) {
	for bad in track.bad_free_array do fmt.eprintfln("bad free during reload at %v", bad.location)
	clear(&track.bad_free_array)
	fmt.eprintfln("live allocations after reload: %d", len(track.allocation_map))
}
