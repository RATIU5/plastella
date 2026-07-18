package editor

import clay "../../vendor/clay"
import platform "../platform"
import render "../render"
import textures "../render/textures"
import ui "../ui"
import sidebar "./sidebar"

SIDEBAR_MIN: f32 : 250
SIDEBAR_MAX: f32 : 400
SIDEBAR_WIDTH_DEFAULT: f32 : 250
SIDEBAR_HEADER_HEIGHT: f32 : 32
SIDEBAR_FOOTER_HEIGHT: f32 : 38
WINDOW_CONTROLS_WIDTH: u16 : 82
RESIZE_HANDLE: f32 : 4

Sidebar_Tab :: enum u8 {
	Project,
	Maps,
	Tilesets,
	Sprites,
	Level_Editor,
	Settings,
}

Sidebar_Memory :: struct {
	width:    f32,
	resizing: bool,
}
sidebar_mem: ^Sidebar_Memory

sidebar_init :: proc() -> ^Sidebar_Memory {
	sidebar_mem = new(Sidebar_Memory)
	sidebar_mem.width = SIDEBAR_WIDTH_DEFAULT

	return sidebar_mem
}

sidebar_shutdown :: proc() {
	free(sidebar_mem)
	sidebar_mem = nil
}

sidebar_frame :: proc() {
	near := abs(platform.mouse_pos().x - sidebar_mem.width) <= RESIZE_HANDLE

	if near && platform.mouse_press(.LEFT) {
		sidebar_mem.resizing = true
	}
	if sidebar_mem.resizing && platform.mouse_release(.LEFT) {
		sidebar_mem.resizing = false
	}

	if near || sidebar_mem.resizing do platform.set_cursor(.RESIZE_EW)

	if sidebar_mem.resizing {
		sidebar_mem.width = clamp(platform.mouse_pos().x, SIDEBAR_MIN, SIDEBAR_MAX)
	}

	if render.pointer_over(ID.sidebar.header) && platform.mouse_press(.LEFT) {
		platform.window_begin_drag()
	}

	if clay.UI(clay.ID(ID.sidebar.group))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(sidebar_mem.width), height = clay.SizingGrow()},
			layoutDirection = clay.LayoutDirection.TopToBottom,
		},
		border = {
			width = {right = 1},
			color = near || sidebar_mem.resizing ? sidebar_mem.resizing ? ui.COLOR_SIDEBAR_BORDER_ACTIVE : ui.COLOR_SIDEBAR_BORDER_HOVER : ui.COLOR_SIDEBAR_BORDER,
		},
		backgroundColor = ui.COLOR_SIDEBAR,
	},
	) {

		// sidebar:header
		if clay.UI(clay.ID(ID.sidebar.header))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(SIDEBAR_HEADER_HEIGHT),
				},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Center},
				padding = {left = WINDOW_CONTROLS_WIDTH},
			},
			clip = {horizontal = true},
		},
		) {
			if clay.UI(clay.ID(ID.sidebar.title))(
			{layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}},
			) {
				project_name := editor_mem.project != nil ? editor_mem.project.name : "Plastella"
				render.text(
					project_name,
					.UI_BLD_14,
					ui.COLOR_TEXT,
					ellipsize = sidebar_mem.width - f32(WINDOW_CONTROLS_WIDTH) - 10,
				)
			}
		}

		// sidebar:content
		if clay.UI(clay.ID(ID.sidebar.content))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				layoutDirection = clay.LayoutDirection.TopToBottom,
				padding = {left = 5, right = 5},
			},
		},
		) {
			if editor_mem.active_tab == .Project {
				sidebar.project_frame(editor_mem.project)
			}
		}

		// sidebar:footer
		if clay.UI(clay.ID(ID.sidebar.footer))(
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
			if ui.button(
				"sidebar:footer:btn_project",
				textures.UI_ICONS.PROJECT,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Project,
			) {
				if editor_mem.active_tab != .Project {
					editor_mem.active_tab = .Project
				}
			}
			if ui.button(
				"sidebar:footer:btn_maps",
				textures.UI_ICONS.MAP,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Maps,
				disabled = editor_mem.project == nil,
			) {
				if editor_mem.project != nil && editor_mem.active_tab != .Maps {
					editor_mem.active_tab = .Maps
				}
			}
			if ui.button(
				"sidebar:footer:btn_tilesets",
				textures.UI_ICONS.TILESETS,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Tilesets,
				disabled = editor_mem.project == nil,
			) {
				if editor_mem.project != nil && editor_mem.active_tab != .Tilesets {
					editor_mem.active_tab = .Tilesets
				}
			}
			if ui.button(
				"sidebar:footer:btn_sprites",
				textures.UI_ICONS.SPRITES,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Sprites,
				disabled = editor_mem.project == nil,
			) {
				if editor_mem.project != nil && editor_mem.active_tab != .Sprites {
					editor_mem.active_tab = .Sprites
				}
			}
			if ui.button(
				"sidebar:footer:btn_level_editor",
				textures.UI_ICONS.LEVEL_EDITOR,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Level_Editor,
				disabled = editor_mem.project == nil,
			) {
				if editor_mem.project != nil && editor_mem.active_tab != .Level_Editor {
					editor_mem.active_tab = .Level_Editor
				}
			}
			if ui.button(
				"sidebar:footer:btn_settings",
				textures.UI_ICONS.SETTINGS,
				.SIDEBAR_TAB,
				selected = editor_mem.active_tab == .Settings,
				disabled = editor_mem.project == nil,
			) {
				if editor_mem.project != nil && editor_mem.active_tab != .Settings {
					editor_mem.active_tab = .Settings
				}
			}
		}
	}
}
