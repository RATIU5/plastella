package layout

import clay "../../vendor/clay"
import "base:runtime"
import c "core:c"
import "core:fmt"

Clay_Trace :: struct {
	phase:     string,
	file:      string,
	line:      int,
	had_error: bool,
}

@(private)
clay_trace: Clay_Trace

CLAY_TRACE :: proc(phase: string, loc := #caller_location) {
	clay_trace.phase = phase
	clay_trace.file = loc.file_path
	clay_trace.line = int(loc.line)
}

@(private)
clay_err_handler :: proc "c" (err: clay.ErrorData) {
	context = runtime.default_context()
	trace := cast(^Clay_Trace)err.userData
	if trace != nil {
		trace.had_error = true
	}

	msg := cast(string)(err.errorText.chars)[:err.errorText.length]

	fmt.eprintf(
		"[clay] %v: %s			phase=%s at %s:%d\n",
		err.errorType,
		msg,
		trace.phase if trace != nil else "?",
		trace.file if trace != nil else "?",
		trace.line if trace != nil else 0,
	)

	when ODIN_DEBUG {
		panic("Clay error")
	}
}

// Must deallocate the returned memory
init_clay :: proc(size: [2]f32) -> (^clay.Context, [^]u8, bool) {
	reset_clay_error()

	min_size := clay.MinMemorySize()
	mem := make([^]u8, min_size)

	arena := clay.CreateArenaWithCapacityAndMemory(cast(c.size_t)min_size, mem)

	CLAY_TRACE("Clay.Initialize")

	ctx := clay.Initialize(
		arena,
		{size.x, size.y},
		{handler = clay_err_handler, userData = &clay_trace},
	)

	if ctx == nil || clay_trace.had_error {
		fmt.eprintf("[clay] initialization failed\n")
		free(mem)
		return nil, nil, false
	}

	return ctx, mem, true
}

reset_clay_error :: proc() {
	clay_trace.had_error = false
}
