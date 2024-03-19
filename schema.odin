package gql

import "core:mem"

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
	name: string,
	args: []Input_Value,
	type: Type_Value,
}

Input_Value :: struct {
	name: string,
	type: Type_Value,
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

Error_Unexpected_Token :: struct {
	token: Token,
}
Error_Repeated_Type :: struct {
	name: string,
}
Allocator_Error :: mem.Allocator_Error
Schema_Error :: union {
	Error_Unexpected_Token,
	Error_Repeated_Type,
	Allocator_Error,
}

schema_parse :: proc(
	s: ^Schema,
	src: string,
) -> (err: Schema_Error) #no_bounds_check {

	@(require_results)
	find_type :: proc(
		s: ^Schema,
		name: string,
	) -> (idx: int, err: Schema_Error) {
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
	) -> (idx: int, err: Schema_Error) {
		// Maybe the type is already in the list
		// (Added by another type referencing it)
		for &type, i in s.types[1:] {
			if type.name != name do continue
			if type.kind != .Unknown {
				err = Error_Repeated_Type{name}
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
			token = tokenizer_next(t)
			#partial switch token.kind {
			case .Name:
				if value.index == 0 {
					value.index = find_type(s, token.value) or_return
					break
				}
				if open_lists > 1 {
					err = Error_Unexpected_Token{token}
				}
				return
			case .Bracket_Open:
				if value.index > 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				open_lists += 1
			case .Bracket_Close:
				if open_lists == 0 || value.index == 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				open_lists  -= 1
				value.lists += 1
			case .Exclamation:
				if value.index == 0 || value.non_null_flags & 1 << value.lists != 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				value.non_null_flags |= 1 << value.lists
			case .Brace_Close, .Paren_Close:
				if open_lists > 0 || value.index == 0 {
					err = Error_Unexpected_Token{token}
				}
				return
			case:
				err = Error_Unexpected_Token{token}
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
				err = Error_Unexpected_Token{token}
				return
			}
		}
	}

	t := tokenizer_make(src)
	token: Token

	top_level_loop: for {
		token = next_token(&t)

		#partial switch token.kind {
		case .EOF: break top_level_loop
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

					#partial switch match_keyword(field_token.value) {
					case .Query:        s.query        = find_type(s, token.value) or_return
					case .Mutation:     s.mutation     = find_type(s, token.value) or_return
					case .Subscription: s.subscription = find_type(s, token.value) or_return
					case:
						return Error_Unexpected_Token{field_token}
					}
				}
			case .Type, .Interface:
				token = next_token_expect(&t, .Name) or_return

				kind: Type_Kind
				#partial switch keyword {
				case .Type:      kind = .Object
				case .Interface: kind = .Interface
				}

				idx  := add_type(s, token.value, kind) or_return

				// Parse interfaces
				interfaces_check: {
					token = next_token(&t)
					#partial switch token.kind {
					case .Name:
						if match_keyword(token.value) != .Implements {
							return Error_Unexpected_Token{token}
						}

						interfaces := make([dynamic]int, 0, 4, s.allocator) or_return
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
								return Error_Unexpected_Token{token}
							}
						}
					case .Brace_Open:
						break interfaces_check
					case:
						return Error_Unexpected_Token{token}
					}
				}

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return
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
							defer field.args = args[:]

							token = next_token(&t)
							args_loop: for {
								#partial switch token.kind {
								case .Name:
									arg := Input_Value{name = token.value}

									token = next_token_expect(&t, .Colon) or_return

									token, arg.type = parse_type_value(s, &t) or_return
									append(&args, arg) or_return
								case .Paren_Close:
									break args_loop
								case:
									return Error_Unexpected_Token{token}
								}
							}
						case:
							return Error_Unexpected_Token{token}
						}

						token, field.type = parse_type_value(s, &t) or_return
						append(&fields, field) or_return
					case .Brace_Close:
						break fields_loop
					case:
						return Error_Unexpected_Token{token}
					}
				}
			case .Input:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Object) or_return

				token = next_token_expect(&t, .Brace_Open) or_return

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return
				defer s.types[idx].fields = fields[:]

				// Parse fields
				token = next_token(&t)
				input_fields_loop: for {
					#partial switch token.kind {
					case .Name:
						field := Field{name = token.value}

						token = next_token_expect(&t, .Colon) or_return

						token, field.type = parse_type_value(s, &t) or_return
						append(&fields, field) or_return
					case .Brace_Close:
						break input_fields_loop
					case:
						return Error_Unexpected_Token{token}
					}
				}
			case .Enum:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Enum) or_return

				token = next_token_expect(&t, .Brace_Open) or_return

				enum_values := make([dynamic]string, 0, 8, s.allocator) or_return
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
						return Error_Unexpected_Token{token}
					}
				}
			case .Union:
				token = next_token_expect(&t, .Name) or_return
				idx  := add_type(s, token.value, .Union) or_return

				token = next_token_expect(&t, .Brace_Open) or_return

				members := make([dynamic]int, 0, 4, s.allocator) or_return
				defer s.types[idx].members = members[:]

				// Parse members
				members_loop: for {
					token = next_token(&t)
					#partial switch token.kind {
					case .Name:
						member := find_type(s, token.value) or_return
						append(&members, member) or_return
					case .Brace_Close:
						break members_loop
					case:
						return Error_Unexpected_Token{token}
					}
				}
			case:
				return Error_Unexpected_Token{token}
			}
		case:
			return Error_Unexpected_Token{token}
		}
	}

	return
}

schema_delete :: proc(s: Schema) {
	for type in s.types[USER_TYPES_START:] {
		delete(type.fields)
		delete(type.interfaces)
		delete(type.members)
		delete(type.enum_values)
	}
	delete(s.types)
}
delete_schema :: schema_delete