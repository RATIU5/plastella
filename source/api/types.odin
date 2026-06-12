package api

App_Memory :: struct {
	run:    bool,
	// Persistent UI/clay state. Lives here (not in package globals) so it
	// survives hot reloads, which reset the DLL's globals to zero.
	ui_ctx: rawptr,
	editor: rawptr,
	// Per-frame input snapshot + cross-frame mouse capture (see input.odin).
	input:  Input,
}
