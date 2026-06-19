package input

import rl "vendor:raylib"

DBL_CLICK_SEC: f64 : 0.3
DBL_CLICK_DIST: f32 : 10

Input_State :: struct {
	time:            f64,
	last_press_time: [Mouse_Button]f64,
	last_press_pos:  [Mouse_Button][2]f32,
	dbl_this_lap:    [Mouse_Button]bool,
	// fixed cap; large pastes truncate
	char_buf:        [32]rune,
	char_count:      int,
}

@(private)
rl_mouse_button := [Mouse_Button]rl.MouseButton {
	.LEFT    = .LEFT,
	.RIGHT   = .RIGHT,
	.MIDDLE  = .MIDDLE,
	.SIDE    = .SIDE,
	.EXTRA   = .EXTRA,
	.FORWARD = .FORWARD,
	.BACK    = .BACK,
}

@(private)
rl_keyboard_key := [Keyboard_Key]rl.KeyboardKey {
	.KEY_NULL      = .KEY_NULL,
	.APOSTROPHE    = .APOSTROPHE,
	.COMMA         = .COMMA,
	.MINUS         = .MINUS,
	.PERIOD        = .PERIOD,
	.SLASH         = .SLASH,
	.ZERO          = .ZERO,
	.ONE           = .ONE,
	.TWO           = .TWO,
	.THREE         = .THREE,
	.FOUR          = .FOUR,
	.FIVE          = .FIVE,
	.SIX           = .SIX,
	.SEVEN         = .SEVEN,
	.EIGHT         = .EIGHT,
	.NINE          = .NINE,
	.SEMICOLON     = .SEMICOLON,
	.EQUAL         = .EQUAL,
	.A             = .A,
	.B             = .B,
	.C             = .C,
	.D             = .D,
	.E             = .E,
	.F             = .F,
	.G             = .G,
	.H             = .H,
	.I             = .I,
	.J             = .J,
	.K             = .K,
	.L             = .L,
	.M             = .M,
	.N             = .N,
	.O             = .O,
	.P             = .P,
	.Q             = .Q,
	.R             = .R,
	.S             = .S,
	.T             = .T,
	.U             = .U,
	.V             = .V,
	.W             = .W,
	.X             = .X,
	.Y             = .Y,
	.Z             = .Z,
	.LEFT_BRACKET  = .LEFT_BRACKET,
	.BACKSLASH     = .BACKSLASH,
	.RIGHT_BRACKET = .RIGHT_BRACKET,
	.GRAVE         = .GRAVE,
	.SPACE         = .SPACE,
	.ESCAPE        = .ESCAPE,
	.ENTER         = .ENTER,
	.TAB           = .TAB,
	.BACKSPACE     = .BACKSPACE,
	.INSERT        = .INSERT,
	.DELETE        = .DELETE,
	.RIGHT         = .RIGHT,
	.LEFT          = .LEFT,
	.DOWN          = .DOWN,
	.UP            = .UP,
	.PAGE_UP       = .PAGE_UP,
	.PAGE_DOWN     = .PAGE_DOWN,
	.HOME          = .HOME,
	.END           = .END,
	.CAPS_LOCK     = .CAPS_LOCK,
	.SCROLL_LOCK   = .SCROLL_LOCK,
	.NUM_LOCK      = .NUM_LOCK,
	.PRINT_SCREEN  = .PRINT_SCREEN,
	.PAUSE         = .PAUSE,
	.F1            = .F1,
	.F2            = .F2,
	.F3            = .F3,
	.F4            = .F4,
	.F5            = .F5,
	.F6            = .F6,
	.F7            = .F7,
	.F8            = .F8,
	.F9            = .F9,
	.F10           = .F10,
	.F11           = .F11,
	.F12           = .F12,
	.LEFT_SHIFT    = .LEFT_SHIFT,
	.LEFT_CONTROL  = .LEFT_CONTROL,
	.LEFT_ALT      = .LEFT_ALT,
	.LEFT_SUPER    = .LEFT_SUPER,
	.RIGHT_SHIFT   = .RIGHT_SHIFT,
	.RIGHT_CONTROL = .RIGHT_CONTROL,
	.RIGHT_ALT     = .RIGHT_ALT,
	.RIGHT_SUPER   = .RIGHT_SUPER,
	.KB_MENU       = .KB_MENU,
	.KP_0          = .KP_0,
	.KP_1          = .KP_1,
	.KP_2          = .KP_2,
	.KP_3          = .KP_3,
	.KP_4          = .KP_4,
	.KP_5          = .KP_5,
	.KP_6          = .KP_6,
	.KP_7          = .KP_7,
	.KP_8          = .KP_8,
	.KP_9          = .KP_9,
	.KP_DECIMAL    = .KP_DECIMAL,
	.KP_DIVIDE     = .KP_DIVIDE,
	.KP_MULTIPLY   = .KP_MULTIPLY,
	.KP_SUBTRACT   = .KP_SUBTRACT,
	.KP_ADD        = .KP_ADD,
	.KP_ENTER      = .KP_ENTER,
	.KP_EQUAL      = .KP_EQUAL,
}

