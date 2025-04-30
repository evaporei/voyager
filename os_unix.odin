#+build linux, darwin, freebsd, openbsd, netbsd, haiku
package voyager

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

_os_load_dir_files :: proc(
	base_path: cstring,
	files_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> (
	files: [dynamic]string,
) {
	dir := posix.opendir(base_path)

	if dir == nil {
		fmt.println("FILEIO: Directory cannot be opened", base_path)
		return
	}
	defer posix.closedir(dir)

	files = make([dynamic]string, files_allocator)

	for dp := posix.readdir(dir); dp != nil; dp = posix.readdir(dir) {
		d_name := cstring(raw_data(&dp.d_name))
		if string(d_name) == "." || string(d_name) == ".." do continue

		b: strings.Builder
		strings.builder_init_len_cap(
			&b,
			0,
			len(d_name) + 1 + len(base_path),
			context.temp_allocator,
		)

		strings.write_string(&b, string(base_path))
		strings.write_string(&b, "/")
		strings.write_string(&b, string(d_name))

		append(&files, strings.clone(strings.to_string(b), strs_allocator))
	}

	return files
}

os_open_file_w_default_app :: proc(file: cstring) {
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
