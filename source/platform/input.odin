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
	pos:    [2]f32,
	delta:  [2]f32,
	wheel:  [2]f32,
	// SDL's click-count for this frame's press (1=single, 2=double, 3=triple,
	// using the OS's own double-click time/distance thresholds); 0 outside
	// the frame a press happened, same one-shot lifetime as btns_pressed.
	clicks: u8,
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
	mouse:         Mouse_Input,
	btns_curr:     bit_set[Mouse_Button],
	btns_pressed:  bit_set[Mouse_Button],
	btns_released: bit_set[Mouse_Button],

	// Keyboard
	keys_curr:     [KEY_COUNT]bool,
	keys_pressed:  [KEY_COUNT]bool,
	keys_released: [KEY_COUNT]bool,
	text:          Text_Input,

	// Other
	quit:          bool,
	scale_changed: bool,
}

input_frame_begin :: proc(inp: ^Input) {
	inp.mouse.delta = {}
	inp.mouse.wheel = {}
	inp.mouse.clicks = 0

	inp.btns_pressed = {}
	inp.btns_released = {}
	inp.keys_pressed = {}
	inp.keys_released = {}

	inp.text.utf8_len = 0
	inp.text.presses_len = 0
	inp.text.dropped = 0
	inp.quit = false
	inp.scale_changed = false
}

input_event_process :: proc(inp: ^Input, ev: ^sdl.Event) {
	#partial switch ev.type {
	case .QUIT:
		inp.quit = true
	case .WINDOW_DISPLAY_SCALE_CHANGED:
		inp.scale_changed = true
	case .MOUSE_MOTION:
		inp.mouse.pos = {ev.motion.x, ev.motion.y}
		inp.mouse.delta += {ev.motion.xrel, ev.motion.yrel}
	case .MOUSE_WHEEL:
		inp.mouse.wheel += {ev.wheel.x, ev.wheel.y}
	case .MOUSE_BUTTON_DOWN:
		if b, ok := mouse_button_from_sdl(ev.button.button); ok {
			if b not_in inp.btns_curr {
				inp.btns_curr += {b}
				inp.btns_pressed += {b}
			}
			inp.mouse.clicks = ev.button.clicks
		}
	case .MOUSE_BUTTON_UP:
		if b, ok := mouse_button_from_sdl(ev.button.button); ok {
			if b in inp.btns_curr {
				inp.btns_curr -= {b}
				inp.btns_released += {b}
			}
		}
	case .KEY_DOWN:
		i := int(ev.key.scancode)
		if !inp.keys_curr[i] {
			inp.keys_curr[i] = true
			inp.keys_pressed[i] = true
		}

		if inp.text.presses_len < len(inp.text.presses) {
			inp.text.presses[inp.text.presses_len] = {ev.key.key, ev.key.mod}
			inp.text.presses_len += 1
		} else {
			inp.text.dropped += 1
		}
	case .KEY_UP:
		i := int(ev.key.scancode)
		if inp.keys_curr[i] {
			inp.keys_curr[i] = false
			inp.keys_released[i] = true
		}
	case .TEXT_INPUT:
		text := string(ev.text.text) // SDL3 guarantees valid UTF-8
		if len(text) == 0 do break
		if inp.text.utf8_len + len(text) > len(inp.text.utf8) {
			inp.text.dropped += 1
			break
		}
		copy(inp.text.utf8[inp.text.utf8_len:], text)
		inp.text.utf8_len += len(text)
	}
}

@(require_results)
key_down :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return inp.keys_curr[int(sc)]
}

@(require_results)
key_pressed :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return inp.keys_pressed[int(sc)]
}

@(require_results)
key_released :: proc(inp: ^Input, sc: sdl.Scancode) -> bool {
	return inp.keys_released[int(sc)]
}

@(require_results)
mouse_down :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b in inp.btns_curr
}

@(require_results)
mouse_pressed :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b in inp.btns_pressed
}

@(require_results)
mouse_released :: proc(inp: ^Input, b: Mouse_Button) -> bool {
	return b in inp.btns_released
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
