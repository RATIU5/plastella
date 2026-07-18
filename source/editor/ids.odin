package editor

Sidebar_IDs :: struct {
	group, header, title, content, footer: string,
}

IDs :: struct {
	sidebar: Sidebar_IDs,
}

ID :: IDs {
	sidebar = {
		group = "sidebar:group",
		header = "sidebar:header",
		title = "sidebar:header:title",
		content = "sidebar:content",
		footer = "sidebar:footer",
	},
}
