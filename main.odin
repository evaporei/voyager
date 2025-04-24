package voyage

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import rl "vendor:raylib"

WINDOW_WIDTH, WINDOW_HEIGHT :: 1280, 720
FONT_SIZE :: 20

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
	slice.sort(dir_files)

	// for i in 0 ..< dir_files.count {
	// 	path := rl.GetFileName(dir_files.paths[i])
	// 	fmt.println(strings.clone_from_cstring(path))
	// }

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		y: i32 = 0
		// rl.DrawRectangle(0, 0, WINDOW_WIDTH, 20, rl.Color{1.0, 0.0, 0.0, 1.0})
		rl.DrawText(cwd_c, 0, y, FONT_SIZE, rl.WHITE)

		for path, i in dir_files {
			file := rl.GetFileName(path)
			if string(file)[0] == '.' {
				continue
			}
			y += FONT_SIZE

			// culling
			if y <= WINDOW_HEIGHT {
				rl.DrawText(file, 0, y, FONT_SIZE, rl.WHITE)
				rl.DrawLine(0, FONT_SIZE * i32(i), WINDOW_WIDTH, FONT_SIZE * i32(i), rl.LIGHTGRAY)
			}
		}

		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)
	}
}
