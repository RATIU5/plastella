package platform

import NS "core:sys/darwin/Foundation"
import sdl "vendor:sdl3"

when ODIN_OS == .Darwin {
	cocoa_window :: proc(window: ^sdl.Window) -> ^NS.Window {
		props := sdl.GetWindowProperties(window)
		return (^NS.Window)(
			sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil),
		)
	}

	setup_fullsize_titlebar :: proc(window: ^sdl.Window) {
		nswindow := cocoa_window(window)
		NS.Window_setStyleMask(
			nswindow,
			{.Titled, .Closable, .Miniaturizable, .Resizable, .FullSizeContentView},
		)
		NS.Window_setTitlebarAppearsTransparent(nswindow, true)
		NS.Window_setTitleVisibility(nswindow, .Hidden)
	}
} else when ODIN_OS == .Windows {
	// TODO:windows
	setup_fullsize_titlebar :: proc() {}
} else {
	// Assume linux, might need to change later
	// TODO:linux
	setup_fullsize_titlebar :: proc() {}
}
