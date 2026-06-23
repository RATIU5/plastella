package app

import "core:fmt"
APP_NAME :: "app"
DLL_EXT :: ".dylib" when ODIN_OS == .Darwin else ".dll" when ODIN_OS == .Windows else ".so"
DLL_FILE :: APP_NAME + DLL_EXT

@(export)
app_update :: proc() {
	fmt.println("hello from app")
}
