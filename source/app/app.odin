package app

import editor "../editor"
import platform "../platform"
import render "../render"
import rl "vendor:raylib"

App_Memory :: struct {
	render_state: ^render.Render_State,
	editor_state: ^editor.Editor_State,
}
mem: ^App_Memory

@(export)
app_init :: proc() {
	mem = new(App_Memory)
	platform.window_init()
	mem.render_state = render.render_init()
}

@(export)
app_update :: proc() {
	render.frame_begin()
	rl.ClearBackground(rl.BLACK)
	render.frame_end()
}

@(export)
app_shutdown :: proc() {
	render.render_shutdown()
	platform.window_shutdown()
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
	render.render_reload(mem.render_state)
}

@(export)
app_should_run :: proc() -> bool {
	return !platform.window_should_close()
}

@(export)
app_force_reload :: proc() -> bool {
	return platform.key_press(.F5)
}

@(export)
app_force_restart :: proc() -> bool {
	return platform.key_press(.F6)
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(App_Memory)
}
