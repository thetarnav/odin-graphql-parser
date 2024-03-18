package gql

import "core:mem"

Schema :: struct {
	types       : [dynamic]Type,
	fields      : [dynamic]Field,
	inputs      : [dynamic]Input_Value,
	query       : Type_Index,
	mutation    : Type_Index,
	subscription: Type_Index,
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

DEFAULT_CAP :: 64

schema_init :: proc(
	s: ^Schema,
	cap := DEFAULT_CAP,
	allocator := context.allocator,
) -> mem.Allocator_Error #no_bounds_check {
	s.types  = make(type_of(s.types),  6, cap, allocator) or_return
	s.fields = make(type_of(s.fields), 0, cap, allocator) or_return
	s.inputs = make(type_of(s.inputs), 0, cap, allocator) or_return
	s.types[0] = {}
	s.types[1] = {kind = .Scalar, name = "String"}
	s.types[2] = {kind = .Scalar, name = "Int"}
	s.types[3] = {kind = .Scalar, name = "Float"}
	s.types[4] = {kind = .Scalar, name = "Boolean"}
	s.types[5] = {kind = .Scalar, name = "ID"}
	return nil
}

schema_make :: proc(
	cap := DEFAULT_CAP,
	allocator := context.allocator,
) -> (s: Schema, err: mem.Allocator_Error) #optional_allocator_error {
	return s, schema_init(&s, cap, allocator)
}
make_schema :: schema_make