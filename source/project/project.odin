package project

Project_Memory :: struct {
	name: string,
}
project_mem: ^Project_Memory

project_init :: proc() {
	project_mem = new(Project_Memory)
}

project_shutdown :: proc() {
	free(project_mem)
	project_mem = nil
}
