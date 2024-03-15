package gql

import "core:fmt"
import test "core:testing"

Expect_Tokens_Case :: struct {
	name    : string,
	src     : string,
	expected: []Token,
}

expected_list := []Expect_Tokens_Case {
	{
		"empty",
		"",
		{},
	},
	{
		"zero",
		"0",
		{
			{.Int, "0"},
		},
	},
}

@(test)
test_tokenizer_cases :: proc(t: ^test.T) {
	tokens := make([dynamic]Token, 0, 10)

	for test_case in expected_list {
		tokenizer: Tokenizer
		tokenizer_init(&tokenizer, test_case.src)

		for {
			token := next_token(&tokenizer) or_break
			append(&tokens, token)
		}
		defer clear_dynamic_array(&tokens)

		if len(tokens) != len(test_case.expected) {
			test.errorf(t, "test case %q: expected %d tokens, got %d", test_case.name, len(test_case.expected), len(tokens))
			continue
		}
	}
}