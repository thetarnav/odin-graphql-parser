package example

import "core:os"
import "core:fmt"
import "core:mem"
import gql ".."

when ODIN_OS == .Windows {
	// foreign import io "io.h"
	
	// foreign io {
	// 	_isatty :: proc(fd: os.Handle) -> b32 ---
	// }

	is_terminal :: proc(fd: os.Handle) -> bool {
		return false // TODO
	}
} else {
	foreign import libc "system:c"

	foreign libc {
		@(link_name = "isatty")
		_isatty :: proc(fd: os.Handle) -> b32 ---
	}
	
	is_terminal :: proc(fd: os.Handle) -> bool {
		return bool(_isatty(fd))
	}
}


main :: proc() {
	if is_terminal(os.stdin) {
		fmt.println("\e[0;36mEnter a GraphQL query or schema:\e[0m")
	}

	buf := make([]byte, mem.Megabyte * 10)
	input_len, err := os.read(os.stdin, buf[:])
	input_str := string(buf[:input_len])

	if err != os.ERROR_NONE {
		fmt.panicf("error reading input: %d", err)
	}

	t: gql.Tokenizer
	gql.tokenizer_init(&t, input_str)

	for token in gql.next_token(&t) {
		fmt.printf("\e[0;32m%s\e[0m %s\n", token.kind, token.value)
	}
}