package voyager

import "core:os"
import "core:slice"
import "core:strings"

get_homedir :: proc() -> string {
	when ODIN_OS == .Windows {
		return os.get_env("USERPROFILE")
	} else {
		return os.get_env("HOME")
	}
}

load_dir_files :: proc(
	dir: string,
	files_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> []string {
	c_dir := strings.clone_to_cstring(dir, context.temp_allocator)
	dir_files := os_load_dir_files(c_dir, files_allocator, strs_allocator)
	delete(c_dir, context.temp_allocator)
	slice.sort_by(dir_files[:], proc(a: string, b: string) -> bool {
		return(
			strings.to_lower(a, context.temp_allocator) <
			strings.to_lower(b, context.temp_allocator) \
		)
	})
	return dir_files[:]
}
