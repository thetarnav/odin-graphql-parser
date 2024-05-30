package gql

import "core:mem"
import "core:strings"

Schema :: struct {
	/*
	Array of all types in the schema.
	Index 0 is reserved for the `Unknown` type. (Zero fallback)
	Index 1 is reserved for the `String` type.
	Index 2 is reserved for the `Int` type.
	Index 3 is reserved for the `Float` type.
	Index 4 is reserved for the `Boolean` type.
	Index 5 is reserved for the `ID` type.

	All other types are user-defined.

	Do `schema.types[1:]` to get types without Unknown,
	or `schema.types[6:]` to get types without built-in scalars.
	*/
	types       : [dynamic]Type,
	/*
	Index of the current query, mutation and subscription types in the `Schema.types` array.
	*/
	query       : int,
	mutation    : int,
	subscription: int,
	/*
	Allocator used to allocate memory for Types, Fields and Input_Values.
	*/
	allocator   : mem.Allocator,
}

Type :: struct {
	kind       : Type_Kind,
	name       : string,
	interfaces : []int,    // Object and Interface (Index to `Schema.types`)
	fields     : []Field,  // Object and Interface and Input_Object
	members    : []int,    // Union (Index to `Schema.types`)
	enum_values: []string, // Enum
}

Type_Kind :: enum {
	Unknown, // Zero case
	Scalar,
	Object,
	Interface,
	Union,
	Enum,
	Input_Object,
}

Type_Value :: struct {
	/*
	Index of the type in the `Schema.types` array
	*/
	index: int,
	/*
	Non_Null flags for the type and List wrappers

	1st bit: 1 if the type is non-null
	2nd bit: 1 if the 1st List wrapper is non-null
	3rd bit: 1 if the 2nd List wrapper is non-null
	...

	e.g.
	[[String]]!
	non_null_flags = 0b00000100 // 2nd List wrapper is non-null
	lists          = 2

	*/
	non_null_flags: u8,
	lists: u8, // Number of List wrappers, MAX: 7
}

Field :: struct {
	name : string,
	args : []Input_Value,
	value: Type_Value,
}

Input_Value :: struct {
	name : string,
	value: Type_Value,
}

Unexpected_Token_Error :: struct {
	token: Token,
}
Repeated_Type_Error :: struct {
	name: string,
}
Allocator_Error :: mem.Allocator_Error
Schema_Error :: union {
	Unexpected_Token_Error,
	Repeated_Type_Error,
	Allocator_Error,
}

USER_TYPES_START :: 6

schema_init :: proc(
	s: ^Schema,
	allocator := context.allocator,
) -> mem.Allocator_Error #no_bounds_check {
	s.allocator = allocator
	s.types     = make(type_of(s.types), USER_TYPES_START, 64, allocator) or_return
	s.types[0]  = {}
	s.types[1]  = {kind = .Scalar, name = "String"}
	s.types[2]  = {kind = .Scalar, name = "Int"}
	s.types[3]  = {kind = .Scalar, name = "Float"}
	s.types[4]  = {kind = .Scalar, name = "Boolean"}
	s.types[5]  = {kind = .Scalar, name = "ID"}
	return nil
}

@(require_results)
schema_make :: proc(
	allocator := context.allocator,
) -> (s: Schema, err: mem.Allocator_Error) #optional_allocator_error {
	return s, schema_init(&s, allocator)
}
make_schema :: schema_make

