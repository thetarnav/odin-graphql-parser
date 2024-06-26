package gql

import test "core:testing"

Expect_Tokens_Case :: struct {
	name    : string,
	src     : string,
	expected: []Token,
}

expected_list := []Expect_Tokens_Case {
	{	"empty",
		"",
		{},
	},
	/*
	Punctuators
	*/
	{	"Paren_Open",
		"(",
		{{.Paren_Open, "("}},
	},
	{	"Paren_Close",
		")",
		{{.Paren_Close, ")"}},
	},
	{	"Bracket_Open",
		"[",
		{{.Bracket_Open, "["}},
	},
	{	"Bracket_Close",
		"]",
		{{.Bracket_Close, "]"}},
	},
	{	"Brace_Open",
		"{",
		{{.Brace_Open, "{"}},
	},
	{	"Brace_Close",
		"}",
		{{.Brace_Close, "}"}},
	},
	{	"Colon",
		":",
		{{.Colon, ":"}},
	},
	{	"Equals",
		"=",
		{{.Equals, "="}},
	},
	{	"At",
		"@",
		{{.At, "@"}},
	},
	{	"Dollar",
		"$",
		{{.Dollar, "$"}},
	},
	{	"Exclamation",
		"!",
		{{.Exclamation, "!"}},
	},
	{	"Pipe",
		"|",
		{{.Pipe, "|"}},
	},
	{	"Spread",
		"...",
		{{.Spread, "..."}},
	},
	/*
	Keywords
	*/
	{	"Query",
	    "query",
		{{.Name, "query"}},
	},
	{	"Mutation",
	    "mutation",
		{{.Name, "mutation"}},
	},
	{	"Subscription",
	    "subscription",
		{{.Name, "subscription"}},
	},
	{	"Fragment",
	    "fragment",
		{{.Name, "fragment"}},
	},
	{	"Directive",
		"directive",
		{{.Name, "directive"}},
	},
	{	"Enum",
	    "enum",
		{{.Name, "enum"}},
	},
	{	"Union",
		"union",
		{{.Name, "union"}},
	},
	{	"Scalar",
		"scalar",
		{{.Name, "scalar"}},
	},
	{	"Type",
	    "type",
		{{.Name, "type"}},
	},
	{	"Input",
	    "input",
		{{.Name, "input"}},
	},
	{	"On",
	    "on",
		{{.Name, "on"}},
	},
	{	"Repeatable",
	    "repeatable",
		{{.Name, "repeatable"}},
	},
	{	"Interface",
	    "interface",
		{{.Name, "interface"}},
	},
	{	"Implements",
	    "implements",
		{{.Name, "implements"}},
	},
	{	"Extend",
	    "extend",
		{{.Name, "extend"}},
	},
	{	"Schema",
	    "schema",
		{{.Name, "schema"}},
	},
	/*
	Booleans and Null
	*/
	{	"True",
	    "true",
		{{.Name, "true"}},
	},
	{	"False",
	    "false",
		{{.Name, "false"}},
	},
	{	"Null",
	    "null",
		{{.Name, "null"}},
	},
	/*
	Names
	*/
	{	"Name",
		"foo",
		{{.Name, "foo"}},
	},
	{	"Name with underscore",
		"foo_bar",
		{{.Name, "foo_bar"}},
	},
	{	"Name with digits",
		"foo123",
		{{.Name, "foo123"}},
	},
	{	"Name with digits and underscore",
		"foo_123",
		{{.Name, "foo_123"}},
	},
	{	"Invalid Name",
		"123foo",
		{{.Invalid, "123"}, {.Name, "foo"}},
	},
	/*
	Int and Float
	*/
	{	"zero",
		"0",
		{{.Int, "0"}},
	},
	{	"int",
		"123",
		{{.Int, "123"}},
	},
	{	"invalid int",
		"0123",
		{{.Invalid, "0"}, {.Int, "123"}},
	},
	{	"float",
		"123.456",
		{{.Float, "123.456"}},
	},
	{	"invalid float",
		"123.",
		{{.Invalid, "123."}},
	},
	{	"float zero",
		"0.456",
		{{.Float, "0.456"}},
	},
	{	"negative int",
		"-123",
		{{.Int, "-123"}},
	},
	{	"negative float",
		"-123.456",
		{{.Float, "-123.456"}},
	},
	{	"negative float zero",
		"-0.456",
		{{.Float, "-0.456"}},
	},
	/*
	String
	*/
	{	"empty String",
		`""`,
		{{.String, `""`}},
	},
	{	"String",
		`"foo"`,
		{{.String, `"foo"`}},
	},
	{	"String with escape",
		`"foo\"bar"`,
		{{.String, `"foo\"bar"`}},
	},
	{	"String with unicode",
		`"䍅㑟"`,
		{{.String, `"䍅㑟"`}},
	},
	{	"String with escaped escape",
		`"foo\\"`,
		{{.String, `"foo\\"`}},
	},
	{	"invalid String",
		`"foo`,
		{{.Invalid, `"foo`}},
	},
	{	"invalid String with escape",
		`"foo\`,
		{{.Invalid, `"foo\`}},
	},
	{	"invalid String with escaped quote",
		`"foo\"`,
		{{.Invalid, `"foo\"`}},
	},
	{	"invalid String with escape and unicode",
		`"foo\u`,
		{{.Invalid, `"foo\u`}},
	},
	/*
	String Block
	*/
	{	"empty String Block",
		`""""""`,
		{{.String_Block, `""""""`}},
	},
	{	"String Block",
		`"""foo"""`,
		{{.String_Block, `"""foo"""`}},
	},
	{	"String Block with escape",
		`"""foo\"bar"""`,
		{{.String_Block, `"""foo\"bar"""`}},
	},
	{	"String Block with unicode",
		`"""䍅㑟"""`,
		{{.String_Block, `"""䍅㑟"""`}},
	},
	{	"String Block with escaped escape",
		`"""foo\\"""`,
		{{.String_Block, `"""foo\\"""`}},
	},
	{	"invalid String Block",
		`"""foo`,
		{{.Invalid, `"""foo`}},
	},
	{	"invalid String Block with escape",
		`"""foo\`,
		{{.Invalid, `"""foo\`}},
	},
	{	"invalid String Block with escaped quote",
		`"""foo\"`,
		{{.Invalid, `"""foo\"`}},
	},
	{	"invalid String Block with escape and unicode",
		`"""foo\u`,
		{{.Invalid, `"""foo\u`}},
	},
	{	"String Block with new line",
		`"""`+"\n"+`foo`+"\n"+`"""`,
		{{.String_Block, `"""`+"\n"+`foo`+"\n"+`"""`}},
	},
	/*
	Comments
	*/
	{	"Comment",
		"# foo",
		{},
	},
	{	"Comment with int after new line",
		"# foo\n123",
		{{.Int, "123"}},
	},
	{	"Comment with int after carriage return",
		"# foo\r123",
		{{.Int, "123"}},
	},
	/*
	Code Snippets
	*/
	{	"Query Example",
`query Global_Link($url: String = "https://example.com") {
	link(url: $url)
}`,     {
			{.Name, "query"},
			{.Name, "Global_Link"},
			{.Paren_Open, "("},
			{.Dollar, "$"},
			{.Name, "url"},
			{.Colon, ":"},
			{.Name, "String"},
			{.Equals, "="},
			{.String, `"https://example.com"`},
			{.Paren_Close, ")"},
			{.Brace_Open, "{"},
			{.Name, "link"},
			{.Paren_Open, "("},
			{.Name, "url"},
			{.Colon, ":"},
			{.Dollar, "$"},
			{.Name, "url"},
			{.Paren_Close, ")"},
			{.Brace_Close, "}"},
		},
	},
	{	"Nested Query Example",
`query Schema {
	types {
		name, fields {
			...display_field
		}
	}
}

fragment display_field on __Field {
	name
	args {name}
}`,	 	{
			{.Name, "query"},
			{.Name, "Schema"},
			{.Brace_Open, "{"},
			{.Name, "types"},
			{.Brace_Open, "{"},
			{.Name, "name"},
			{.Name, "fields"},
			{.Brace_Open, "{"},
			{.Spread, "..."},
			{.Name, "display_field"},
			{.Brace_Close, "}"},
			{.Brace_Close, "}"},
			{.Brace_Close, "}"},
			{.Name, "fragment"},
			{.Name, "display_field"},
			{.Name, "on"},
			{.Name, "__Field"},
			{.Brace_Open, "{"},
			{.Name, "name"},
			{.Name, "args"},
			{.Brace_Open, "{"},
			{.Name, "name"},
			{.Brace_Close, "}"},
			{.Brace_Close, "}"},
		},
	},
}

