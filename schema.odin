package gql

import "core:mem"

Schema :: struct {
	/*
	Array of all types in the schema.
	Index 0 is reserved for the `Unknown` type.
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
	query       : Type_Index,
	mutation    : Type_Index,
	subscription: Type_Index,
	/*
	Allocator used to allocate memory for Types, Fields and Input_Values.
	*/
	allocator   : mem.Allocator,
}

Type :: struct {
	kind       : Type_Kind,
	name       : string,
	types      : []Type_Index,  // Interface and Union
	interfaces : []Type_Index,  // Object and Interface
	fields     : []Field,       // Object and Interface
	enum_values: []string,      // Enum
	inputs     : []Input_Value, // Input_Object
	of_type    : Type_Index,    // Non_Null and List
}

// Index of the type in the `Schema.types` array
Type_Index :: distinct int

Type_Kind :: enum {
	Unknown, // Zero case
	Scalar,
	Object,
	Interface,
	Union,
	Enum,
	Input_Object,
	List,
	Non_Null,
}

Field :: struct {
	name: string,
	args: []Input_Value,
	type: Type_Index,
}

Input_Value :: struct {
	name: string,
	type: Type_Index,
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
	) -> Type_Index {
		for type, i in s.types {
			if type.name == name do return Type_Index(i)
		}
		append(&s.types, Type{name = name})
		return Type_Index(len(s.types) - 1)
	}
	
	t := tokenizer_make(src)
	for {
		token := tokenizer_next(&t) or_break

		#partial switch token.kind {
		// Ignore string comments
		case .String, .String_Block:
			continue
		// Type Object
		case .Type:
			token = tokenizer_next(&t)

			#partial switch token.kind {
			case .Name:
				idx := USER_TYPES_START
				type: ^Type
				search: {
					for ; idx < len(s.types); idx += 1 {
						type = &s.types[idx]
						if type.name != token.value do continue
						if type.kind == .Unknown do break search
						return Error_Repeated_Type{token.value}
					}
					idx += 1 // TODO append
					type = &s.types[idx]
					type.name = token.value
				}

				token = tokenizer_next(&t)
				if (token.kind != .Brace_Left) {
					return Error_Unexpected_Token{token}
				}

				fields := make([dynamic]Field, 0, 8, s.allocator) or_return

				// Parse fields
				for {
					token = tokenizer_next(&t)
					if (token.kind == .Brace_Right) do break

					if (token.kind != .Name) {
						return Error_Unexpected_Token{token}
					}

					field := Field{name = token.value}

					token = tokenizer_next(&t)
					// Parse arguments
					if (token.kind == .Parenthesis_Left) {
						for {
							token = tokenizer_next(&t)
							if (token.kind == .Parenthesis_Right) do break

							if (token.kind != .Name) {
								return Error_Unexpected_Token{token}
							}

							arg := Input_Value{name = token.value}

							token = tokenizer_next(&t)
							if (token.kind != .Colon) {
								return Error_Unexpected_Token{token}
							}

							// Parse argument type
							token = tokenizer_next(&t)
							if (token.kind != .Name) {
								return Error_Unexpected_Token{token}
							}

							arg.type = find_type(s, token.value)
							if (arg.type == 0) {
								return Error_Unexpected_Token{token}
							}

							field.args = append(fields.args, arg)
						}
					} else if (token.kind != .Colon) {
						return Error_Unexpected_Token{token}
					}

					token = tokenizer_next(&t)
					if (token.kind != .Name) {
						return Error_Unexpected_Token{token}
					}

					field.type = find_type(s, token.value)
					if (field.type == 0) {
						return Error_Unexpected_Token{token}
					}

					fields = append(fields, field)
				}
			}
		case:
			return Error_Unexpected_Token{token}
		}
	}

	return
}