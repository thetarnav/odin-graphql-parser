package gql

import "core:unicode/utf8"

Token :: struct {
	kind : Token_Kind,
	value: string,
}

Token_Kind :: enum {
	Invalid,
	EOF,
	// Punctuators
	Parenthesis_Left,
	Parenthesis_Right,
	Bracket_Left,
	Bracket_Right,
	Brace_Left,
	Brace_Right,
	Colon,
	Equals,
	At,
	Dollar,
	Exclamation,
	Vertical_Bar,
	// Keywords
	Query,
	Mutation,
	Subscription,
	Fragment,
	Directive,
	Enum,
	Union,
	Scalar,
	Type,
	Input,
	On,
	Repeatable,
	Interface,
	Implements,
	Extend,
	Schema,
	// Scalars
	Int,
	Float,
	String,
	// Identifiers
	Name,
	// Operators
	Spread,
}

Tokenizer :: struct {
	src         : string,
	offset_read : int,
	offset_write: int,
	char        : rune,
	last_width  : int,
}

tokenizer_init :: proc "contextless" (t: ^Tokenizer, src: string) {
	t.src = src
	first_ch := next_char(t)
	if first_ch == utf8.RUNE_BOM {
		t.offset_write = t.offset_read
		next_char(t)
	}
}

@(private, require_results)
make_token :: proc "contextless" (t: ^Tokenizer, kind: Token_Kind) -> (token: Token) #no_bounds_check {
	token.kind = kind
	token.value = t.src[t.offset_write : t.offset_read]
	t.offset_write = t.offset_read
	next_char(t)
	return
}
@(private, require_results)
make_token_ignore_last_char :: proc "contextless" (t: ^Tokenizer, kind: Token_Kind) -> (token: Token) #no_bounds_check {
	token.kind = kind
	token.value = t.src[t.offset_write : t.offset_read-t.last_width]
	t.offset_write = t.offset_read-t.last_width
	return
}

next_char :: proc "contextless" (t: ^Tokenizer) -> (char: rune, before_eof: bool) #optional_ok #no_bounds_check {
	if t.offset_read >= len(t.src) {
		t.char = 0
		t.offset_read = len(t.src)+1
		t.last_width = 1
		return 0, false
	}

	width: int
	char, width = utf8.decode_rune_in_string(t.src[t.offset_read:])
	t.char = char
	t.offset_read += width
	t.last_width = width
	return char, true
}

@(require_results)
next_token :: proc "contextless" (t: ^Tokenizer) -> (token: Token, before_eof: bool) #optional_ok #no_bounds_check {
	if t.offset_read > len(t.src) {
		return make_token(t, .EOF), false
	}
	before_eof = true

	switch t.char {
	// Whitespace
	case ' ', '\t', '\n', '\r':
		t.offset_write = t.offset_read
		return next_token(t)
	// Punctuators
	case '(': token = make_token(t, .Parenthesis_Left)
	case ')': token = make_token(t, .Parenthesis_Right)
	case '[': token = make_token(t, .Bracket_Left)
	case ']': token = make_token(t, .Bracket_Right)
	case '{': token = make_token(t, .Brace_Left)
	case '}': token = make_token(t, .Brace_Right)
	case ':': token = make_token(t, .Colon)
	case '=': token = make_token(t, .Equals)
	case '@': token = make_token(t, .At,)
	case '$': token = make_token(t, .Dollar)
	case '!': token = make_token(t, .Exclamation)
	case '|': token = make_token(t, .Vertical_Bar)
	case '.':
		if '.' == next_char(t) &&
		   '.' == next_char(t)
		{
			token = make_token(t, .Spread)
		} else {
			token = make_token_ignore_last_char(t, .Invalid)
		}
	// Int and Float
	case '-':
		next_char(t)
		return scan_number(t)
	case '0'..='9':
		return scan_number(t)
	// Keywords and Identifiers
	case 'a'..='z', 'A'..='Z', '_':
		for {
			switch next_char(t) {
			case 'a'..='z', 'A'..='Z', '0'..='9', '_': continue
			}
			break
		}
		switch t.src[t.offset_write : t.offset_read-t.last_width] {
		case "query":       token = make_token_ignore_last_char(t, .Query)
		case "mutation":    token = make_token_ignore_last_char(t, .Mutation)
		case "subscription":token = make_token_ignore_last_char(t, .Subscription)
		case "fragment":    token = make_token_ignore_last_char(t, .Fragment)
		case "directive":   token = make_token_ignore_last_char(t, .Directive)
		case "enum":        token = make_token_ignore_last_char(t, .Enum)
		case "union":       token = make_token_ignore_last_char(t, .Union)
		case "scalar":      token = make_token_ignore_last_char(t, .Scalar)
		case "type":        token = make_token_ignore_last_char(t, .Type)
		case "input":       token = make_token_ignore_last_char(t, .Input)
		case "on":          token = make_token_ignore_last_char(t, .On)
		case "repeatable":  token = make_token_ignore_last_char(t, .Repeatable)
		case "interface":   token = make_token_ignore_last_char(t, .Interface)
		case "implements":  token = make_token_ignore_last_char(t, .Implements)
		case "extend":      token = make_token_ignore_last_char(t, .Extend)
		case "schema":      token = make_token_ignore_last_char(t, .Schema)
		case:               token = make_token_ignore_last_char(t, .Name)
		}
	// String
	case '"':
		escaping := false

		if '"' == next_char(t) {
			// Empty String
			if '"' != next_char(t) {
				return make_token_ignore_last_char(t, .String), true
			}

			// Block String
			for {
				switch next_char(t) {
				case 0:
					return make_token_ignore_last_char(t, .Invalid), true
				case '\\':
					escaping = !escaping
				case '"':
					if !escaping &&
					   '"' == next_char(t) &&
					   '"' == next_char(t)
					{
						return make_token(t, .String), true
					}
					escaping = false
				case:
					escaping = false
				}
			}
		}

		// String
		for {
			switch next_char(t) {
			case 0, '\n':
				return make_token_ignore_last_char(t, .Invalid), true
			case '\\':
				escaping = !escaping
			case '"':
				if !escaping {
					return make_token(t, .String), true
				}
				escaping = false
			case:
				escaping = false
			}
		}
	}

	return
}

@(private, require_results)
scan_number :: proc "contextless" (t: ^Tokenizer) -> (token: Token, before_eof: bool) #optional_ok {
	/*  e.g.
	    123
	    123.456
	    0.123
		0
	*/
	scan_fraction :: proc "contextless" (t: ^Tokenizer) -> (token: Token, before_eof: bool) #optional_ok {
		char := next_char(t)
		if char < '0' || char > '9' {
			return make_token_ignore_last_char(t, .Invalid), true
		}
		for {
			switch next_char(t) {
			case '0'..='9':
				continue
			case 'a'..='z', 'A'..='Z', '_':
				return make_token_ignore_last_char(t, .Invalid), true
			case:
				return make_token_ignore_last_char(t, .Float), true
			}
		}
	}

	if t.char == '0' {
		switch next_char(t) {
		case '.':
			return scan_fraction(t)
		case '0'..='9', 'a'..='z', 'A'..='Z', '_':
			return make_token_ignore_last_char(t, .Invalid), true
		case:
			return make_token_ignore_last_char(t, .Int), true
		}
	}
	
	for {
		switch next_char(t) {
		case '0'..='9':
			continue
		case '.':
			return scan_fraction(t)
		case 'a'..='z', 'A'..='Z', '_':
			return make_token_ignore_last_char(t, .Invalid), true
		case:
			return make_token_ignore_last_char(t, .Int), true
		}
	}
}