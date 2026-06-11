package app

import api "../api"
import platform "../platform"
import rl "vendor:raylib"

am: ^api.App_Memory

@(export)
app_update :: proc() {
	platform.handle_window_drag()

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

@(export)
app_init_window :: proc() {
	platform.init_window()
}

@(export)
app_init :: proc() {
	am = new(api.App_Memory)

	am^ = api.App_Memory {
		run = true,
	}

	app_hot_reloaded(am)
}

@(export)
app_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		if platform.window_should_close() {
			return false
		}
	}

	return am.run
}

@(export)
app_shutdown :: proc() {
	free(am)
}

@(export)
app_shutdown_window :: proc() {
	platform.shutdown_window()
}

@(export)
app_memory :: proc() -> rawptr {
	return am
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(api.App_Memory)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	am = (^api.App_Memory)(mem)
}

@(export)
app_force_reload :: proc() -> bool {
	return platform.is_force_reload_pressed()
}

@(export)
app_force_restart :: proc() -> bool {
	return platform.is_force_restart_pressed()
}
