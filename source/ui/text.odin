package ui

import "core:c"
import "core:mem"
import clay "../../vendor/clay"

ellipsize_text :: proc(text: string, max_width: f32, cfg: clay.TextElementConfig) -> string {
	cfg := cfg
	ss := clay.StringSlice{
		length    = c.int32_t(len(text)),
		chars     = ([^]c.char)(raw_data(text)),
		baseChars = ([^]c.char)(raw_data(text)),
	}

	if measure_text(ss, &cfg, nil).width <= max_width {
		return text
	}

	dots_str := "..."
	dots := clay.StringSlice{
		length    = 3,
		chars     = ([^]c.char)(raw_data(dots_str)),
		baseChars = ([^]c.char)(raw_data(dots_str)),
	}
	dots_width := measure_text(dots, &cfg, nil).width

	lo, hi := 0, len(text)
	for lo < hi {
		mid := (lo + hi + 1) / 2
		slice := clay.StringSlice{
			length    = c.int32_t(mid),
			chars     = ss.chars,
			baseChars = ss.baseChars,
		}
		if measure_text(slice, &cfg, nil).width + dots_width <= max_width {
			lo = mid
		} else {
			hi = mid - 1
		}
	}

	// Trim trailing spaces so they don't appear as phantom gaps before "...".
	for lo > 0 && text[lo - 1] == ' ' {
		lo -= 1
	}

	// Allocate from the temp allocator — freed at the end of each frame by
	// free_all(context.temp_allocator), so Clay's stored pointer stays valid
	// for exactly the frame it was created in.
	buf := make([]u8, lo + 3, context.temp_allocator)
	mem.copy(raw_data(buf), raw_data(text), lo)
	buf[lo]     = '.'
	buf[lo + 1] = '.'
	buf[lo + 2] = '.'

	return string(buf)
}
