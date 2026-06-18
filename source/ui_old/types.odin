package ui_old

WIDTH_TYPE :: enum u8 {
	FIT,
	GROW,
}

// nil = grow to fill parent; f32 = fixed width in px.
WIDTH :: union {
	f32,
}
