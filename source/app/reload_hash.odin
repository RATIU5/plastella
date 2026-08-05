package app

// Generic ^runtime.Type_Info walker used to detect a struct-layout change across
// a hot reload (Appendix A). Debug-only, no knowledge of App specifically - kept
// out of app.odin so that file stays about lifecycle, not reflection.

import "../platform"
import "base:runtime"
import "core:mem"

// Keep these imports live in release builds too: everything that uses them
// lives inside the ODIN_DEBUG block below, which release compiles out entirely.
_ :: platform.Device
_ :: runtime.Type_Info
_ :: mem.byte_slice

when ODIN_DEBUG {
	@(export)
	app_memory_layout_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		seen := make(map[typeid]bool, 64, context.temp_allocator) // host will free each loop
		h := layout_hash(type_info_of(App), FNV_OFFSET, &seen)
		return layout_hash(type_info_of(platform.Device), h, &seen)
	}

	@(export)
	app_assets_table_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		FNV_PRIME :: u64(1099511628211)
		h := FNV_OFFSET
		for b in mem.byte_slice(&text_styles, size_of(text_styles)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		for b in mem.byte_slice(&font_paths, size_of(font_paths)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		for b in mem.byte_slice(&texture_paths, size_of(texture_paths)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		return h
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
