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

load_dir_files :: proc(dir: cstring) -> []string {
	c_dir_files := rl.LoadDirectoryFiles(dir)
	defer rl.UnloadDirectoryFiles(c_dir_files)
	dir_files := make([]string, c_dir_files.count)
	for i in 0 ..< c_dir_files.count {
		path := c_dir_files.paths[i]
		dir_files[i] = strings.clone_from_cstring(path)
	}
	slice.sort_by(dir_files, proc(a: string, b: string) -> bool {
		xl, yl := strings.to_lower(a), strings.to_lower(b)
		return xl < yl
	})
	return dir_files
}

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "voyager")
	defer rl.CloseWindow()

	cwd := get_homedir()
	c_cwd := strings.clone_to_cstring(cwd)
	dir_files := load_dir_files(c_cwd)

	font := rl.GetFontDefault()

	scroll_speed: f32 = 2000
	y_offset: f32 = 0

	for !rl.WindowShouldClose() {
		y: f32 = y_offset
		y_offset += rl.GetMouseWheelMove() * scroll_speed * rl.GetFrameTime()

		mouse_pos := rl.GetMousePosition()
		mouse_clicked := rl.IsMouseButtonPressed(.LEFT)

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for path, i in dir_files {
			c_path := strings.clone_to_cstring(path)
			defer delete(c_path)
			c_file := rl.GetFileName(c_path)
			if string(c_file)[0] == '.' {
				continue
			}
			y += FONT_SIZE

			// culling
			if y >= 0 && y <= WINDOW_HEIGHT {
				rect := rl.Rectangle{0, y, WINDOW_WIDTH, FONT_SIZE}
				color := rl.Color{200, 200, 200, 100}
				if rl.CheckCollisionPointRec(mouse_pos, rect) {
					if mouse_clicked && rl.DirectoryExists(c_path) {
						cwd = path
						delete(c_cwd)
						c_cwd = strings.clone_to_cstring(cwd)
						for path in dir_files do delete(path)
						delete(dir_files)
						dir_files = load_dir_files(c_cwd)
						break
					}
					color.rgb = rl.LIME.rgb
				} else if i % 2 != 0 {
					color.a = 0
				}
				rl.DrawRectangleRec(rect, color)
				rl.DrawTextEx(font, c_file, {0, y}, FONT_SIZE, FONT_SPACING, rl.WHITE)
			}
		}

		rl.DrawRectangle(0, 0, WINDOW_WIDTH, 20, rl.BLACK)

		parts := strings.split(cwd, "/")
		x: i32 = 0
		for part in parts {
			c_part := strings.clone_to_cstring(part)
			defer delete(c_part)
			rl.DrawText(c_part, x, 0, FONT_SIZE, rl.WHITE)
			x += rl.MeasureText(c_part, FONT_SIZE)
			rl.DrawText(" / ", x, 0, FONT_SIZE, rl.WHITE)
			x += rl.MeasureText(" / ", FONT_SIZE)
		}

		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)
	}
}
