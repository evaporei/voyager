#+build linux, darwin, freebsd, openbsd, netbsd, haiku
package voyager

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

scan_dir_files :: proc(
	basePath: cstring,
	dirs_allocator := context.allocator,
	strs_allocator := context.allocator,
) -> [dynamic]string {
	files := make([dynamic]string, dirs_allocator)

	dp: ^posix.dirent
	dir := posix.opendir(basePath)

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
				strings.write_string(&b, "/")
				strings.write_string(&b, string(d_name))

				append(&files, strings.clone(strings.to_string(b), strs_allocator))
			}
			dp = posix.readdir(dir)
		}
		posix.closedir(dir)
	} else {
		fmt.println("FILEIO: Directory cannot be opened", basePath)
	}

	return files
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
