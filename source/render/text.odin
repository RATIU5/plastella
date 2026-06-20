package render

import clay "../../vendor/clay"

text :: proc(str: string, font: FONT, size: u16, color: clay.Color) {
	clay.Text(
		str,
		clay.TextElementConfig({fontId = u16(font), fontSize = size, textColor = color}),
	)
}