schema_parse :: proc(
	s: ^Schema,
	src: string,
) -> (err: Schema_Error) #no_bounds_check {

	@(require_results)
	find_type :: proc(
		s: ^Schema,
		name: string,
	) -> (idx: int, err: Schema_Error) #no_bounds_check {
		for type, i in s.types[1:] {
			if type.name == name {
				return i+1, nil
			}
		}
		append(&s.types, Type{name = name}) or_return
		return len(s.types) - 1, nil
	}
	@(require_results)
	add_type :: proc(
		s: ^Schema,
		name: string,
		kind: Type_Kind,
	) -> (idx: int, err: Schema_Error) #no_bounds_check {
		// Maybe the type is already in the list
		// (Added by another type referencing it)
		for &type, i in s.types[1:] {
			if type.name != name do continue
			if type.kind != .Unknown {
				err = Repeated_Type_Error{name}
			}
			idx = i+1
			type.kind = kind
			return
		}

		// Append new
		append(&s.types, Type{name = name, kind = kind}) or_return
		idx = len(s.types) - 1
		return
	}
	@(require_results)
	parse_type_value :: proc(
		s: ^Schema,
		t: ^Tokenizer,
	) -> (token: Token, value: Type_Value, err: Schema_Error) {

		open_lists: u8 = 0
		for {
			token = next_token(t)
			#partial switch token.kind {
			case .Name:
				if value.index == 0 {
					value.index = find_type(s, token.value) or_return
					break
				}
				if open_lists > 1 {
					err = Unexpected_Token_Error{token}
				}
				return
			case .Bracket_Open:
				if value.index > 0 {
					err = Unexpected_Token_Error{token}
					return
				}
				open_lists += 1
			case .Bracket_Close:
				if open_lists == 0 || value.index == 0 {
					err = Unexpected_Token_Error{token}
					return
				}
				open_lists  -= 1
				value.lists += 1
			case .Exclamation:
				if value.index == 0 || value.non_null_flags & (1 << value.lists) != 0 {
					err = Unexpected_Token_Error{token}
					return
				}
				value.non_null_flags |= (1 << value.lists)
			case .Brace_Close, .Paren_Close:
				if open_lists > 0 || value.index == 0 {
					err = Unexpected_Token_Error{token}
				}
				return
			case:
				err = Unexpected_Token_Error{token}
				return
			}
		}
	}
	@(require_results)
	next_token :: #force_inline proc(
		t: ^Tokenizer,
	) -> (token: Token) {
		token = tokenizer_next(t)
		for {
			#partial switch token.kind {
			// Ignore string comments
			case .String, .String_Block:
				token = tokenizer_next(t)
			case:
				return
			}
		}
	}
	@(require_results)
	next_token_expect :: #force_inline proc(
		t: ^Tokenizer,
		expected: Token_Kind,
	) -> (token: Token, err: Schema_Error) {
		token = tokenizer_next(t)
		for {
			#partial switch token.kind {
			// Ignore string comments
			case .String, .String_Block:
				token = tokenizer_next(t)
			case expected:
				return
			case:
				err = Unexpected_Token_Error{token}
				return
			}
		}
	}

	t := tokenizer_make(src)
	
	token := next_token(&t)
	top_level_loop: for {
		#partial switch token.kind {
		case .EOF:
			break top_level_loop
		// Type Object
		case .Name:
			keyword := match_keyword(token.value)
			#partial switch keyword {
			case .Schema:
				token = next_token_expect(&t, .Brace_Open) or_return

				// Parse schema fields
				for {
					token = next_token(&t)
					if (token.kind == .Brace_Close) do break

					field_token := token
					token = next_token_expect(&t, .Colon) or_return
					token = next_token_expect(&t, .Name) or_return

					switch field_token.value {
					case "query":        s.query        = find_type(s, token.value) or_return
					case "mutation":     s.mutation     = find_type(s, token.value) or_return
					case "subscription": s.subscription = find_type(s, token.value) or_return
					case:
						return Unexpected_Token_Error{field_token}
					}
				}
				token = next_token(&t)

			case .Type, .Interface:
				token = next_token_expect(&t, .Name) or_return

				type_kind: Type_Kind = keyword == .Type ? .Object : .Interface
				idx := add_type(s, token.value, type_kind) or_return

				// Parse interfaces
				interfaces_check: {
					token = next_token(&t)
					#partial switch token.kind {
					case .Name:
						if match_keyword(token.value) != .Implements {
							return Unexpected_Token_Error{token}
						}

						interfaces := make([dynamic]int, 0, 4, s.allocator) or_return
						defer shrink(&interfaces)
						defer s.types[idx].interfaces = interfaces[:]

						for {
							token = next_token(&t)
							#partial switch token.kind {
							case .Name:
								interface := find_type(s, token.value) or_return
								append(&interfaces, interface) or_return
							case .Brace_Open:
								break interfaces_check
							case:
								return Unexpected_Token_Error{token}
							}
						}
					case .Brace_Open:
						break interfaces_check
					case:
						return Unexpected_Token_Error{token}
					}
				}

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return
				defer shrink(&fields)
				defer s.types[idx].fields = fields[:]

				// Parse fields
				token = next_token(&t)
				fields_loop: for {
					#partial switch token.kind {
					case .Name:
						field := Field{name = token.value}

						token = next_token(&t)
						#partial switch token.kind {
						case .Colon:
							// No arguments
						case .Paren_Open:
							// Parse arguments
							args := make([dynamic]Input_Value, 0, 4, s.allocator) or_return
							defer shrink(&args)
							defer field.args = args[:]

							token = next_token(&t)
							args_loop: for {
								#partial switch token.kind {
								case .Name:
									arg := Input_Value{name = token.value}

									token = next_token_expect(&t, .Colon) or_return

									token, arg.value = parse_type_value(s, &t) or_return
									append(&args, arg) or_return
								case .Paren_Close:
									break args_loop
								case:
									return Unexpected_Token_Error{token}
								}
							}

							token = next_token_expect(&t, .Colon) or_return
						case:
							return Unexpected_Token_Error{token}
						}

						token, field.value = parse_type_value(s, &t) or_return
						append(&fields, field) or_return
					case .Brace_Close:
						break fields_loop
					case:
						return Unexpected_Token_Error{token}
					}
				}
				token = next_token(&t)

			case .Input:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Object) or_return

				token = next_token_expect(&t, .Brace_Open) or_return

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return
				defer shrink(&fields)
				defer s.types[idx].fields = fields[:]

				// Parse fields
				token = next_token(&t)
				input_fields_loop: for {
					#partial switch token.kind {
					case .Name:
						field := Field{name = token.value}

						token = next_token_expect(&t, .Colon) or_return

						token, field.value = parse_type_value(s, &t) or_return
						append(&fields, field) or_return
					case .Brace_Close:
						break input_fields_loop
					case:
						return Unexpected_Token_Error{token}
					}
				}
				token = next_token(&t)

			case .Enum:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Enum) or_return

				token = next_token_expect(&t, .Brace_Open) or_return

				enum_values := make([dynamic]string, 0, 8, s.allocator) or_return
				defer shrink(&enum_values)
				defer s.types[idx].enum_values = enum_values[:]

				// Parse enum values
				enum_values_loop: for {
					token = next_token(&t)
					#partial switch token.kind {
					case .Name:
						append(&enum_values, token.value) or_return
					case .Brace_Close:
						break enum_values_loop
					case:
						return Unexpected_Token_Error{token}
					}
				}
				token = next_token(&t)

			case .Union:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Union) or_return

				token = next_token_expect(&t, .Equals) or_return

				members := make([dynamic]int, 0, 4, s.allocator) or_return
				defer shrink(&members)
				defer s.types[idx].members = members[:]

				// Parse members
				for {
					token = next_token_expect(&t, .Name) or_return
					member := find_type(s, token.value) or_return
					append(&members, member) or_return

					token = next_token(&t)
					if token.kind != .Pipe do break
				}

			case:
				return Unexpected_Token_Error{token}
			}
		case:
			return Unexpected_Token_Error{token}
		}
	}

	shrink(&s.types)
	return
}

