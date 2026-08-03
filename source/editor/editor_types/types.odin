package editor_types

import "../../project"

Toolbar_Tab :: enum u8 {
	Project,
	Map,
	Tileset,
	Sprites,
	Level,
	Settings,
}

Editor :: struct {
	tab:         Toolbar_Tab,
	status_text: string,
	project:     ^project.Project,
}
