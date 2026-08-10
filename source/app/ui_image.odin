package app

import "../../vendor/clay"
import "core:strings"

image :: proc(ctx: ^Ctx, id: string, img: Texture_Id, width: f32) {
	// Temp-scoped, freed at frame end.
	img_inst := new_clone(texture_slice(ctx.frame.assets, img), context.temp_allocator)
	img_id := strings.concatenate([]string{id, "_image"}, context.temp_allocator)

	w := width
	h := w * f32(img_inst.crop.h) / f32(img_inst.crop.w)

	if clay.UI(clay.ID(img_id))(
	{
		layout = {sizing = {width = clay.SizingFixed(w), height = clay.SizingFixed(h)}},
		image = {imageData = rawptr(img_inst)},
		aspectRatio = {w / h},
	},
	) {}
}

icon :: proc(ctx: ^Ctx, id: string, img: Ui_Icons, height: f32, tint: clay.Color) {
	img_inst := new_clone(ui_icon(ctx.frame.assets, img), context.temp_allocator)
	img_inst.tint = tint
	img_id := strings.concatenate([]string{id, "_icon"}, context.temp_allocator)

	w := height * (f32(img_inst.crop.w) / f32(img_inst.crop.h))

	if clay.UI(clay.ID(img_id))(
	{
		layout = {sizing = {width = clay.SizingFixed(w), height = clay.SizingFixed(height)}},
		image = {imageData = rawptr(img_inst)},
		aspectRatio = {w / height},
	},
	) {}
}
