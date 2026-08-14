package app

PROJECT_NAME_MAX :: TEXT_INPUT_MAX_BYTES
PROJECT_NAME_MAX_RUNES :: 25

Project :: struct {
	initialized: bool,
	name_buf:    [PROJECT_NAME_MAX]u8,
	name_len:    int,
	loc_buf:     [TEXT_INPUT_MAX_BYTES]u8,
	loc_len:     int,
	start_lives: i16,
	tile_size:   f32,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	project_name_set(prj, name)
	project_loc_set(prj, "~/Plastella Projects/")
	project_start_lives_set(prj, 5)
	project_tile_size_set(prj, 16)
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

@(require_results)
project_start_lives_get :: proc(prj: ^Project) -> i16 {
	return prj.start_lives
}

project_start_lives_set :: proc(prj: ^Project, val: i16) {
	prj.start_lives = val
}


@(require_results)
project_tile_size_get :: proc(prj: ^Project) -> f32 {
	return prj.tile_size
}

project_tile_size_set :: proc(prj: ^Project, val: f32) {
	prj.tile_size = val
}
