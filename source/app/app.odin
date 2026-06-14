package app

import api "../api"
import editor "../editor"
import platform "../platform"
import ui "../ui"

am: ^api.App_Memory

@(export)
app_update :: proc() {
	// Nothing visible: skip the whole UI frame but keep the OS event queue
	// serviced so the window can be restored.
	if platform.window_minimized() {
		platform.idle_pump_events()
		return
	}

	platform.poll_input(&am.input)

	// Game simulation (fixed timestep) will go here, before the UI frame.

	// Single-pass UI: builds, handles input, and draws in one go. Runs before
	// window drag so UI gets first claim on the mouse; window drag only fires
	// if nothing in the editor captured it (cf. Dear ImGui's io.WantCaptureMouse).
	editor.frame(&am.input)
	platform.handle_window_drag(&am.input)
	platform.apply_cursor(&am.input)

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
	am.ui_ctx = ui.init_clay()
	am.editor = editor.init()
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
	editor.shutdown()
	ui.shutdown_clay()
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
	// Re-point clay's context and font tables, which the new DLL zeroed out.
	ui.reload(am.ui_ctx)
	editor.reload(am.editor)
}

@(export)
app_force_reload :: proc() -> bool {
	return platform.is_force_reload_pressed()
}

@(export)
app_force_restart :: proc() -> bool {
	return platform.is_force_restart_pressed()
}
