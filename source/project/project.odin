package project

Project :: struct {
	initialized: bool,
	name:        string,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	prj.name = name
	prj.initialized = true
}

project_shutdown :: proc(project_mem: ^Project) {
	if project_mem == nil do return
	free(project_mem)
}
