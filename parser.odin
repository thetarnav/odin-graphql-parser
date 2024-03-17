package gql

Schema :: struct {
	types       : []Type,
	query       : Type,
	mutation    : Maybe(Type),
	subscription: Maybe(Type),
}

Type :: struct {
	kind          : Type_Kind,
	name          : string,
	fields        : []Field,       // Object and Interface
	interfaces    : []Type,        // Object and Interface
	possible_types: []Type,        // Interface and Union
	enum_values   : []Enum_Value,  // Enum
	input_fields  : []Input_Value, // Input
	of_type       : ^Type,         // Non_Null and List
}

Type_Kind :: enum {
	Scalar,
	Object,
	Interface,
	Union,
	Enum,
	Input,
	List,
	Non_Null,
}

Field :: struct {
	name: string,
	args: []Input_Value,
	type: Type,
}

Input_Value :: struct {
	name   : string,
	type   : Type,
	default: string,
}

Enum_Value :: struct {
	name: string,
}

// Type :: union {
// 	Scalar,
// 	Object,
// 	Interface,
// 	Union,
// 	Enum,
// 	Input,
// 	List,
// 	Non_Null,
// }

// Scalar :: struct {
// 	name: string,
// }
// Object :: struct {
// 	name      : string,
// 	fields    : []Field,
// 	interfaces: []Type,
// }
// Interface :: struct {
// 	name      : string,
// 	fields    : []Field,
// 	interfaces: []Type,
// 	types     : []Type,
// }
// Union :: struct {
// 	name : string,
// 	types: []Type,
// }
// Enum :: struct {
// 	name  : string,
// 	values: []Enum_Value,
// }
// Input :: struct {
// 	name  : string,
// 	values: []Input_Value,
// }
// List :: struct {
// 	name: string,
// 	type: ^Type,
// }
// Non_Null :: struct {
// 	name: string,
// 	type: ^Type,
// }