// Snapshot for signals raylib doesn't track (chars, double-click). Live signals wrap raylib directly.
@(private)
input_state: Input_State

mouse_pos :: proc() -> [2]f32 {
	return rl.GetMousePosition()
}

mouse_down :: proc(button: Mouse_Button) -> bool {
	return rl.IsMouseButtonDown(rl_mouse_button[button])
}

key_down :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyDown(rl_keyboard_key[key])
}

mod_down :: proc(mod: Modifiers) -> bool {
	switch mod {
	case .SHIFT:
		return rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	case .CONTROL:
		return rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	case .ALT:
		return rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	case .SUPER:
		return rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
	case:
		return false
	}
}

mouse_press :: proc(button: Mouse_Button) -> bool {
	return rl.IsMouseButtonPressed(rl_mouse_button[button])
}

// Also fires mouse_press this lap; check dbl first if you need exclusivity.
mouse_dbl_click :: proc(button: Mouse_Button) -> bool {
	return input_state.dbl_this_lap[button]
}

mouse_release :: proc(button: Mouse_Button) -> bool {
	return rl.IsMouseButtonReleased(rl_mouse_button[button])
}

mouse_scroll :: proc() -> [2]f32 {
	return rl.GetMouseWheelMoveV()
}

key_press :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyPressed(rl_keyboard_key[key])
}

key_press_repeat :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyPressedRepeat(rl_keyboard_key[key])
}

key_release :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyReleased(rl_keyboard_key[key])
}

chars_typed :: proc() -> []rune {
	return input_state.char_buf[:input_state.char_count]
}

// Call once per lap, AFTER raylib pumps events (post-EndDrawing), BEFORE building UI.
input_update :: proc() {
	// reset; last lap's chars are stale
	input_state.char_count = 0
	input_state.time = rl.GetTime()

	for input_state.char_count < len(input_state.char_buf) {
		// drains raylib's queue — must happen exactly once per lap, here only
		c := rl.GetCharPressed()
		if c == 0 do break
		input_state.char_buf[input_state.char_count] = c
		input_state.char_count += 1
	}

	now := input_state.time
	for button in Mouse_Button {
		rl_btn := rl_mouse_button[button]

		input_state.dbl_this_lap[button] = false

		if rl.IsMouseButtonPressed(rl_btn) {
			pos := rl.GetMousePosition()
			dt := now - input_state.last_press_time[button]
			dist := rl.Vector2Distance(pos, input_state.last_press_pos[button])

			if dt < DBL_CLICK_SEC && dist < DBL_CLICK_DIST {
				input_state.dbl_this_lap[button] = true
				// sentinel: stop click 3 pairing with click 2
				input_state.last_press_time[button] = -1e9
			} else {
				input_state.last_press_time[button] = now
			}

			input_state.last_press_pos[button] = pos
		}
	}
}
