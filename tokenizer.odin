package gql

import "core:unicode/utf8"

Token :: struct {
	kind : Token_Kind,
	value: string,
}

Token_Kind :: enum {
	Illegal,
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
	On,
	// Literals
	Int,
	Float,
	String,
	// Identifiers
	Name,
	// Operators
	Spread,
}

Tokenizer :: struct {
	src      : string,
	read_idx : int,
	write_idx: int,
	char     : rune,
}

tokenizer_init :: proc "contextless" (t: ^Tokenizer, src: string) {
	t.src = src
	first_ch, ok := next_char(t)
	if first_ch == utf8.RUNE_BOM {
		next_char(t)
	}
}

token_make :: proc "contextless" (t: ^Tokenizer, kind: Token_Kind) -> (token: Token) {
	token.kind = kind
	token.value = t.src[t.write_idx:t.read_idx]
	t.write_idx = t.read_idx
	return
}

next_char :: proc "contextless" (t: ^Tokenizer) -> (char: rune, can_continue: bool) #optional_ok #no_bounds_check {
	if t.read_idx >= len(t.src) {
		t.char = -1
		return -1, false
	}

	width: int
	char, width = utf8.decode_rune_in_string(t.src[t.read_idx:])
	t.char = char
	t.read_idx += width
	return char, true
}

next_token :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	if t.read_idx >= len(t.src) {
		return Token{.EOF, ""}, false
	}

	switch t.char {
	// Whitespace
	case ' ', '\t', '\n', '\r':
		t.write_idx = t.read_idx
		return next_token(t)
	// Punctuators
	case '(': return token_make(t, .Parenthesis_Left), true
	case ')': return token_make(t, .Parenthesis_Right), true
	case '[': return token_make(t, .Bracket_Left), true
	case ']': return token_make(t, .Bracket_Right), true
	case '{': return token_make(t, .Brace_Left), true
	case '}': return token_make(t, .Brace_Right), true
	case ':': return token_make(t, .Colon), true
	case '=': return token_make(t, .Equals), true
	case '@': return token_make(t, .At,), true
	case '$': return token_make(t, .Dollar), true
	case '!': return token_make(t, .Exclamation), true
	case '|': return token_make(t, .Vertical_Bar), true
	case '.':
		if '.' == next_char(t) &&
		   '.' == next_char(t)
		{
			token = token_make(t, .Spread)
		} else {
			token = token_make(t, .Illegal)
		}
	/* Int and Float
	   123     | -123
	   123.456 | -123.456
	   0.123   | -0.123
	*/
	case '-':
		next_char(t)
		return scan_number(t)
	case '0'..='9':
		return scan_number(t)
	}

	return token, true
}

scan_number :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	if t.char == '0' {
		switch next_char(t) {
		case '.':
			return scan_fraction(t)
		case '0'..='9', 'a'..='z', 'A'..='Z', '_':
			return token_make(t, .Illegal), true
		case:
			return token_make(t, .Int), true
		}
	}
	
	for {
		char := next_char(t) or_break
		switch char {
		case '0'..='9':
			continue
		case '.':
			return scan_fraction(t)
		case 'a'..='z', 'A'..='Z', '_':
			return token_make(t, .Illegal), true
		case:
			return token_make(t, .Int), true
		}
	}
}

scan_fraction :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	for {
		char := next_char(t) or_break
		switch char {
		case '0'..='9':
			continue
		case 'a'..='z', 'A'..='Z', '_':
			return token_make(t, .Illegal), true
		case:
			return token_make(t, .Float), true
		}
	}
	return
}