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
GAME_DLL_DIR :: ""
GAME_DLL_PATH :: GAME_DLL_DIR + "game" + DLL_EXT

copy_dll :: proc(to: string) -> bool {
	copy_err := os.copy_file(to, GAME_DLL_PATH)

	if copy_err != nil {
		fmt.printfln("Failed to copy " + GAME_DLL_PATH + " to {0}: %v", to, copy_err)
		return false
	}
	return true
}

Game_API :: struct {
	lib:               dynlib.Library,
	init_window:       proc(),
	init:              proc(),
	update:            proc(),
	should_run:        proc() -> bool,
	shutdown:          proc(),
	shutdown_window:   proc(),
	memory:            proc() -> rawptr,
	memory_size:       proc() -> int,
	hot_reloaded:      proc(mem: rawptr),
	force_reload:      proc() -> bool,
	force_restart:     proc() -> bool,
	modification_time: time.Time,
	api_version:       int,
}

load_game_api :: proc(api_version: int) -> (api: Game_API, ok: bool) {
	mod_time, mod_time_err := os.last_write_time_by_name(GAME_DLL_PATH)
	if mod_time_err != os.ERROR_NONE {
		fmt.printfln(
			"Failed getting last write time of " + GAME_DLL_PATH + ", error code: {1}",
			mod_time_err,
		)
		return
	}

	game_dll_name := fmt.tprintf(GAME_DLL_DIR + "game_{0}" + DLL_EXT, api_version)
	copy_dll(game_dll_name) or_return

	_, ok = dynlib.initialize_symbols(&api, game_dll_name, "game_", "lib")
	if !ok {
		fmt.printfln("Failed initializing symbols: {0}", dynlib.last_error())
	}

	api.api_version = api_version
	api.modification_time = mod_time
	ok = true

	return
}

unload_game_api :: proc(api: ^Game_API) {
	if api.lib != nil {
		if !dynlib.unload_library(api.lib) {
			fmt.printfln("Failed unloading lib: {0}", dynlib.last_error())
		}
	}

	if os.remove(fmt.tprintf(GAME_DLL_DIR + "game_{0}" + DLL_EXT, api.api_version)) != nil {
		fmt.printfln(
			"Failed to remove {0}game_{1}" + DLL_EXT + " copy",
			GAME_DLL_DIR,
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

	game_api_version := 0
	game_api, game_api_ok := load_game_api(game_api_version)

	if !game_api_ok {
		fmt.printfln("Failed to load game api")
		return
	}

	game_api_version += 1
	game_api.init_window()
	game_api.init()

	old_game_apis := make([dynamic]Game_API, default_allocator)

	for game_api.should_run() {
		game_api.update()
		force_reload := game_api.force_reload()
		force_restart := game_api.force_restart()
		reload := force_reload || force_restart
		game_dll_mod, game_dll_mod_err := os.last_write_time_by_name(GAME_DLL_PATH)

		if game_dll_mod_err == os.ERROR_NONE && game_api.modification_time != game_dll_mod {
			reload = true
		}

		if reload {
			new_game_api, new_game_api_ok := load_game_api(game_api_version)

			if new_game_api_ok {
				force_restart =
					force_restart || game_api.memory_size() != new_game_api.memory_size()

				if !force_restart {
					// Normal hot reload
					append(&old_game_apis, game_api)
					game_memory := game_api.memory()
					game_api = new_game_api
					game_api.hot_reloaded(game_memory)
				} else {
					// Full restart without restarting executable
					game_api.shutdown()
					reset_tracking_allocator(&tracking_allocator)

					for &g in old_game_apis {
						unload_game_api(&g)
					}

					clear(&old_game_apis)
					unload_game_api(&game_api)
					game_api = new_game_api
					game_api.init()
				}

				game_api_version += 1
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
	game_api.shutdown()
	if reset_tracking_allocator(&tracking_allocator) {
		libc.getchar()
	}

	for &g in old_game_apis {
		unload_game_api(&g)
	}

	delete(old_game_apis)

	game_api.shutdown_window()
	unload_game_api(&game_api)
	mem.tracking_allocator_destroy(&tracking_allocator)
}

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
