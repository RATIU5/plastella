package app

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:reflect"
import "core:time"
import rl "vendor:raylib"

APP_NAME :: "app"
DLL_EXT :: ".dylib" when ODIN_OS == .Darwin else ".dll" when ODIN_OS == .Windows else ".so"
DLL :: APP_NAME + DLL_EXT

FNV_OFFSET :: 0xcbf29ce484222325
FNV_PRIME :: 0x100000001b3

App_API :: struct {
	lib:                dynlib.Library,
	version:            int,
	mod_time:           time.Time,
	init:               proc(),
	update:             proc(),
	shutdown:           proc(),
	should_run:         proc() -> bool,
	force_reload:       proc() -> bool,
	force_restart:      proc() -> bool,
	memory:             proc() -> rawptr,
	hot_reloaded:       proc(m: rawptr),
	memory_size:        proc() -> int,
	memory_layout_hash: proc() -> u64,
}

App_Memory :: struct {
	counter: int,
}
mem: ^App_Memory

@(export)
app_init :: proc() {
	mem = new(App_Memory)
}

@(export)
app_update :: proc() {
	mem.counter += 1
	fmt.println("hello from app:", mem.counter)
}

@(export)
app_shutdown :: proc() {
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
}

@(export)
app_should_run :: proc() -> bool {
	return !rl.WindowShouldClose()
}

@(export)
app_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
app_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

load_api :: proc(version: int) -> (api: App_API, ok: bool) {
	dll := DLL

	mod, mod_err := os.last_write_time_by_name(dll)
	if mod_err != nil {
		fmt.eprintfln("cannot stat", dll, mod_err)
		return
	}

	copy_name := fmt.tprintf("%s_%d%s", APP_NAME, version, DLL_EXT)
	data, read_err := os.read_entire_file(dll, context.allocator)
	if read_err != nil do return
	defer delete(data)
	if os.write_entire_file(copy_name, data) != nil do return

	count, syms_ok := dynlib.initialize_symbols(&api, copy_name, "app_", "lib")
	if !syms_ok || count == 0 do return

	api.version = version
	api.mod_time = mod
	return api, true
}

layout_hash :: proc(id: typeid) -> u64 {
	h := u64(FNV_OFFSET)
	ti := type_info_of(id)
	h = (h ~ u64(ti.size)) * FNV_PRIME

	for field in reflect.struct_fields_zipped(id) {
		h = (h ~ u64(field.offset)) * FNV_PRIME
		h = (h ~ u64(field.type.size)) * FNV_PRIME
		#partial switch p in field.type.variant {
		case runtime.Type_Info_Pointer:
			if p.elem != nil do h = (h ~ layout_hash(p.elem.id)) * FNV_PRIME
		}
	}

	return h
}
