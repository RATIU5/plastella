package platform

import sdl "vendor:sdl3"

Render_Callback :: #type proc "c" ()

window_setup               :: proc(window: ^sdl.Window, bar_height: f32) {}
window_teardown            :: proc() {}
reposition_traffic_lights  :: proc(window: ^sdl.Window, bar_height: f32) {}
window_set_render_callback :: proc(cb: Render_Callback) {}
