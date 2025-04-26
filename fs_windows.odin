#+build windows
package voyager

import "core:fmt"
import "core:slice"
import "core:strings"
import win32 "core:sys/windows"

os_load_dir_files :: proc(
	base_path: cstring,
	files_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> (
	files: [dynamic]string,
) {
	bb: strings.Builder
	strings.builder_init_len_cap(&bb, 0, len(base_path) + 2, context.temp_allocator)
	strings.write_string(&bb, string(base_path))
	strings.write_string(&bb, "\\*")
	w_base_path := win32.utf8_to_utf16(strings.to_string(bb), context.temp_allocator)

	find_file_data: win32.WIN32_FIND_DATAW
	h_find := win32.FindFirstFileW(raw_data(w_base_path), &find_file_data)
	delete(w_base_path, context.temp_allocator)
	strings.builder_destroy(&bb)
	if h_find == win32.INVALID_HANDLE_VALUE {
		fmt.eprintln("FindFirstFile failed for file", base_path, win32.GetLastError())
		return
	}
	defer win32.FindClose(h_find)

	files = make([dynamic]string, files_allocator)
	for {
		if find_file_data.cFileName[0] != '.' &&
		   !slice.equal(find_file_data.cFileName[0:2], []u16{'.', '.'}) {
			b: strings.Builder
			strings.builder_init_len_cap(
				&b,
				0,
				len(base_path) + 1 + len(find_file_data.cFileName),
				context.temp_allocator,
			)
			defer strings.builder_destroy(&b)

			strings.write_string(&b, string(base_path))
			strings.write_string(&b, "\\")
			for i := 0; find_file_data.cFileName[i] != 0; i += 1 {
				strings.write_rune(&b, rune(find_file_data.cFileName[i]))
			}
			append(&files, strings.clone(strings.to_string(b), strs_allocator))
		}
		if win32.FindNextFileW(h_find, &find_file_data) == transmute(win32.BOOL)i32(0) do break
	}

	return files
}

os_open_file_w_default_app :: proc(file: cstring) {
	w_file := win32.utf8_to_utf16(string(file), context.temp_allocator)
	win32.ShellExecuteW(nil, win32.L("open"), raw_data(w_file), nil, nil, win32.SW_SHOWNORMAL)
	delete(w_file, context.temp_allocator)
}
