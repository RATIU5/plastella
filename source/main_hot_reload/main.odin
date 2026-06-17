package main

import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:time"

when ODIN_OS == .Windows {
	DLL_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	DLL_EXT :: ".dylib"
} else {
	DLL_EXT :: ".so"
}

// Empty: the host chdirs to its own directory on startup, and the build places
// the DLL right next to the executable (build/hot_reload/), so the DLL is found
// relative to the exe regardless of where the project lives.
APP_DLL_DIR :: ""
APP_DLL_PATH :: APP_DLL_DIR + "app" + DLL_EXT

copy_dll :: proc(to: string) -> bool {
	copy_err := os.copy_file(to, APP_DLL_PATH)

	if copy_err != nil {
		fmt.printfln("Failed to copy " + APP_DLL_PATH + " to {0}: %v", to, copy_err)
		return false
	}
	return true
}

App_API :: struct {
	lib:               dynlib.Library,
	init_window:       proc(),
	init:              proc(),
	update:            proc(),
	should_run:        proc() -> bool,
	shutdown:          proc(),
	shutdown_window:   proc(),
	memory:            proc() -> rawptr,
	memory_size:       proc() -> int,
	memory_layout_hash: proc() -> u64,
	set_reload_status: proc(blocked: bool),
	hot_reloaded:      proc(mem: rawptr),
	force_reload:      proc() -> bool,
	force_restart:     proc() -> bool,
	modification_time: time.Time,
	api_version:       int,
}

load_app_api :: proc(api_version: int) -> (api: App_API, ok: bool) {
	mod_time, mod_time_err := os.last_write_time_by_name(APP_DLL_PATH)
	if mod_time_err != os.ERROR_NONE {
		fmt.printfln(
			"Failed getting last write time of " + APP_DLL_PATH + ", error code: {1}",
			mod_time_err,
		)
		return
	}

	app_dll_name := fmt.tprintf(APP_DLL_DIR + "app_{0}" + DLL_EXT, api_version)
	copy_dll(app_dll_name) or_return

	_, ok = dynlib.initialize_symbols(&api, app_dll_name, "app_", "lib")
	if !ok {
		fmt.printfln("Failed initializing symbols: {0}", dynlib.last_error())
	}

	api.api_version = api_version
	api.modification_time = mod_time
	ok = true

	return
}

unload_app_api :: proc(api: ^App_API) {
	if api.lib != nil {
		if !dynlib.unload_library(api.lib) {
			fmt.printfln("Failed unloading lib: {0}", dynlib.last_error())
		}
	}

	if os.remove(fmt.tprintf(APP_DLL_DIR + "app_{0}" + DLL_EXT, api.api_version)) != nil {
		fmt.printfln(
			"Failed to remove {0}app_{1}" + DLL_EXT + " copy",
			APP_DLL_DIR,
			api.api_version,
		)
	}
}

main :: proc() {
	exec_path := os.args[0]
	exec_dir := filepath.dir(string(exec_path))
	os.set_working_directory(exec_dir)

	context.logger = log.create_console_logger()

	default_allocator := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false

		for _, value in a.allocation_map {
			log.errorf("%v: Leaked %v bytes\n", value.location, value.size)
			err = true
		}

		mem.tracking_allocator_clear(a)
		return err
	}

	app_api_version := 0
	app_api, app_api_ok := load_app_api(app_api_version)

	if !app_api_ok {
		fmt.printfln("Failed to load app api")
		return
	}

	app_api_version += 1
	app_api.init_window()
	app_api.init()

	old_app_apis := make([dynamic]App_API, default_allocator)
	reload_blocked := false

	for app_api.should_run() {
		app_api.update()
		force_reload := app_api.force_reload()
		force_restart := app_api.force_restart()
		reload := force_reload || force_restart
		app_dll_mod, app_dll_mod_err := os.last_write_time_by_name(APP_DLL_PATH)

		if app_dll_mod_err == os.ERROR_NONE && app_api.modification_time != app_dll_mod {
			reload = true
		}

		if reload {
			new_app_api, new_app_api_ok := load_app_api(app_api_version)

			if new_app_api_ok {
				// The persistent-state layout differs when the new DLL reports a
				// different App_Memory size or a different layout fingerprint (the
				// latter catches changes to heap structs reached through rawptr,
				// which the size alone misses).
				incompatible :=
					app_api.memory_size() != new_app_api.memory_size() ||
					app_api.memory_layout_hash() != new_app_api.memory_layout_hash()

				if incompatible && !force_restart {
					// Can't hot-reload (stale bytes) and won't silently restart
					// (would wipe unsaved in-memory state). Hold the OLD code +
					// memory, raise the HUD, and wait for an explicit restart.
					if !reload_blocked {
						log.warn(
							"App_Memory layout changed — clean hot reload impossible. " +
							"Save, then press the force-restart key.",
						)
					}
					reload_blocked = true
					app_api.set_reload_status(true)
					// Adopt the new mod time so this doesn't re-fire every frame,
					// and drop the freshly loaded DLL: we keep running the old one.
					app_api.modification_time = new_app_api.modification_time
					unload_app_api(&new_app_api)
				} else if force_restart {
					// Full restart without restarting executable
					app_api.shutdown()
					reset_tracking_allocator(&tracking_allocator)

					for &a in old_app_apis {
						unload_app_api(&a)
					}

					clear(&old_app_apis)
					unload_app_api(&app_api)
					app_api = new_app_api
					app_api.init()
					reload_blocked = false
					app_api_version += 1
				} else {
					// Normal hot reload
					append(&old_app_apis, app_api)
					app_memory := app_api.memory()
					app_api = new_app_api
					app_api.hot_reloaded(app_memory)
					app_api.set_reload_status(false)
					reload_blocked = false
					app_api_version += 1
				}
			}
		}

		if len(tracking_allocator.bad_free_array) > 0 {
			for b in tracking_allocator.bad_free_array {
				log.errorf("Bad free at: %v", b.location)
			}

			libc.getchar()
			panic("Bad free detected")
		}
	}

	free_all(context.temp_allocator)
	app_api.shutdown()
	if reset_tracking_allocator(&tracking_allocator) {
		libc.getchar()
	}

	for &a in old_app_apis {
		unload_app_api(&a)
	}

	delete(old_app_apis)

	app_api.shutdown_window()
	unload_app_api(&app_api)
	mem.tracking_allocator_destroy(&tracking_allocator)
}

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
