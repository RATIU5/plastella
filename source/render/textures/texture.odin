package textures

import rl "vendor:raylib"

Texture_Slice :: struct {
	tex:  ^rl.Texture2D,
	crop: rl.Rectangle,
	tint: [4]f32,
}
