package app

PROJECT_NAME_MAX :: TEXT_INPUT_MAX_BYTES
PROJECT_NAME_MAX_RUNES :: 25

Project :: struct {
	initialized: bool,
	name_buf:    [PROJECT_NAME_MAX]u8,
	name_len:    int,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	project_rename(prj, name)
	prj.initialized = true
}

@(require_results)
project_name :: proc(prj: ^Project) -> string {
	return string(prj.name_buf[:prj.name_len])
}

project_rename :: proc(prj: ^Project, name: string) {
	prj.name_len = copy(prj.name_buf[:], name)
}
