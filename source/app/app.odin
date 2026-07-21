package app

import editor "../editor"
import platform "../platform"
import project "../project"
import render "../render"
import ui "../ui"
import "base:runtime"

@(private)
_ :: runtime.Type_Info

App_Memory :: struct {
	render_mem:  ^render.Render_Memory,
	editor_mem:  ^editor.Editor_Memory,
	project_mem: ^project.Project_Memory,
	ui_mem:      ^ui.UI_Memory,
}
mem: ^App_Memory

when ODIN_DEBUG {
	@(export)
	app_memory_layout_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		seen := make(map[typeid]bool, 64, context.temp_allocator) // host will free each loop
		return layout_hash(type_info_of(App_Memory), FNV_OFFSET, &seen)
	}

	layout_hash :: proc(ti: ^runtime.Type_Info, seed: u64, seen: ^map[typeid]bool) -> u64 {
		PRIME :: u64(1099511628211)
		if ti == nil do return seed // rawptr elem, empty proc results, etc.
		h := (seed ~ u64(ti.size)) * PRIME
		if seen[ti.id] do return h // already walked this type
		seen[ti.id] = true

		#partial switch v in ti.variant {
		case runtime.Type_Info_Named:
			h = layout_hash(v.base, h, seen)
		case runtime.Type_Info_Struct:
			for i in 0 ..< int(v.field_count) {
				h = (h ~ u64(v.offsets[i])) * PRIME
				h = layout_hash(v.types[i], h, seen)
			}
		case runtime.Type_Info_Union:
			for variant in v.variants do h = layout_hash(variant, h, seen)
		case runtime.Type_Info_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Enumerated_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Slice:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Dynamic_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Map:
			h = layout_hash(v.key, h, seen)
			h = layout_hash(v.value, h, seen)
		case runtime.Type_Info_Pointer:
			h = layout_hash(v.elem, h, seen) // nil for rawptr -> stops
		case runtime.Type_Info_Multi_Pointer:
			h = layout_hash(v.elem, h, seen)
		}
		return h
	}
}

@(export)
app_init :: proc() {
	mem = new(App_Memory)
	platform.window_init()
	mem.render_mem = render.render_init()
	mem.ui_mem = ui.ui_init()
	mem.editor_mem = editor.editor_init(mem.project_mem)
}

@(export)
app_update :: proc() {
	render.frame_begin()
	editor.editor_frame()
	render.frame_end()
}

@(export)
app_shutdown :: proc() {
	project.project_shutdown(mem.project_mem)
	editor.editor_shutdown()
	ui.input_shutdown()
	render.render_shutdown()
	platform.window_shutdown()
	free(mem)
	mem = nil
}

@(export)
app_memory :: proc() -> rawptr {
	return mem
}

@(export)
app_hot_reloaded :: proc(m: rawptr) {
	mem = (^App_Memory)(m)
	render.render_reload(mem.render_mem)
	ui.ui_reload(mem.ui_mem)
	editor.editor_reload(mem.editor_mem)
}

@(export)
app_should_run :: proc() -> bool {
	return !platform.window_should_close()
}

@(export)
app_force_reload :: proc() -> bool {
	return platform.key_press(.F5)
}

@(export)
app_force_restart :: proc() -> bool {
	return platform.key_press(.F6)
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(App_Memory)
}
