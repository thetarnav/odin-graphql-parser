package example

import "core:os"
import "core:fmt"
import "core:mem"
import gql ".."

main :: proc() {
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