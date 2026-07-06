package app

import editor "../editor"
import platform "../platform"
import render "../render"

App_Memory :: struct {
	render_mem: ^render.Render_Memory,
	editor_mem: ^editor.Editor_Memory,
}
mem: ^App_Memory

@(export)
app_init :: proc() {
	mem = new(App_Memory)
	platform.window_init()
	mem.render_mem = render.render_init()
	mem.editor_mem = editor.editor_init()
}

@(export)
app_update :: proc() {
	render.frame_begin()
	editor.editor_frame()
	render.frame_end()
}

@(export)
app_shutdown :: proc() {
	editor.editor_shutdown()
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
	render.render_reload(mem.render_mem)
	editor.editor_reload(mem.editor_mem)
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
