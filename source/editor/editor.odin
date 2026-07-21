package editor

import project "../project"
import ui "../ui"

Editor_Memory :: struct {
	sidebar_mem: ^Sidebar_Memory,
	project:     ^project.Project_Memory,
	active_tab:  Sidebar_Tab,
}
editor_mem: ^Editor_Memory

editor_init :: proc(proj: ^project.Project_Memory) -> ^Editor_Memory {
	editor_mem = new(Editor_Memory)
	editor_mem.project = proj
	editor_mem.sidebar_mem = sidebar_init()

	return editor_mem
}

// re-point package globals after a hot reload — the new dll zeroed them
editor_reload :: proc(m: ^Editor_Memory) {
	editor_mem = m
	sidebar_mem = m.sidebar_mem
}

editor_shutdown :: proc() {
	if editor_mem == nil do return
	project.project_shutdown(editor_mem.project)
	ui.input_shutdown()
	sidebar_shutdown()
	free(editor_mem)
	editor_mem = nil
}

editor_frame :: proc() {
	sidebar_frame()
}