schema_delete :: proc(s: Schema) #no_bounds_check {
	for type in s.types[USER_TYPES_START:] {
		delete(type.fields)
		delete(type.interfaces)
		delete(type.members)
		delete(type.enum_values)
	}
	delete(s.types)
}
delete_schema :: schema_delete

@(require_results)
type_value_is_non_null :: #force_inline proc(
	value: Type_Value,
) -> bool {
	return value.non_null_flags & 1 != 0
}
@(require_results)
type_value_is_list_non_null :: #force_inline proc(
	value: Type_Value,
	list_idx: u8,
) -> bool {
	return value.non_null_flags & (1 << (list_idx+1)) != 0
}

/*
Return a pretty string representation of a schema error.
*/
@(require_results)
schema_error_to_string :: proc(
	schema_src: string,
	schema_err: Schema_Error,
	allocator := context.allocator,
) -> (text: string, err: mem.Allocator_Error) #optional_allocator_error {
	switch e in schema_err {
	case Allocator_Error:
		switch e {
		case .None:                 text = "Allocator_Error: None"
		case .Out_Of_Memory:        text = "Allocator_Error: Out of memory"
		case .Invalid_Pointer:      text = "Allocator_Error: Invalid pointer"
		case .Invalid_Argument:     text = "Allocator_Error: Invalid argument"
		case .Mode_Not_Implemented: text = "Allocator_Error: Mode not implemented"
		}
	case Repeated_Type_Error:
		text = strings.concatenate({"Repeated_Type: \"", e.name, "\""}, allocator) or_return
	case Unexpected_Token_Error:
		// Find the position of the token in the source string
		idx := int(uintptr(raw_data(e.token.value)) - uintptr(raw_data(schema_src)))
		start_width := 0
		start := idx
		end   := idx

		for start > 0 && idx - start < 40 {
			if schema_src[start] == '\t' {
				start_width += 7
			}
			if schema_src[start] == '\n' {
				start += 1
				start_width -= 1
				break
			}
			start_width += 1
			start -= 1
		}
		for i := 0; i < 40; i += 1 {
			if end < len(schema_src) {
				if schema_src[end] == '\n' {
					break
				}
				end += 1
			}
		}

		b := strings.builder_make_len_cap(0, 128, allocator) or_return
		strings.write_string(&b, "Unexpected token: \"")
		strings.write_string(&b, e.token.value)
		strings.write_string(&b, "\"\n")
		strings.write_string(&b, schema_src[start:end])
		strings.write_string(&b, "\n")
		for _ in 0..<start_width {
			strings.write_rune(&b, ' ')
		}
		for _ in 0..<len(e.token.value) {
			strings.write_rune(&b, '^')
		}
		text = strings.to_string(b)
	}

	return
}
