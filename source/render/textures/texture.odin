package textures

import be "../../render_backend"
import rl "vendor:raylib"


when be.BACKEND == .Raylib {
	Texture_Slice :: struct {
		tex:  ^rl.Texture2D,
		crop: rl.Rectangle,
	}
}
