package editor

Editor_Memory :: struct {
	sidebar_mem: ^Sidebar_Memory,
}
editor_mem: ^Editor_Memory

editor_init :: proc() -> ^Editor_Memory {
	editor_mem = new(Editor_Memory)
	editor_mem.sidebar_mem = sidebar_init()

	return editor_mem
}

// re-point package globals after a hot reload — the new dll zeroed them
editor_reload :: proc(m: ^Editor_Memory) {
	editor_mem = m
	sidebar_mem = m.sidebar_mem
}

editor_shutdown :: proc() {
	sidebar_shutdown()
	free(editor_mem)
	editor_mem = nil
}

editor_frame :: proc() {
	sidebar_frame()
}
