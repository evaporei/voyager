package voyager

import "core:fmt"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

when ODIN_OS == .Windows {
	DIVISOR :: "\\"
} else {
	DIVISOR :: "/"
}

when ODIN_OS == .Darwin {
	// WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
	WINDOW_WIDTH, WINDOW_HEIGHT :: 1280, 720
	FONT_SIZE :: 20
	SCROLL_SPEED: f32 : 2000
} else when ODIN_OS == .Linux {
	// WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
	WINDOW_WIDTH, WINDOW_HEIGHT :: 2560, 1660
	FONT_SIZE :: 50
	SCROLL_SPEED: f32 : 100000
} else when ODIN_OS == .Windows {
	// WINDOW_WIDTH, WINDOW_HEIGHT :: 2560, 1660
	WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
	FONT_SIZE :: 50
	SCROLL_SPEED: f32 : 100000
}
FONT_SPACING :: FONT_SIZE / 10
ELEMENT_SIZE :: WINDOW_HEIGHT / FONT_SIZE

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	// rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_HIGHDPI, .MSAA_4X_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "voyager")
	defer rl.CloseWindow()

	font := rl.GetFontDefault()
	// font := rl.LoadFontEx(
	//  "very cool font.ttf"
	// 	FONT_SIZE,
	// 	nil,
	// 	0x017F,
	// )
	// rl.SetTextureFilter(font.texture, .TRILINEAR)

	dir_pool: Dir_State_Pool
	dir_state_pool_init(&dir_pool)

	init_dir: string
	if len(os.args) > 1 {
		init_dir = os.args[1]
		// TODO: should scape last slash if sent
		// if strings.ends_with(init_dir, DIVISOR) {
		// 	init_dir = init_dir[:len(init_dir) - 2]
		// }
		if ODIN_OS == .Windows {
			init_dir, _ = strings.replace_all(init_dir, "\\\\", "\\", context.temp_allocator)
		}
	} else {
		init_dir = os_get_homedir()
	}

	dir := dir_state_pool_push(&dir_pool, init_dir)

	offsets: Dir_Offsets
	dir_offsets_init(&offsets, dir^)

	outer: for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)

		mouse_pos := rl.GetMousePosition()
		mouse_clicked := rl.IsMouseButtonPressed(.LEFT)
		mouse_delta := rl.GetMouseWheelMove() * SCROLL_SPEED * rl.GetFrameTime()

		if mouse_delta != 0 {
			dir_offsets_scroll(&offsets, dir^, mouse_delta)
		}

		if rl.IsKeyPressed(.F5) {
			dir_state_reload(dir)
			dir_offsets_init(&offsets, dir^)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for &path, i in dir.files[offsets.start:offsets.end] {
			c_path := strings.clone_to_cstring(path, context.temp_allocator)
			c_file := rl.GetFileName(c_path)
			y := f32(i) * FONT_SIZE + FONT_SIZE

			rect := rl.Rectangle{0, y, WINDOW_WIDTH, FONT_SIZE}
			color := rl.Color{200, 200, 200, 100}
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				if mouse_clicked {
					if rl.DirectoryExists(c_path) {
						dir = dir_state_pool_push(&dir_pool, path)
						dir_offsets_init(&offsets, dir^)
						continue outer
					} else {
						os_open_file_w_default_app(c_path)
					}
				}
				color.rgb = rl.LIME.rgb
			} else if i % 2 != 0 {
				color.a = 0
			}
			rl.DrawRectangleRec(rect, color)
			rl.DrawTextEx(font, c_file, {0, y}, FONT_SIZE, FONT_SPACING, rl.WHITE)
		}

		rl.DrawRectangleRec({0, 0, WINDOW_WIDTH, FONT_SIZE}, rl.BLACK)

		parts := strings.split(dir.cwd, DIVISOR, context.temp_allocator)
		x: f32 = 0
		for &part, i in parts {
			c_part := strings.clone_to_cstring(part, context.temp_allocator)
			part_size := rl.MeasureTextEx(font, c_part, FONT_SIZE, FONT_SPACING)
			rect := rl.Rectangle{f32(x), 0, part_size.x, FONT_SIZE}
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				if mouse_clicked && i != len(parts) - 1 {
					up_until := parts[:i + 1]
					new_cwd := strings.join(up_until, DIVISOR, context.temp_allocator)
					dir = dir_state_pool_push(&dir_pool, new_cwd)
					dir_offsets_init(&offsets, dir^)
					break
				}
				color := rl.LIME
				color.a = 100
				rl.DrawRectangleRec(rect, color)
			}
			rl.DrawTextEx(font, c_part, {x, 0}, FONT_SIZE, FONT_SPACING, rl.WHITE)
			x += part_size.x
			when ODIN_OS == .Windows {
				divisor_w_space: cstring = " \\ "
			} else {
				divisor_w_space: cstring = " / "
			}
			rl.DrawTextEx(font, divisor_w_space, {x, 0}, FONT_SIZE, FONT_SPACING, rl.WHITE)
			x += rl.MeasureTextEx(font, divisor_w_space, FONT_SIZE, FONT_SPACING).x
		}

		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)
	}
}
