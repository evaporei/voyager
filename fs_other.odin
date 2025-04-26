#+build js, wasi, orca
package voyager

_os_load_dir_files :: proc(
	base_path: cstring,
	files_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> [dynamic]string {
	unimplemented("fs::_os_load_dir_files not implemented on target")
	return nil
}

os_open_file_w_default_app :: proc(file: cstring) {
	unimplemented("fs::os_open_file_w_default_app not implemented on target")
}
