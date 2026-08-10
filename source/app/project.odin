package app

PROJECT_NAME_MAX :: TEXT_INPUT_MAX_BYTES
PROJECT_NAME_MAX_RUNES :: 25

Project :: struct {
	initialized: bool,
	name_buf:    [PROJECT_NAME_MAX]u8,
	name_len:    int,
	loc_buf:     [TEXT_INPUT_MAX_BYTES]u8,
	loc_len:     int,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	project_name_set(prj, name)
	project_loc_set(prj, "~/Plastella Projects/")
	prj.initialized = true
}

@(require_results)
project_name_get :: proc(prj: ^Project) -> string {
	return string(prj.name_buf[:prj.name_len])
}

project_name_set :: proc(prj: ^Project, name: string) {
	prj.name_len = copy(prj.name_buf[:], name)
}

@(require_results)
project_loc_get :: proc(prj: ^Project) -> string {
	return string(prj.loc_buf[:prj.loc_len])
}

project_loc_set :: proc(prj: ^Project, path: string) {
	prj.loc_len = copy(prj.loc_buf[:], path)
}
