package platform

import sdl "vendor:sdl3"

// binding omits COUNT; `_ = 511` sentinel -> 512
KEY_COUNT :: int(max(sdl.Scancode)) + 1

Mouse_Button :: enum u8 {
	Left,
	Right,
	Middle,
}

Mouse_Input :: struct {
	pos:   [2]f32,
	delta: [2]f32,
	wheel: [2]f32,
}

Key_Press :: struct {
	key:  sdl.Keycode,
	mods: sdl.Keymod,
}

Text_Input :: struct {
	utf8:        [64]u8,
	utf8_len:    int,
	presses:     [32]Key_Press,
	presses_len: int,
	dropped:     int,
}

Input :: struct {
	// Mouse
	mouse:     Mouse_Input,
	btns_curr: bit_set[Mouse_Button],
	btns_prev: bit_set[Mouse_Button],

	// Keyboard
	keys_curr: [KEY_COUNT]bool,
	keys_prev: [KEY_COUNT]bool,
	text:      Text_Input,

	// Other
	quit:      bool,
}

input_frame_begin :: proc(inp: ^Input) {
	// Mouse state reset
	inp.btns_prev = inp.btns_curr
	inp.mouse.delta = {}
	inp.mouse.wheel = {}

	// Keyboard state reset
	inp.keys_prev = inp.keys_curr
	inp.text.utf8_len = 0
	inp.text.presses_len = 0
	inp.text.dropped = 0

	// Quit state reset (might not be needed)
	inp.quit = false
}

input_event_process :: proc(inp: ^Input, ev: ^sdl.Event) {
	#partial switch ev.type {
	case .QUIT:
		inp.quit = true
	case .MOUSE_MOTION:
		inp.mouse.pos = {ev.motion.x, ev.motion.y}
		inp.mouse.delta += {ev.motion.xrel, ev.motion.yrel}
	case .MOUSE_WHEEL:
		inp.mouse.wheel += {ev.wheel.x, ev.wheel.y}
	case .MOUSE_BUTTON_DOWN:
		if b, ok := mouse_button_from_sdl(ev.button.button); ok {
			inp.btns_curr += {b}
		}
	case .MOUSE_BUTTON_UP:
		if b, ok := mouse_button_from_sdl(ev.button.button); ok {
			inp.btns_curr -= {b}
		}
	case .KEY_DOWN:
		inp.keys_curr[int(ev.key.scancode)] = true

		if inp.text.presses_len < len(inp.text.presses) {
			inp.text.presses[inp.text.presses_len] = {ev.key.key, ev.key.mod}
			inp.text.presses_len += 1
		} else {
			inp.text.dropped += 1
		}
	case .KEY_UP:
		inp.keys_curr[int(ev.key.scancode)] = false
	case .TEXT_INPUT:
		src := cast([^]u8)ev.text.text
		for i := 0; src[i] != 0 && inp.text.utf8_len < len(inp.text.utf8); i += 1 {
			inp.text.utf8[inp.text.utf8_len] = src[i]
			inp.text.utf8_len += 1
		}
	}
}

@(require_results)
key_down :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return inp.keys_curr[int(sc)]
}

@(require_results)
key_pressed :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return inp.keys_curr[int(sc)] && !inp.keys_prev[int(sc)]
}

@(require_results)
key_released :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return !inp.keys_curr[int(sc)] && inp.keys_prev[int(sc)]
}

@(require_results)
mouse_down :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b in inp.btns_curr
}

@(require_results)
mouse_pressed :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b in inp.btns_curr && b not_in inp.btns_prev
}

@(require_results)
mouse_released :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b not_in inp.btns_curr && b in inp.btns_prev
}

mouse_scroll :: proc(inp: ^Input) -> [2]f32 {

	return {}
}

@(private = "file")
mouse_button_from_sdl :: proc(b: u8) -> (Mouse_Button, bool) {
	switch b {
	case sdl.BUTTON_LEFT:
		return .Left, true
	case sdl.BUTTON_RIGHT:
		return .Right, true
	case sdl.BUTTON_MIDDLE:
		return .Middle, true
	}
	return {}, false
}
