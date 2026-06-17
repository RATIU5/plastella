
package project

Project_State :: struct {
	name: string,
}

project_init :: proc() -> ^Project_State {
	project := new(Project_State)
	project.name = "New Project"
	return project
}

project_shutdown :: proc(project: ^Project_State) {
	free(project)
}
