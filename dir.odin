package voyager

import "core:mem"
import vmem "core:mem/virtual"
import "core:strings"

Dir_State :: struct {
	files_arena:     vmem.Arena,
	files_allocator: mem.Allocator,
	strs_arena:      vmem.Arena,
	strs_allocator:  mem.Allocator,
	cwd:             string,
	files:           []string,
}

dir_state_init :: proc(dir: ^Dir_State) -> mem.Allocator_Error {
	vmem.arena_init_growing(&dir.files_arena, 1 * mem.Megabyte) or_return
	dir.files_allocator = vmem.arena_allocator(&dir.files_arena)
	vmem.arena_init_growing(&dir.strs_arena, 5 * mem.Megabyte) or_return
	dir.strs_allocator = vmem.arena_allocator(&dir.strs_arena)
	return .None
}

dir_state_unload :: proc(dir: ^Dir_State) {
	delete(dir.cwd)
	free_all(dir.strs_allocator)
	free_all(dir.files_allocator)
}

dir_state_load :: proc(dir: ^Dir_State, path: string) {
	dir_state_unload(dir)
	dir.cwd = strings.clone(path)
	dir.files = os_load_dir_files(dir.cwd, dir.files_allocator, dir.strs_allocator)
}

dir_state_reload :: proc(dir: ^Dir_State) {
	tmp_cwd := strings.clone(dir.cwd, context.temp_allocator)
	dir_state_load(dir, tmp_cwd)
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
		parts := strings.split(dir.files[base_start], DIVISOR)
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
