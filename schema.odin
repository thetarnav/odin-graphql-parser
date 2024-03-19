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
	query_idx       : int,
	mutation_idx    : int,
	subscription_idx: int,
	/*
	Allocator used to allocate memory for Types, Fields and Input_Values.
	*/
	allocator   : mem.Allocator,
}

Type :: struct {
	kind       : Type_Kind,
	name       : string,
	types      : []Type_Value,  // Interface and Union
	interfaces : []Type_Value,  // Object and Interface
	fields     : []Field,       // Object and Interface
	enum_values: []string,      // Enum
	inputs     : []Input_Value, // Input_Object
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
	lists: i8, // Number of List wrappers, MAX: 7
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
Schema_Error :: union {
	Error_Unexpected_Token,
	Error_Repeated_Type,
	mem.Allocator_Error,
}

schema_parse_string :: proc(
	s: ^Schema,
	src: string,
) -> (err: Schema_Error) #no_bounds_check {

	find_type :: proc(
		s: ^Schema,
		name: string,
	) -> (idx: int) {
		for type, i in s.types[1:] {
			if type.name == name {
				return i
			}
		}
		append(&s.types, Type{name = name})
		return len(s.types) - 1
	}

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
			idx = i
			type.kind = kind
			return
		}

		// Append new
		append(&s.types, Type{name = name, kind = kind})
		idx = len(s.types) - 1
		return
	}

	parse_type_value :: proc(
		s: ^Schema,
		t: ^Tokenizer,
	) -> (token: Token, value: Type_Value, err: Schema_Error) {
		
		open_lists: uint = 0
		for {
			token = tokenizer_next(t)
			#partial switch token.kind {
			case .Name:
				if value.index == 0 {
					value.index = find_type(s, token.value)
					break
				}
				if open_lists > 1 {
					err = Error_Unexpected_Token{token}
				}
				return
			case .Bracket_Left:
				if value.index > 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				value.lists += 1
				open_lists  += 1
			case .Bracket_Right:
				if open_lists == 0 || value.index == 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				open_lists -= 1
			case .Exclamation:
				if value.index == 0 || value.non_null_flags & 1 << open_lists != 0 {
					err = Error_Unexpected_Token{token}
					return
				}
				value.non_null_flags |= 1 << open_lists
			case .Brace_Right, .Parenthesis_Right:
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
	
	t := tokenizer_make(src)
	for {
		token := tokenizer_next(&t) or_break

		#partial switch token.kind {
		// Ignore string comments
		case .String, .String_Block:
			continue
		// Type Object
		case .Name:
			token = tokenizer_next(&t)

			#partial switch token.kind {
			case .Name:
				idx := add_type(s, token.value, .Object) or_return

				token = tokenizer_next(&t)
				if (token.kind != .Brace_Left) {
					return Error_Unexpected_Token{token}
				}

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return
				defer s.types[idx].fields = fields[:]

				// Parse fields
				token = tokenizer_next(&t)
				for {
					if (token.kind == .Brace_Right) do break

					if (token.kind != .Name) {
						return Error_Unexpected_Token{token}
					}

					field := Field{name = token.value}

					// Parse arguments
					token = tokenizer_next(&t)
					if (token.kind == .Parenthesis_Left) {

						args := make([dynamic]Input_Value, 0, 4, s.allocator) or_return
						defer field.args = args[:]

						token = tokenizer_next(&t)
						for {
							if (token.kind == .Parenthesis_Right) do break

							if (token.kind != .Name) {
								return Error_Unexpected_Token{token}
							}

							arg := Input_Value{name = token.value}

							token = tokenizer_next(&t)
							if (token.kind != .Colon) {
								return Error_Unexpected_Token{token}
							}

							token, arg.value = parse_type_value(s, &t) or_return
							append(&args, arg)
						}
					} else if (token.kind != .Colon) {
						return Error_Unexpected_Token{token}
					}

					token, field.value = parse_type_value(s, &t) or_return
					append(&fields, field)
				}
			}
		case:
			return Error_Unexpected_Token{token}
		}
	}

	return
}