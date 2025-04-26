#+build js, wasi, orca
package voyager

scan_dir_files :: proc(
	basePath: cstring,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> [dynamic]string {
    unimplemented("fs::scan_dir_files not implemented on target")
    return nil
}

open_file :: proc(file: cstring) {
    unimplemented("fs::open_file not implemented on target")
}
