package gql

Schema :: struct {
	types       : []Type,
	query       : Type_Name,
	mutation    : Maybe(Type_Name),
	subscription: Maybe(Type_Name),
}

Type :: struct {
	kind        : Type_Kind,
	name        : Type_Name,
	types       : []Type_Name,   // Interface and Union
	interfaces  : []Type_Name,   // Object and Interface
	fields      : []Field,       // Object and Interface
	enum_values : []string,      // Enum
	input_fields: []Input_Value, // Input_Object
	of_type     : Type_Name,     // Non_Null and List
}

Type_Name :: distinct string

Type_Kind :: enum {
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
	type: Type_Name,
}

Input_Value :: struct {
	name   : string,
	type   : Type_Name,
}

scalar_string  := Type{kind = .Scalar, name = "String"}
scalar_int     := Type{kind = .Scalar, name = "Int"}
scalar_float   := Type{kind = .Scalar, name = "Float"}
scalar_boolean := Type{kind = .Scalar, name = "Boolean"}
scalar_id      := Type{kind = .Scalar, name = "ID"}