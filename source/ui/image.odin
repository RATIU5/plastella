package ui

import "../../vendor/clay"
import "../assets"
import "core:strings"

image :: proc(ctx: ^Ctx, id: string, img: assets.Texture_Id, width: f32) {
	img_inst := new_clone(assets.image(ctx.frame.assets, img), context.temp_allocator)
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
