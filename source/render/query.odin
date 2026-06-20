package render

import clay "../../vendor/clay"
import io "../io"

element_id :: proc(label: string) -> clay.ElementId {
	return clay.GetElementId(clay.MakeString(label))
}

hovered :: proc() -> bool {
	return clay.Hovered()
}

pointer_over :: proc(label: string) -> bool {
	return clay.PointerOver(element_id(label))
}

clicked :: proc(label: string, button := io.Mouse_Button.LEFT) -> bool {
	return pointer_over(label) && io.mouse_press(button)
}

// found=false means no such element this frame; bbox is zero.
element_bbox :: proc(label: string) -> (clay.BoundingBox, bool) {
	d := clay.GetElementData(element_id(label))
	return d.boundingBox, d.found
}

scroll_offset :: proc() -> [2]f32 {
	return clay.GetScrollOffset()
}

scroll_data :: proc(label: string) -> (clay.ScrollContainerData, bool) {
	d := clay.GetScrollContainerData(element_id(label))
	return d, d.found
}

on_hover :: proc(
	cb: proc "c" (id: clay.ElementId, data: clay.PointerData, ud: rawptr),
	ud: rawptr = nil,
) {
	clay.OnHover(cb, ud)
}

open_element_id :: proc() -> u32 {
	return clay.GetOpenElementId()
}
