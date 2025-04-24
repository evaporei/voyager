package voyage

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import rl "vendor:raylib"

WINDOW_WIDTH, WINDOW_HEIGHT :: 1280, 720
FONT_SIZE :: 20
FONT_SPACING :: FONT_SIZE / 10

get_homedir :: proc() -> string {
	when ODIN_OS == .Windows {
		return os.get_env("USERPROFILE")
	} else {
		return os.get_env("HOME")
	}
}

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "voyager")
	defer rl.CloseWindow()

	cwd := get_homedir()
	cwd_c := strings.clone_to_cstring(cwd)

	c_dir_files := rl.LoadDirectoryFiles(cwd_c)
	dir_files := c_dir_files.paths[:c_dir_files.count]
	slice.sort_by(dir_files, proc(a: cstring, b: cstring) -> bool {
		x, y := string(a), string(b)
		xl, yl := strings.to_lower(x), strings.to_lower(y)
		return xl < yl
	})

	font := rl.GetFontDefault()

	scroll_speed: f32 = 2000
	y_offset: f32 = 0

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		y: f32 = y_offset

		y_offset += rl.GetMouseWheelMove() * scroll_speed * rl.GetFrameTime()

		for path, i in dir_files {
			file := rl.GetFileName(path)
			if string(file)[0] == '.' {
				continue
			}
			y += FONT_SIZE

			// culling
			if y <= WINDOW_HEIGHT {
				rl.DrawTextEx(font, file, {0, y}, FONT_SIZE, FONT_SPACING, rl.WHITE)
				rl.DrawLineEx({0, y}, {WINDOW_WIDTH, y}, 1, rl.Color{200, 200, 200, 100})
			}
		}

		rl.DrawRectangle(0, 0, WINDOW_WIDTH, 20, rl.BLACK)
		rl.DrawText(cwd_c, 0, 0, FONT_SIZE, rl.WHITE)
		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)
	}
}
