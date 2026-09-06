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

// A size is a sheet, not a number: the atlas is drawn at 32px cells for 16
// logical px, so at 2x one source pixel is one physical pixel and strokes stay
// crisp. Any other height resamples, so there is nothing else to pick.
Icon_Size :: enum u8 {
	Small,
}

@(rodata)
icon_size_px := [Icon_Size]f32 {
	.Small = 16,
}

icon :: proc(ctx: ^Ctx, id: string, img: Ui_Icons, size: Icon_Size, tint: clay.Color) {
	height := icon_size_px[size]
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
