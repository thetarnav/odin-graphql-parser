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
	src         : string,
	offset_read : int,
	offset_write: int,
	char        : rune,
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
	token.value = t.src[t.offset_write:t.offset_read]
	t.offset_write = t.offset_read
	return
}

next_char :: proc "contextless" (t: ^Tokenizer) -> (char: rune, can_continue: bool) #optional_ok #no_bounds_check {

	if t.offset_read >= len(t.src) {
		t.char = -1
		return -1, false
	}

	width: int
	char, width = utf8.decode_rune_in_string(t.src[t.offset_read:])
	t.char = char
	t.offset_read += width
	return char, true
}

@(require_results)
next_token :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	
	if t.offset_read < len(t.src){
		can_continue = true
	}
	else if t.offset_read == t.offset_write {
		return make_token(t, .EOF), false
	}

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
			token = make_token(t, .Invalid)
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

	return
}

@(private, require_results)
scan_number :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	if t.char == '0' {
		switch next_char(t) {
		case '.':
			return scan_fraction(t)
		case '0'..='9', 'a'..='z', 'A'..='Z', '_':
			return make_token(t, .Invalid), true
		case:
			return make_token(t, .Int), true
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
			return make_token(t, .Invalid), true
		case:
			break
		}
	}

	return make_token(t, .Int), true
}

@(private, require_results)
scan_fraction :: proc "contextless" (t: ^Tokenizer) -> (token: Token, can_continue: bool) #optional_ok {
	for {
		char := next_char(t) or_break
		switch char {
		case '0'..='9':
			continue
		case 'a'..='z', 'A'..='Z', '_':
			return make_token(t, .Invalid), true
		case:
			break
		}
	}
	return make_token(t, .Float), true
}