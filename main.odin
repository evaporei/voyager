package voyager

import "base:runtime"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/posix"

import rl "vendor:raylib"

when ODIN_OS == .Darwin {
	WINDOW_WIDTH, WINDOW_HEIGHT :: 1280, 720
} else when ODIN_OS == .Linux {
	WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
}
FONT_SIZE :: 20
FONT_SPACING :: FONT_SIZE / 10
ELEMENT_SIZE :: WINDOW_HEIGHT / FONT_SIZE

get_homedir :: proc() -> string {
	when ODIN_OS == .Windows {
		return os.get_env("USERPROFILE")
	} else {
		return os.get_env("HOME")
	}
}

load_dir_files :: proc(
	dir: cstring,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> []string {
	c_dir_files := rl.LoadDirectoryFiles(dir)
	defer rl.UnloadDirectoryFiles(c_dir_files)
	dir_files := make([]string, c_dir_files.count, dirs_allocator)
	for i in 0 ..< c_dir_files.count {
		path := c_dir_files.paths[i]
		dir_files[i] = strings.clone_from_cstring(path, strs_allocator)
	}
	slice.sort_by(dir_files, proc(a: string, b: string) -> bool {
		xl, yl :=
			strings.to_lower(a, context.temp_allocator),
			strings.to_lower(b, context.temp_allocator)
		return xl < yl
	})
	return dir_files
}

open_file :: proc(file: cstring) {
	pid := posix.fork()
	if pid < 0 {
		fmt.println("kaboom man")
		os.exit(1)
	} else if pid == 0 {
		// fmt.println("child")
		when ODIN_OS == .Darwin {
			args := []cstring{"open", file, nil}
			os.exit(int(posix.execv("/usr/bin/open", raw_data(args))))
		} else when ODIN_OS == .Linux {
			args := []cstring{"xdg-open", file, nil}
			os.exit(int(posix.execv("/usr/bin/xdg-open", raw_data(args))))
		}
	} else {
		// fmt.println("woo parent!")
	}
}

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "voyager")
	defer rl.CloseWindow()

	dirs_arena: vmem.Arena
	err := vmem.arena_init_growing(&dirs_arena, 5 * mem.Megabyte)
	assert(err == .None)
	dirs_allocator := vmem.arena_allocator(&dirs_arena)

	strs_arena: vmem.Arena
	err = vmem.arena_init_growing(&strs_arena, 5 * mem.Megabyte)
	assert(err == .None)
	strs_allocator := vmem.arena_allocator(&strs_arena)

	cwd := strings.clone(get_homedir())
	// cwd := strings.clone("/Volumes/nas/slow/music")
	c_cwd := strings.clone_to_cstring(cwd)
	dir_files := load_dir_files(c_cwd, dirs_allocator, strs_allocator)

	font := rl.GetFontDefault()

	scroll_speed: f32 = 2000

	base_start := 0
	for base_start < len(dir_files) {
		parts := strings.split(dir_files[base_start], "/")
		if strings.starts_with(parts[len(parts) - 1], ".") {
			base_start += 1
		} else {
			break
		}
	}
	start := base_start
	end := min(ELEMENT_SIZE + start, len(dir_files))
	// fmt.println(len(dir_files), base_start, start, end)
	bigger_than_screen := len(dir_files) - base_start >= ELEMENT_SIZE
	base_y_offset: f32 = f32(start - 0) * -ELEMENT_SIZE / 2
	y_offset: f32 = base_y_offset

	outer: for !rl.WindowShouldClose() {
		offset := rl.GetMouseWheelMove() * scroll_speed * rl.GetFrameTime()

		mouse_pos := rl.GetMousePosition()
		mouse_clicked := rl.IsMouseButtonPressed(.LEFT)

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		// fmt.println(len(dir_files) - base_start, WINDOW_HEIGHT / FONT_SIZE)
		if offset != 0 && bigger_than_screen {
			// if offset != 0 {
			// fmt.println(
			// 	"wheelMove() =",
			// 	rl.GetMouseWheelMove(),
			// 	" offset =",
			// 	offset,
			// 	" y_offset =",
			// 	y_offset,
			// )
			// y_offset = max(min(0, y_offset + offset), -WINDOW_HEIGHT * 1.5)
			y_offset = max(
				min(y_offset + offset, base_y_offset), // y_offset + offset,
				-f32(len(dir_files)) * FONT_SIZE,
			)
			// maybe use base_y_offset here instead of int(-y_offset) / FONT_SIZE
			start = max(base_start, min(int(-y_offset) / FONT_SIZE, len(dir_files) - 1))
			end = max(1, min(ELEMENT_SIZE + start, len(dir_files)))
			// fmt.println(start, end)
		}
		// fmt.println(start, end)

		for path, i in dir_files[start:end] {
			c_path := strings.clone_to_cstring(path, context.temp_allocator)
			defer delete(c_path, context.temp_allocator)
			c_file := rl.GetFileName(c_path)
			y := f32(i) * FONT_SIZE + FONT_SIZE

			rect := rl.Rectangle{0, y, WINDOW_WIDTH, FONT_SIZE}
			color := rl.Color{200, 200, 200, 100}
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				if mouse_clicked {
					if rl.DirectoryExists(c_path) {
						delete(cwd)
						cwd = strings.clone(path)
						delete(c_cwd)
						c_cwd = strings.clone_to_cstring(cwd)
						free_all(strs_allocator)
						free_all(dirs_allocator)
						dir_files = load_dir_files(c_cwd, dirs_allocator, strs_allocator)
						base_start = 0
						for base_start < len(dir_files) {
							parts := strings.split(dir_files[base_start], "/")
							if strings.starts_with(parts[len(parts) - 1], ".") {
								base_start += 1
							} else {
								break
							}
						}
						start = base_start
						end = min(ELEMENT_SIZE + start, len(dir_files))
						bigger_than_screen = len(dir_files) - base_start > ELEMENT_SIZE
						base_y_offset = f32(start - 0) * -ELEMENT_SIZE
						y_offset = base_y_offset
						// fmt.println(len(dir_files), start, end)
						continue outer
					} else {
						open_file(c_path)
					}
				}
				color.rgb = rl.LIME.rgb
			} else if i % 2 != 0 {
				color.a = 0
			}
			rl.DrawRectangleRec(rect, color)
			rl.DrawTextEx(font, c_file, {0, y}, FONT_SIZE, FONT_SPACING, rl.WHITE)
		}

		rl.DrawRectangle(0, 0, WINDOW_WIDTH, 20, rl.BLACK)

		parts := strings.split(cwd, "/")
		x: i32 = 0
		for part, i in parts {
			c_part := strings.clone_to_cstring(part, context.temp_allocator)
			defer delete(c_part, context.temp_allocator)
			part_size := rl.MeasureText(c_part, FONT_SIZE)
			rect := rl.Rectangle{f32(x), 0, f32(part_size), FONT_SIZE}
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				if mouse_clicked && i != len(parts) - 1 {
					up_until := parts[:i + 1]
					new_cwd := strings.join(up_until, "/")
					delete(cwd)
					cwd = new_cwd
					delete(c_cwd)
					c_cwd = strings.clone_to_cstring(cwd)
					free_all(strs_allocator)
					free_all(dirs_allocator)
					dir_files = load_dir_files(c_cwd, dirs_allocator, strs_allocator)
					base_start = 0
					for base_start < len(dir_files) {
						parts := strings.split(dir_files[base_start], "/")
						if strings.starts_with(parts[len(parts) - 1], ".") {
							base_start += 1
						} else {
							break
						}
					}
					start = base_start
					end = min(ELEMENT_SIZE + start, len(dir_files))
					bigger_than_screen = len(dir_files) - base_start > ELEMENT_SIZE
					base_y_offset = f32(start - 0) * -ELEMENT_SIZE
					y_offset = base_y_offset
					// fmt.println(len(dir_files), start, end)
					break
				}
				color := rl.LIME
				color.a = 100
				rl.DrawRectangleRec(rect, color)
			}
			rl.DrawText(c_part, x, 0, FONT_SIZE, rl.WHITE)
			x += part_size
			rl.DrawText(" / ", x, 0, FONT_SIZE, rl.WHITE)
			x += rl.MeasureText(" / ", FONT_SIZE)
		}

		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)

		free_all(context.temp_allocator)
	}
	// fmt.println(dirs_arena.total_used)
	// fmt.println(strs_arena.total_used)
}
