package project

Project_Memory :: struct {
	name: string,
}

project_init :: proc(name: string = "Untitled Project") -> ^Project_Memory {
	project_mem := new(Project_Memory)
	project_mem.name = name
	return project_mem
}

project_shutdown :: proc(project_mem: ^Project_Memory) {
	if project_mem == nil do return
	free(project_mem)
}
