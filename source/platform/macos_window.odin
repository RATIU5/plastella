package platform

import NS "core:sys/darwin/Foundation"
import sdl "vendor:sdl3"

cocoa_window :: proc(window: ^sdl.Window) -> ^NS.Window {
	props := sdl.GetWindowProperties(window)
	return (^NS.Window)(sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil))
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
