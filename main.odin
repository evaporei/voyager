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
	// WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
	WINDOW_WIDTH, WINDOW_HEIGHT :: 1280, 720
	FONT_SIZE :: 20
	SCROLL_SPEED: f32 : 2000
} else when ODIN_OS == .Linux {
	// WINDOW_WIDTH, WINDOW_HEIGHT :: 1920, 1080
	WINDOW_WIDTH, WINDOW_HEIGHT :: 2560, 1660
	FONT_SIZE :: 50
	SCROLL_SPEED: f32 : 100000
}
FONT_SPACING :: FONT_SIZE / 10
ELEMENT_SIZE :: WINDOW_HEIGHT / FONT_SIZE

get_homedir :: proc() -> string {
	when ODIN_OS == .Windows {
		return os.get_env("USERPROFILE")
	} else {
		return os.get_env("HOME")
	}
}

// Scan all files and directories in a base path
// WARNING: files.paths[] must be previously allocated and
// contain enough space to store all required paths
my_scan_dir_files :: proc(
	basePath: cstring,
	files: ^[dynamic]string,
	allocator := context.allocator,
) {
	dp: ^posix.dirent
	dir := posix.opendir(basePath)
	i := 0

	if dir != nil {
		dp = posix.readdir(dir)
		for dp != nil {
			d_name := cstring(raw_data(&dp.d_name))
			if string(d_name) != "." && string(d_name) != ".." {
				b: strings.Builder
				strings.builder_init_len_cap(
					&b,
					0,
					len(d_name) + 1 + len(basePath),
					context.temp_allocator,
				)
				defer strings.builder_destroy(&b)

				strings.write_string(&b, string(basePath))
				when ODIN_OS == .Windows {
					strings.write_string(&b, "\\")
				} else {
					strings.write_string(&b, "/")
				}
				strings.write_string(&b, string(d_name))

				files[i] = strings.clone(strings.to_string(b), allocator)
				i += 1
			}
			dp = posix.readdir(dir)
		}
		posix.closedir(dir)
	} else {
		fmt.println("FILEIO: Directory cannot be opened", basePath)
	}
}

