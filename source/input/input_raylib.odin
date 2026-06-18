package input

import rl "vendor:raylib"

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

mouse_pos :: proc() -> [2]f32 {
	return rl.GetMousePosition()
}

mouse_down :: proc(button: Mouse_Button) -> bool {
	return rl.IsMouseButtonDown(rl_mouse_button[button])
}

mouse_up :: proc(button: Mouse_Button) -> bool {
	return rl.IsMouseButtonUp(rl_mouse_button[button])
}

key_down :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyDown(rl_keyboard_key[key])
}

key_up :: proc(key: Keyboard_Key) -> bool {
	return rl.IsKeyUp(rl_keyboard_key[key])
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

mod_up :: proc(mod: Modifiers) -> bool {
	switch mod {
	case .SHIFT:
		return rl.IsKeyUp(.LEFT_SHIFT) || rl.IsKeyUp(.RIGHT_SHIFT)
	case .CONTROL:
		return rl.IsKeyUp(.LEFT_CONTROL) || rl.IsKeyUp(.RIGHT_CONTROL)
	case .ALT:
		return rl.IsKeyUp(.LEFT_ALT) || rl.IsKeyUp(.RIGHT_ALT)
	case .SUPER:
		return rl.IsKeyUp(.LEFT_SUPER) || rl.IsKeyUp(.RIGHT_SUPER)
	case:
		return false
	}
}

mouse_click :: proc(button: Mouse_Button) -> bool {

}
