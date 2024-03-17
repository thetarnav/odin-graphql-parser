package gql

import "core:fmt"
import test "core:testing"

Expect_Tokens_Case :: struct {
	name    : string,
	src     : string,
	expected: []Token,
}

expected_list := []Expect_Tokens_Case {
	{   "empty",
		"",
		{},
	},
	/*
	Punctuators
	*/
	{   "Parenthesis_Left",
		"(",
		{{.Parenthesis_Left, "("}},
	},
	{   "Parenthesis_Right",
		")",
		{{.Parenthesis_Right, ")"}},
	},
	{   "Bracket_Left",
		"[",
		{{.Bracket_Left, "["}},
	},
	{   "Bracket_Right",
		"]",
		{{.Bracket_Right, "]"}},
	},
	{   "Brace_Left",
		"{",
		{{.Brace_Left, "{"}},
	},
	{   "Brace_Right",
		"}",
		{{.Brace_Right, "}"}},
	},
	{   "Colon",
		":",
		{{.Colon, ":"}},
	},
	{   "Equals",
		"=",
		{{.Equals, "="}},
	},
	{   "At",
		"@",
		{{.At, "@"}},
	},
	{   "Dollar",
		"$",
		{{.Dollar, "$"}},
	},
	{   "Exclamation",
		"!",
		{{.Exclamation, "!"}},
	},
	{   "Vertical_Bar",
		"|",
		{{.Vertical_Bar, "|"}},
	},
	{   "Spread",
		"...",
		{{.Spread, "..."}},
	},
	/*
	Int and Float
	*/
	{   "zero",
		"0",
		{{.Int, "0"}},
	},
	{   "int",
		"123",
		{{.Int, "123"}},
	},
	{   "invalid int",
		"0123",
		{{.Invalid, "0"}, {.Int, "123"}},
	},
	{   "float",
		"123.456",
		{{.Float, "123.456"}},
	},
	{   "invalid float",
		"123.",
		{{.Invalid, "123."}},
	},
	{   "float zero",
		"0.456",
		{{.Float, "0.456"}},
	},
	{   "negative int",
		"-123",
		{{.Int, "-123"}},
	},
	{   "negative float",
		"-123.456",
		{{.Float, "-123.456"}},
	},
	{   "negative float zero",
		"-0.456",
		{{.Float, "-0.456"}},
	},
	/*
	Keywords
	*/
	{   "Query",
	    "query",
		{{.Query, "query"}},
	},
	{   "Mutation",
	    "mutation",
		{{.Mutation, "mutation"}},
	},
	{   "Subscription",
	    "subscription",
		{{.Subscription, "subscription"}},
	},
	{   "Fragment",
	    "fragment",
		{{.Fragment, "fragment"}},
	},
	{   "Directive",
		"directive",
		{{.Directive, "directive"}},
	},
	{   "Enum",
	    "enum",
		{{.Enum, "enum"}},
	},
	{   "Union",
		"union",
		{{.Union, "union"}},
	},
	{   "Scalar",
		"scalar",
		{{.Scalar, "scalar"}},
	},
	{   "Type",
	    "type",
		{{.Type, "type"}},
	},
	{   "Input",
	    "input",
		{{.Input, "input"}},
	},
	{   "On",
	    "on",
		{{.On, "on"}},
	},
	{   "Repeatable",
	    "repeatable",
		{{.Repeatable, "repeatable"}},
	},
	{   "Interface",
	    "interface",
		{{.Interface, "interface"}},
	},
	{   "Implements",
	    "implements",
		{{.Implements, "implements"}},
	},
	{   "Extend",
	    "extend",
		{{.Extend, "extend"}},
	},
	{   "Schema",
	    "schema",
		{{.Schema, "schema"}},
	},
	/*
	Names
	*/
	{   "Name",
		"foo",
		{{.Name, "foo"}},
	},
	{   "Name with underscore",
		"foo_bar",
		{{.Name, "foo_bar"}},
	},
	{   "Name with digits",
		"foo123",
		{{.Name, "foo123"}},
	},
	{   "Name with digits and underscore",
		"foo_123",
		{{.Name, "foo_123"}},
	},
	{   "Invalid Name",
		"123foo",
		{{.Invalid, "123"}, {.Name, "foo"}},
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

		test.expectf(t,
			len(tokens) == len(test_case.expected),
			"\n\e[0;32m%q\e[0m:\e[0;31m\n\texpected %d tokens, got %d\n\e[0m",
			test_case.name, len(test_case.expected), len(tokens),
		)

		for token, i in tokens {
			test.expectf(t,
				token == test_case.expected[i],
				"\n\e[0;32m%q\e[0m:\e[0;31m\n\texpected tokens[%d] to be %v, got %v\n\e[0m",
				test_case.name, i, test_case.expected[i], token,
			)
		}
	}
}