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

	// example_tokenizer(input_str)
	example_parser(input_str)
}

example_tokenizer :: proc(input: string) {
	t := gql.make_tokenizer(input)

	for token in gql.next_token(&t) {
		fmt.printf("\e[0;32m%s\e[0m %s\n", token.kind, token.value)
	}
}

example_parser :: proc(input: string) {
	schema := gql.schema_make()
	err := gql.schema_parse(&schema, input)
    defer gql.schema_delete(schema)

    if err != nil {
        fmt.printfln("Error parsing schema: %v", err)
        return
    }

    for type in schema.types {
        fmt.printfln("Type: %s", type.name)
    }
}