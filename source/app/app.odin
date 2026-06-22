package app

import api "../api"
import editor "../editor"
import platform "../platform"
import render "../render"
import ui "../ui"
import "base:runtime"

am: ^api.App_Memory

RELOAD_NOTICE_MSG ::
	"Code change needs a full restart (persistent state changed). " +
	"Save your work, then press F6 to restart."

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
		run          = true,
		render_state = render.render_init(),
		editor       = editor.init(),
	}
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
	render.render_shutdown()
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
	render.render_reload(am.render_state)
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

// The host calls this once per detected incompatible reload (blocked = true) to
// raise the dismissible HUD toast, and with false after a clean reload/restart
// to clear it.
@(export)
app_set_reload_status :: proc(blocked: bool) {
	if blocked {
		ui.dev_notice_show(RELOAD_NOTICE_MSG)
	} else {
		ui.dev_notice_hide()
	}
}

// A fingerprint of every persistent (hot-reload-surviving) struct's memory
// layout. The host compares old vs new DLL: if it changes, the old memory can't
// be reused, so a hot reload would corrupt state. App_Memory holds the editor
// state behind a `rawptr`, so hashing App_Memory alone misses changes to
// Editor_State — list each persistent root explicitly here.
@(export)
app_memory_layout_hash :: proc() -> u64 {
	FNV_OFFSET :: u64(1469598103934665603)
	h := layout_hash(type_info_of(api.App_Memory), FNV_OFFSET)
	h = layout_hash(type_info_of(editor.Editor_State), h)
	return h
}

// Folds a type's size and recursive field layout into `seed`. Recurses through
// named/struct/union types (by value) but stops at pointers — opaque rawptr
// roots are covered by listing their concrete types in app_memory_layout_hash.
layout_hash :: proc(ti: ^runtime.Type_Info, seed: u64) -> u64 {
	PRIME :: u64(1099511628211)
	h := (seed ~ u64(ti.size)) * PRIME
	#partial switch v in ti.variant {
	case runtime.Type_Info_Named:
		h = layout_hash(v.base, h)
	case runtime.Type_Info_Struct:
		for i in 0 ..< int(v.field_count) {
			h = (h ~ u64(v.offsets[i])) * PRIME
			h = layout_hash(v.types[i], h)
		}
	case runtime.Type_Info_Union:
		for variant in v.variants {
			h = layout_hash(variant, h)
		}
	}
	return h
}
