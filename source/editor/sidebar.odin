package editor

import clay "../../vendor/clay"
import api "../api"
import "../ui"

SIDEBAR_MIN: f32 : 250
SIDEBAR_MAX: f32 : 400
RESIZE_HANDLE: f32 : 4
SIDEBAR_RESIZE_CAPTURE :: api.Capture(100)
SIDEBAR_HEADER_HEIGHT: f32 : 32
SIDEBAR_FOOTER_HEIGHT: f32 : 38

Sidebar_Tab :: enum {
	Projects,
	Map,
	Tilesets,
	Sprites,
	LevelEditor,
	Settings,
}

Sidebar_State :: struct {
	width: f32,
	tab:   Sidebar_Tab,
}

sidebar :: proc(input: ^api.Input) {
	assert(editor_ctx != nil, "editor_ctx not initialized")
	sb := &editor_ctx.sidebar
	pj := &editor_ctx.project
	open_project := pj^ != nil

	near := abs(input.mouse.x - sb.width) <= RESIZE_HANDLE
	resizing := api.has_capture(input, SIDEBAR_RESIZE_CAPTURE)

	if near && input.left_pressed {
		resizing = api.capture_mouse(input, SIDEBAR_RESIZE_CAPTURE)
	}
	if input.left_released {
		api.release_capture(input, SIDEBAR_RESIZE_CAPTURE)
		resizing = false
	}

	if near || resizing {
		input.cursor = .Resize_EW
	}
	if resizing {
		sb.width = clamp(input.mouse.x, SIDEBAR_MIN, SIDEBAR_MAX)
	}

	if clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(editor_ctx.sidebar.width),
				height = clay.SizingGrow(),
			},
			layoutDirection = clay.LayoutDirection.TopToBottom,
		},
		backgroundColor = ui.COLOR_SIDEBAR,
		border = {
			color = near || resizing ? resizing ? ui.COLOR_SIDEBAR_BORDER_ACTIVE : ui.COLOR_SIDEBAR_BORDER_HOVER : ui.COLOR_SIDEBAR_BORDER,
			width = {right = 1},
		},
	},
	) {

		// Sidebar:Header
		if clay.UI(clay.ID("Sidebar:Header"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(SIDEBAR_HEADER_HEIGHT),
				},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Center},
				padding = {left = 82},
			},
			clip = {horizontal = true},
		},
		) {
			text_cfg := clay.TextElementConfig {
				fontSize  = 14,
				fontId    = u16(ui.FONT.BODY_BLD_14),
				textColor = ui.COLOR_TEXT,
				wrapMode  = clay.TextWrapMode.None,
			}

			// Sidebar:Header
			project_name_id := clay.ID("Sidebar:ProjectName")
			project_name: string
			switch p in pj {
			case Project_State:
				project_name = p.name
			case nil:
				project_name = "Plastella"
			}
			if clay.UI(project_name_id)(
			{layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}},
			) {
				clay.TextDynamic(
					ui.ellipsize_text(project_name, sb.width - 88, text_cfg),
					text_cfg,
				)
			}
			if clay.PointerOver(project_name_id) {
				ui.tooltip_set(project_name_id, project_name)
			}
		}

		// Sidebar:Content
		sidebar_content_id := clay.ID("Sidebar:Content")
		if clay.UI(sidebar_content_id)(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				layoutDirection = clay.LayoutDirection.TopToBottom,
				padding = {left = 5, right = 5},
			},
		},
		) {
			if !open_project &&
			   clay.UI(clay.ID("Sidebar:Content:No_Project"))(
			   {
				   layout = {
					   sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					   childAlignment = {
						   clay.LayoutAlignmentX.Center,
						   clay.LayoutAlignmentY.Center,
					   },
					   layoutDirection = clay.LayoutDirection.TopToBottom,
					   childGap = 15,
					   padding = {left = 5, right = 5, top = 5, bottom = 5},
				   },
			   },
			   ) {
				ui.text("Create a new project", .REG_20, ui.COLOR_NO_PROJECT_TEXT)
				ui.button_group_bordered(
					"Button:Sidebar:Project_Commands",
					[]string{"New Project", "Open Project"},
					-1,
					ui.PRIMARY_BUTTON,
					input,
					vertical = true,
				)
			}
		}

		// Sidebar:Footer
		sidebar_footer_id := clay.ID("Sidebar:Footer")
		if clay.UI(sidebar_footer_id)(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(SIDEBAR_FOOTER_HEIGHT),
				},
				padding = {left = 5, right = 5, top = 5, bottom = 5},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				childGap = 3,
			},
			backgroundColor = ui.COLOR_SIDEBAR_FOOTER,
			border = {width = {top = 1}, color = ui.COLOR_SIDEBAR_BORDER},
		},
		) {
			if ui.button("Button:Tab:Project", ui.get_icon(.PROJECT), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .Projects, tooltip = "Projects").clicked {
				sb.tab = .Projects
			}
			if ui.button("Button:Tab:Map", ui.get_icon(.MAP), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .Map, tooltip = "Map", disabled = !open_project).clicked {
				sb.tab = .Map
			}
			if ui.button("Button:Tab:Tileset", ui.get_icon(.TILESETS), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .Tilesets, tooltip = "Tilesets", disabled = !open_project).clicked {
				sb.tab = .Tilesets
			}
			if ui.button("Button:Tab:Sprites", ui.get_icon(.SPRITES), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .Sprites, tooltip = "Sprites", disabled = !open_project).clicked {
				sb.tab = .Sprites
			}
			if ui.button("Button:Tab:Level_Editor", ui.get_icon(.LEVEL_EDITOR), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .LevelEditor, tooltip = "Level Editor", disabled = !open_project).clicked {
				sb.tab = .LevelEditor
			}
			if ui.button("Button:Tab:Settings", ui.get_icon(.SETTINGS), ui.SIDEBAR_TAB_BUTTON, input, selected = sb.tab == .Settings, tooltip = "Settings", disabled = !open_project).clicked {
				sb.tab = .Settings
			}
		}
	}
}
