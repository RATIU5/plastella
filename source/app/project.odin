package app

import "core:strings"

Project :: struct {
	initialized: bool,
	name:        string,
}

project_init :: proc(prj: ^Project, name: string = "Untitled Project") {
	prj.name = strings.clone(name)
	prj.initialized = true
}

project_rename :: proc(prj: ^Project, name: string) {
	if name == prj.name do return
	delete(prj.name)
	prj.name = strings.clone(name)
}

project_shutdown :: proc(prj: ^Project) {
	if prj == nil do return
	delete(prj.name)
}
