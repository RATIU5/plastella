package app

import rl "vendor:raylib"

App_Memory :: struct {
	run: bool,
}

a: ^App_Memory

@(export)
app_update :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

@(export)
app_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Plastella")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(200)
	rl.SetExitKey(nil)
}

@(export)
app_init :: proc() {
	a = new(App_Memory)

	a^ = App_Memory {
		run = true,
	}

	app_hot_reloaded(a)
}

@(export)
app_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		if rl.WindowShouldClose() {
			return false
		}
	}

	return a.run
}

@(export)
app_shutdown :: proc() {
	free(a)
}

@(export)
app_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
app_memory :: proc() -> rawptr {
	return a
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(App_Memory)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	a = (^App_Memory)(mem)
}

@(export)
app_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
app_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
