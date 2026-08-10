package app

import "../../vendor/clay"
import "core:testing"

// nil keeps the style untouched; a set squares off exactly the corners it omits.
@(test)
test_corner_radius_mask :: proc(t: ^testing.T) {
	full := clay.CornerRadius{5, 5, 5, 5}

	cases := [?]struct {
		corners: Maybe(Corners),
		want:    clay.CornerRadius,
	} {
		{nil, {5, 5, 5, 5}},
		{CORNERS_ALL, {5, 5, 5, 5}},
		{CORNERS_TOP, {5, 5, 0, 0}},
		{CORNERS_BOTTOM, {0, 0, 5, 5}},
		{CORNERS_LEFT, {5, 0, 5, 0}},
		{CORNERS_RIGHT, {0, 5, 0, 5}},
		{Corners{}, {0, 0, 0, 0}},
		{Corners{.Bottom_Right}, {0, 0, 0, 5}},
	}

	for c in cases {
		got := corner_radius_mask(full, c.corners)
		testing.expectf(t, got == c.want, "%v gave %v, want %v", c.corners, got, c.want)
	}
}

// Masking an edge zeroes only that edge, and never the between-children width.
@(test)
test_border_width_mask :: proc(t: ^testing.T) {
	full := clay.BorderWidth{1, 2, 3, 4, 5}

	kept := border_width_mask(full, nil)
	testing.expect_value(t, kept, full)

	no_left := border_width_mask(full, EDGES_ALL - {.Left})
	testing.expect_value(t, no_left.left, u16(0))
	testing.expect_value(t, no_left.right, u16(2))
	testing.expect_value(t, no_left.top, u16(3))
	testing.expect_value(t, no_left.bottom, u16(4))
	testing.expect_value(t, no_left.betweenChildren, u16(5))

	none := border_width_mask(full, Edges{})
	testing.expect_value(t, none.left, u16(0))
	testing.expect_value(t, none.top, u16(0))
	testing.expect_value(t, none.betweenChildren, u16(5))
}
