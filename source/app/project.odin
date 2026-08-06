package app

// Fixed buffer, not a heap string: clay borrows the name's bytes for the whole frame
// and renders them after the layout closes, so freeing a heap name mid-frame leaves
// the renderer reading freed memory. Sized to match the input that feeds it, so a
// rename from the UI can never truncate.
PROJECT_NAME_MAX :: TEXT_INPUT_MAX_BYTES

Project :: struct {
	initialized: bool,
	name_buf:    [PROJECT_NAME_MAX]u8,
	name_len:    int,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	project_rename(prj, name)
	prj.initialized = true
}

// Aliases prj's buffer; valid until the next rename.
@(require_results)
project_name :: proc(prj: ^Project) -> string {
	return string(prj.name_buf[:prj.name_len])
}

project_rename :: proc(prj: ^Project, name: string) {
	prj.name_len = copy(prj.name_buf[:], name)
}
