package app

import "../../vendor/clay"
import "core:fmt"
import "core:strconv"
import "core:strings"
import sdl "vendor:sdl3"

project_view :: proc(ctx: ^Ctx, edtr: ^Editor) {
	if edtr.project == nil do return

	if edtr.project.initialized {
		if edtr.tab == .Project {
			if clay.UI(clay.ID("project:row_top"))(
			{
				layout = grid_group_layout(
					.LeftToRight,
					{
						width = clay.SizingGrow(),
						height = grid_row(
							&edtr.grid,
							"top",
							{frac = 0.8, min_frac = 0.2, min_px = 250},
						),
					},
				),
			},
			) {
				if clay.UI(clay.ID("project:overview"))(
				{
					layout = {
						sizing = {
							width = grid_col(
								&edtr.grid,
								"overview",
								{frac = 0.7, min_frac = 0.3, min_px = 250},
							),
							height = clay.SizingGrow(),
						},
						padding = {10, 10, 10, 10},
						layoutDirection = .TopToBottom,
						childGap = 15,
					},
					cornerRadius = {10, 10, 10, 10},
					backgroundColor = COLOR_GREY_850,
				},
				) {

				}

				grid_seam(ctx, &edtr.grid, .X, "overview")

				// SETTINGS
				if clay.UI(clay.ID("project:settings"))(
				{
					layout = {
						sizing = {
							width = grid_col(
								&edtr.grid,
								"settings",
								{frac = 0.3, min_frac = 0.3, min_px = 300},
							),
							height = clay.SizingGrow(),
						},
						padding = {10, 10, 10, 10},
						layoutDirection = .TopToBottom,
						childGap = 10,
					},
					cornerRadius = {10, 10, 10, 10},
					backgroundColor = COLOR_GREY_850,
				},
				) {
					if clay.UI(clay.ID("project:settings:inner"))(
					{
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							padding = {10, 10, 10, 10},
							layoutDirection = .TopToBottom,
							childGap = 15,
						},
						cornerRadius = {10, 10, 10, 10},
						backgroundColor = COLOR_GREY_805,
					},
					) {

						text(ctx.frame.assets, "Project", .UI_BLD_13, COLOR_GREY_150)

						if clay.UI(clay.ID("project:settings:location_inputs"))(
						{
							layout = {
								sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
								layoutDirection = .TopToBottom,
								childGap = 1,
							},
						},
						) {
							if clay.UI(clay.ID("project:settings:project_name"))(
							{
								layout = {
									sizing = {
										width = clay.SizingGrow(),
										height = clay.SizingFit(),
									},
									layoutDirection = .LeftToRight,
									childAlignment = {y = .Center},
									childGap = 20,
								},
							},
							) {
								if clay.UI(clay.ID("project:settings:project_name:left"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow(),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
									},
								},
								) {
									text(
										ctx.frame.assets,
										"Project Name",
										.UI_REG_13,
										COLOR_GREY_340,
									)
								}

								if clay.UI(clay.ID("project:settings:project_name:right"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow({min = 120, max = 250}),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
										childGap = 1,
									},
								},
								) {
									proj_name := text_input(
										ctx,
										"project:settings:name_input",
										project_name_get(edtr.project),
										{
											placeholder = "Untitled Project",
											width = .Grow,
											submits = true,
											transform = project_name_transform,
											corners = Corners{.Top_Right, .Top_Left},
										},
									)
									if proj_name.submitted {
										name := strings.trim_space(proj_name.text)
										if name == "" {
											status_text_set(
												edtr,
												"Project name cannot be empty",
												.Error,
											)
										} else {
											project_name_set(edtr.project, name)
										}
									}
									if proj_name.rejected {
										status_text_set(
											edtr,
											fmt.tprintf(
												"Project name is limited to %d characters",
												PROJECT_NAME_MAX_RUNES,
											),
											.Warning,
										)
									}
								}
							}

							if clay.UI(clay.ID("project:settings:project_loc"))(
							{
								layout = {
									sizing = {
										width = clay.SizingGrow(),
										height = clay.SizingFit(),
									},
									layoutDirection = .LeftToRight,
									childAlignment = {y = .Center},
									childGap = 20,
								},
							},
							) {
								if clay.UI(clay.ID("project:settings:project_loc:left"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow(),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
									},
								},
								) {
									text(
										ctx.frame.assets,
										"Project Location",
										.UI_REG_13,
										COLOR_GREY_340,
									)
								}

								if clay.UI(clay.ID("project:settings:loc_input:right"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow({min = 120, max = 250}),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
										childGap = 1,
									},
								},
								) {
									proj_loc := text_input(
										ctx,
										"project:settings:loc_input",
										project_loc_get(edtr.project),
										{
											placeholder = "~/Plastella Projects/",
											width = .Grow,
											submits = true,
											corners = Corners{.Bottom_Left},
										},
									)

									if btn, open := button_box(
										ctx,
										"project:settings:loc_button",
										{corners = Corners{.Bottom_Right}},
									); open {
										icon_h := f32(text_styles[btn.font].size)
										icon(
											ctx,
											"project:settings:loc_button:icon",
											.Project,
											icon_h,
											btn.fg,
										)

										if btn.clicked {
											sdl.ShowOpenFolderDialog(
												project_path_set_cb,
												nil,
												app.device.window,
												strings.clone_to_cstring(
													project_loc_get(edtr.project),
													context.temp_allocator,
												),
												false,
											)
										}
									}

									if proj_loc.submitted {
										path := strings.trim_space(proj_loc.text)
										if path == "" {
											status_text_set(
												edtr,
												"Project location cannot be empty",
												.Error,
											)
										} else {
											project_loc_set(edtr.project, path)
										}
									}
									if proj_loc.rejected {
										status_text_set(
											edtr,
											"Project location is not a valid path on your system",
											.Warning,
										)
									}
								}
							}
						}

						text(ctx.frame.assets, "Configuration", .UI_BLD_13, COLOR_GREY_150)

						if clay.UI(clay.ID("project:settings:config_inputs"))(
						{
							layout = {
								sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
								layoutDirection = .TopToBottom,
								childGap = 1,
							},
						},
						) {
							if clay.UI(clay.ID("project:settings:project_tilesize"))(
							{
								layout = {
									sizing = {
										width = clay.SizingGrow(),
										height = clay.SizingFit(),
									},
									layoutDirection = .LeftToRight,
									childAlignment = {y = .Center},
									childGap = 20,
								},
							},
							) {
								if clay.UI(clay.ID("project:settings:project_tile_size:left"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow(),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
									},
								},
								) {
									text(ctx.frame.assets, "Tile Size", .UI_REG_13, COLOR_GREY_340)
								}

								if clay.UI(clay.ID("project:settings:project_tile_size:right"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow({min = 120, max = 250}),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
										childGap = 1,
									},
								},
								) {
									tile_size := number_input(
										ctx,
										"project:settings:tile_size_input",
										project_tile_size_get(edtr.project),
										{
											step_proc = increment_tile_size,
											lo = f32(16),
											hi = f32(256),
											format = tile_size_fmt,
											width = .Grow,
										},
									)
									if tile_size.changed {
										project_tile_size_set(edtr.project, tile_size.value)
									}
									if tile_size.invalid {
										status_text_set(edtr, "Tile size must be a number", .Error)
									}
									if tile_size.snapped {
										status_text_set(
											edtr,
											"Tile size must be a power of four",
											.Warning,
										)
									}
									if tile_size.clamped {
										status_text_set(
											edtr,
											fmt.tprintf(
												"Tile size must be between %d and %d",
												16,
												256,
											),
											.Warning,
										)
									}
								}
							}

							if clay.UI(clay.ID("project:settings:project_start_lives"))(
							{
								layout = {
									sizing = {
										width = clay.SizingGrow(),
										height = clay.SizingFit(),
									},
									layoutDirection = .LeftToRight,
									childAlignment = {y = .Center},
									childGap = 20,
								},
							},
							) {
								if clay.UI(clay.ID("project:settings:project_start_lives:left"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow(),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
									},
								},
								) {
									text(
										ctx.frame.assets,
										"Starting Lives",
										.UI_REG_13,
										COLOR_GREY_340,
									)
								}

								if clay.UI(clay.ID("project:settings:project_start_lives:right"))(
								{
									layout = {
										sizing = {
											width = clay.SizingGrow({min = 120, max = 250}),
											height = clay.SizingFit(),
										},
										layoutDirection = .LeftToRight,
										childAlignment = {x = .Right, y = .Center},
										childGap = 1,
									},
								},
								) {
									lives := number_input(
										ctx,
										"project:settings:start_lives_input",
										f32(project_start_lives_get(edtr.project)),
										{step = 1, lo = f32(1), hi = f32(99), width = .Grow},
									)
									if lives.changed {
										project_start_lives_set(edtr.project, i16(lives.value))
									}
									if lives.invalid {
										status_text_set(
											edtr,
											"Starting lives must be a number",
											.Error,
										)
									}
									if lives.clamped {
										status_text_set(
											edtr,
											fmt.tprintf(
												"Starting lives must be between %d and %d",
												1,
												99,
											),
											.Warning,
										)
									}
								}
							}
						}
					}
				}
			}

			grid_seam(ctx, &edtr.grid, .Y, "top")

			if clay.UI(clay.ID("project:bottom"))(
			{
				layout = {
					sizing = {
						width = clay.SizingGrow(),
						height = grid_row(
							&edtr.grid,
							"bottom",
							{frac = 0.2, min_frac = 0.15, min_px = 200, max_px = 400},
						),
					},
					padding = {10, 10, 10, 10},
					layoutDirection = .TopToBottom,
					childGap = 15,
				},
				cornerRadius = {10, 10, 10, 10},
				backgroundColor = COLOR_GREY_850,
			},
			) {}
		}
	}

	if !edtr.project.initialized {
		if clay.UI(clay.ID("no_project"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
			},
		},
		) {
			if clay.UI(clay.ID("no_project:inner"))(
			{
				layout = {
					sizing = {width = clay.SizingFixed(250), height = clay.SizingPercent(0.5)},
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Center, y = .Center},
					childGap = 20,
				},
			},
			) {
				image(ctx, "no_project:logo", .Logo, 200)
				if clay.UI(clay.ID("no_project:quick_actions"))(
				{
					layout = {
						sizing = {width = clay.SizingGrow()},
						layoutDirection = .TopToBottom,
						childAlignment = {x = .Center, y = .Center},
						childGap = 8,
					},
				},
				) {
					if btn, open := button_box(
						ctx,
						"no_project:button_new",
						{theme = .Wide_Action},
					); open {
						if clay.UI(clay.ID("no_project:button_new:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "no_project:button_new:icon", .Add, 14, btn.fg)
							text(ctx.frame.assets, "New Project", btn.font, btn.fg, .Center, .None)
						}
						text(ctx.frame.assets, "Cmd + N", .UI_REG_12, btn.fg)

						if btn.clicked do project_init(edtr.project)
					}
					if btn, open := button_box(
						ctx,
						"no_project:button_open",
						{theme = .Wide_Action},
					); open {
						if clay.UI(clay.ID("no_project:button_open:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "no_project:button_open:icon", .Project, 14, btn.fg)
							text(
								ctx.frame.assets,
								"Open Project",
								btn.font,
								btn.fg,
								.Center,
								.None,
							)
						}
						text(ctx.frame.assets, "Cmd + O", .UI_REG_12, btn.fg)

						if btn.clicked {
							// TODO: Open a project file here
						}
					}
				}
			}
		}
	}
}

@(private = "file")
project_path_set_cb :: proc "c" (_: rawptr, file_list: [^]cstring, _: i32) {
	context = app.ctx
	if file_list == nil || file_list[0] == nil do return
	project_loc_set(&app.project, string(file_list[0]))
	app.frames_owed = max(app.frames_owed, 1)
}

tile_size_fmt :: proc(value: f32, buf: []u8) -> string {
	n := len(strconv.write_int(buf, i64(value), 10))
	n += copy(buf[n:], " px")
	return string(buf[:n])
}

increment_tile_size :: proc(val: f32, dir: int) -> f32 {
	return val * 4 if dir > 0 else val / 4
}
