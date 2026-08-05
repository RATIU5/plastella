package app

Project :: struct {
	initialized: bool,
	name:        string,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	prj.name = name
	prj.initialized = true
}
