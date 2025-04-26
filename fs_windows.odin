#+build windows
package voyager

import "core:fmt"
import "core:strings"
import win32 "core:sys/windows"
import "core:slice"

scan_dir_files :: proc(
	basePath: cstring,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> [dynamic]string {
    files := make([dynamic]string, dirs_allocator)

    find_file_data: win32.WIN32_FIND_DATAW
    h_find := win32.INVALID_HANDLE_VALUE

    w_base_path := make([]u16, len(basePath) + 3, context.temp_allocator)
    for ch, i in string(basePath) {
        w_base_path[i] = u16(ch)
    }
    w_base_path[len(w_base_path) - 3] = '\\'
    w_base_path[len(w_base_path) - 2] = '*'
    w_base_path[len(w_base_path) - 1] = 0

    h_find = win32.FindFirstFileW(raw_data(w_base_path), &find_file_data)
    delete(w_base_path, context.temp_allocator)
    if h_find == win32.INVALID_HANDLE_VALUE {
        fmt.eprintln("FindFirstFile failed for file", basePath, win32.GetLastError())
        return nil
    }
    for {
        if find_file_data.cFileName[0] != '.' && !slice.equal(find_file_data.cFileName[0:2], []u16{'.', '.'}) {
            b: strings.Builder
            strings.builder_init_len_cap(
                &b,
                0,
                len(basePath) + 1 + len(find_file_data.cFileName),
                context.temp_allocator,
            )
            defer strings.builder_destroy(&b)

            strings.write_string(&b, string(basePath))
            strings.write_string(&b, "\\")
            i := 0
            for find_file_data.cFileName[i] != 0 {
                strings.write_rune(&b, rune(find_file_data.cFileName[i]))
                i += 1
            }
            append(&files, strings.clone(strings.to_string(b), strs_allocator))
        }
        if win32.FindNextFileW(h_find, &find_file_data) == transmute(win32.BOOL)i32(0) do break;
    }
    win32.FindClose(h_find)

    return files
}

open_file :: proc(file: cstring) {
    w_file := make([]u16, len(file) + 1, context.temp_allocator)
    for ch, i in string(file) {
        w_file[i] = u16(ch)
    }
    w_file[len(w_file) - 1] = 0
    win32.ShellExecuteW(nil, win32.L("open"), raw_data(w_file), nil, nil, win32.SW_SHOWNORMAL)
    delete(w_file, context.temp_allocator)
}