test_only_name: string

@(test)
test_tokenizer_cases :: proc(t: ^test.T) {
	tokens := make([dynamic]Token, 0, 10)

	failed_count: int

	for test_case in expected_list {
		switch test_only_name {
		case "", test_case.name:
		case:
			failed_count += 1
			continue
		}

		tokenizer := make_tokenizer(test_case.src)

		for token in next_token(&tokenizer) {
			append(&tokens, token)
		}
		defer clear_dynamic_array(&tokens)

		good := test.expectf(t,
			len(tokens) == len(test_case.expected),
			"\n\e[0;32m%q\e[0m:\e[0;31m\n\texpected %d tokens, got %d\n\e[0m",
			test_case.name, len(test_case.expected), len(tokens),
		)

		for token, i in tokens {
			token_good := test.expectf(t,
				token == test_case.expected[i],
				"\n\e[0;32m%q\e[0m:\e[0;31m\n\texpected tokens[%d] to be %v, got %v\n\e[0m",
				test_case.name, i, test_case.expected[i], token,
			)
			good = good && token_good
		}

		if !good {
			failed_count += 1
			continue
		}
	}

	if failed_count > 0 {
		test.errorf(t, "\e[0;31mFailed %d cases\e[0m", failed_count)
	} else {
		test.logf(t, "\e[0;32mAll cases passed\e[0m")
	}
}