my_load_dir_files :: proc(
	dirPath: cstring,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> (
	files: [dynamic]string,
) {
	entity: ^posix.dirent
	dir := posix.opendir(dirPath)
	counter := 0

	// It's a directory
	if dir != nil {
		entity = posix.readdir(dir)
		for entity != nil {
			d_name := cstring(raw_data(&entity.d_name))
			if string(d_name) != "." && string(d_name) != ".." {
				counter += 1
			}
			entity = posix.readdir(dir)
		}

		files = make([dynamic]string, counter, dirs_allocator)
		posix.closedir(dir)
		my_scan_dir_files(dirPath, &files, strs_allocator)
	} else {
		fmt.println("FILEIO: Failed to open requested directory") // Maybe it's a file...
	}

	return
}

load_dir_files :: proc(
	dir: string,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> []string {
	c_dir := strings.clone_to_cstring(dir, context.temp_allocator)
	dir_files := my_load_dir_files(c_dir, dirs_allocator, strs_allocator)
	delete(c_dir, context.temp_allocator)
	slice.sort_by(dir_files[:], proc(a: string, b: string) -> bool {
		xl, yl :=
			strings.to_lower(a, context.temp_allocator),
			strings.to_lower(b, context.temp_allocator)
		return xl < yl
	})
	return dir_files[:]
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

Dir_State :: struct {
	dirs_arena:     vmem.Arena,
	dirs_allocator: mem.Allocator,
	strs_arena:     vmem.Arena,
	strs_allocator: mem.Allocator,
	cwd:            string,
	files:          []string,
}

dir_state_init :: proc(dir: ^Dir_State) -> mem.Allocator_Error {
	vmem.arena_init_growing(&dir.dirs_arena, 1 * mem.Megabyte) or_return
	dir.dirs_allocator = vmem.arena_allocator(&dir.dirs_arena)
	vmem.arena_init_growing(&dir.strs_arena, 5 * mem.Megabyte) or_return
	dir.strs_allocator = vmem.arena_allocator(&dir.strs_arena)
	return .None
}

dir_state_load :: proc(dir: ^Dir_State, path: string) {
	dir_state_unload(dir)
	dir.cwd = strings.clone(path)
	dir.files = load_dir_files(dir.cwd, dir.dirs_allocator, dir.strs_allocator)
}

dir_state_unload :: proc(dir: ^Dir_State) {
	delete(dir.cwd)
	free_all(dir.strs_allocator)
	free_all(dir.dirs_allocator)
}

Dir_Offsets :: struct {
	base_start, start, end:  int,
	base_y_offset, y_offset: f32,
	bigger_than_screen:      bool,
}

dir_offsets_init :: proc(offsets: ^Dir_Offsets, dir: Dir_State) {
	using offsets
	base_start = 0
	for base_start < len(dir.files) {
		parts := strings.split(dir.files[base_start], "/")
		if strings.starts_with(parts[len(parts) - 1], ".") {
			base_start += 1
		} else {
			break
		}
	}
	start = base_start
	end = min(ELEMENT_SIZE + start, len(dir.files))
	bigger_than_screen = len(dir.files) - base_start >= ELEMENT_SIZE
	base_y_offset = f32(start - 0) * -ELEMENT_SIZE / 2
	y_offset = base_y_offset
}

dir_offsets_scroll :: proc(offsets: ^Dir_Offsets, dir: Dir_State, mouse_delta: f32) {
	using offsets
	if !bigger_than_screen do return
	y_offset = max(min(y_offset + mouse_delta, base_y_offset), -f32(len(dir.files)) * FONT_SIZE)
	// maybe use base_y_offset here instead of int(-y_offset) / FONT_SIZE
	start = max(base_start, min(int(-y_offset) / FONT_SIZE, len(dir.files) - 1))
	end = max(1, min(ELEMENT_SIZE + start, len(dir.files)))
}

POOL_CAP :: 10
Dir_State_Pool :: struct {
	dirs:  [POOL_CAP]Dir_State,
	count: int,
}

dir_state_pool_init :: proc(pool: ^Dir_State_Pool) {
	for &dir in &pool.dirs do assert(dir_state_init(&dir) == .None)
}

dir_state_pool_push :: proc(pool: ^Dir_State_Pool, path: string) -> ^Dir_State {
	for &dir in &pool.dirs {
		if dir.cwd == path {
			return &dir
		}
	}

	count := pool.count % POOL_CAP
	dir_state_load(&pool.dirs[count], path)
	pool.count = count + 1
	return &pool.dirs[count]
}

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
	} else {
		init_dir = get_homedir()
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

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for &path, i in dir.files[offsets.start:offsets.end] {
			c_path := strings.clone_to_cstring(path, context.temp_allocator)
			defer delete(c_path, context.temp_allocator)
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

		rl.DrawRectangleRec({0, 0, WINDOW_WIDTH, FONT_SIZE}, rl.BLACK)

		parts := strings.split(dir.cwd, "/")
		x: f32 = 0
		for &part, i in parts {
			c_part := strings.clone_to_cstring(part, context.temp_allocator)
			defer delete(c_part, context.temp_allocator)
			part_size := rl.MeasureTextEx(font, c_part, FONT_SIZE, FONT_SPACING)
			rect := rl.Rectangle{f32(x), 0, part_size.x, FONT_SIZE}
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				if mouse_clicked && i != len(parts) - 1 {
					up_until := parts[:i + 1]
					new_cwd := strings.join(up_until, "/", context.temp_allocator)
					dir = dir_state_pool_push(&dir_pool, new_cwd)
					delete(new_cwd, context.temp_allocator)
					dir_offsets_init(&offsets, dir^)
					break
				}
				color := rl.LIME
				color.a = 100
				rl.DrawRectangleRec(rect, color)
			}
			rl.DrawTextEx(font, c_part, {x, 0}, FONT_SIZE, FONT_SPACING, rl.WHITE)
			x += part_size.x
			rl.DrawTextEx(font, " / ", {x, 0}, FONT_SIZE, FONT_SPACING, rl.WHITE)
			x += rl.MeasureTextEx(font, " / ", FONT_SIZE, FONT_SPACING).x
		}

		rl.DrawLine(0, FONT_SIZE, WINDOW_WIDTH, FONT_SIZE, rl.SKYBLUE)
	}
}
