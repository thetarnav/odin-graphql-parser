package gql

import "core:fmt"
import "core:mem"
import "core:intrinsics"
import test "core:testing"

schema_src := `
schema {
	query: Root
}

type Root {
	test: TestUnion
}

union TestUnion = Test | Item

type Test implements Node {
	name: String!
	items: [Item]!
}

type Item implements Node {
	name: String
	color(urls: [String!]!): Color
}

interface Node {
	id: ID!
}

enum Color {
	RED
	GREEN
	BLUE
}
`

@(test)
test_schema :: proc(t: ^test.T) {
	schema := schema_make()
	err := schema_parse(&schema, schema_src)
	defer schema_delete(schema)

	if err != nil {
		switch e in err {
			case Unexpected_Token_Error:
				fmt.printfln("unexpected token %v: %s", e.token.kind, e.token.value)

				token_pos := int(uintptr(raw_data(e.token.value)) - uintptr(raw_data(schema_src)))
				start_width := 0
				start := token_pos
				end   := token_pos

				for start > 0 && token_pos - start < 40 {
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

				fmt.println(schema_src[start:end])
				// underline the token
				fmt.printf("%*s", start_width, "")
				fmt.printf("%*s", len(e.token.value), "^")
				fmt.println()

			case Repeated_Type_Error:
				fmt.printfln("repeated type: %v", e.name)
			case Allocator_Error:
				fmt.printfln("allocator error: %v", e)
		}
		test.fail(t)
	}

	expected_types: []Type = {
		{ // USER_TYPES_START + 0
			name       = "Root",
			kind       = Type_Kind.Object,
			fields     = {
				{
					name = "test",
					value = {
						index = USER_TYPES_START + 1,
					},
				},
			},
		},
		{ // USER_TYPES_START + 1
			name       = "TestUnion",
			kind       = Type_Kind.Union,
			members    = {USER_TYPES_START + 2, USER_TYPES_START + 3},
		},
		{ // USER_TYPES_START + 2
			name       = "Test",
			kind       = Type_Kind.Object,
			interfaces = {USER_TYPES_START + 4},
			fields     = {
				{
					name = "name",
					value = {
						index = 1,
						non_null_flags = 0b00000001,
					},
				},
				{
					name = "items",
					value = {
						index = USER_TYPES_START + 3,
						lists = 1,
						non_null_flags = 0b00000010,
					},
				},
			},
		},
		{ // USER_TYPES_START + 3
			name       = "Item",
			kind       = Type_Kind.Object,
			interfaces = {USER_TYPES_START + 4},
			fields     = {
				{
					name = "name",
					value = {
						index = 1,
					},
				},
				{
					name = "color",
					args = {
						{
							name = "urls",
							type = {
								index = 1,
								non_null_flags = 0b00000011,
								lists = 1,
							},
						},
					},
					value = {
						index = USER_TYPES_START + 5,
					},
				},
			},
		},
		{ // USER_TYPES_START + 4
			name       = "Node",
			kind       = Type_Kind.Interface,
			fields     = {
				{
					name = "id",
					value = {
						index = 5,
						non_null_flags = 0b00000001,
					},
				},
			},
		},
		{ // USER_TYPES_START + 5
			name       = "Color",
			kind       = Type_Kind.Enum,
			enum_values = {"RED", "GREEN", "BLUE"},
		},
	}

	test.expect_value(t, len(schema.types), USER_TYPES_START + len(expected_types))
	for type, i in schema.types[USER_TYPES_START:] {
		// fmt.printfln("type %d: %s", i, type.name)
		expected := expected_types[i]
		expect_value_name(t, type.name, expected.name, "name")
		expect_value_name(t, type.kind, expected.kind, "kind")

		expect_value_name(t, len(type.fields), len(expected.fields), "fields")
		for field, j in type.fields {
			expected_field := expected.fields[j]
			expect_value_name(t, field.name, expected_field.name, "field name")
			expect_value_name(t, field.value.index, expected_field.value.index, "field type index")
			test.expectf(t, field.value.non_null_flags == expected_field.value.non_null_flags, "field type flags expected %b, got %b", expected_field.value.non_null_flags, field.value.non_null_flags)
			expect_value_name(t, field.value.lists, expected_field.value.lists, "field type lists")

			expect_value_name(t, len(field.args), len(expected_field.args), "args")
			for arg, k in field.args {
				expected_arg := expected_field.args[k]
				expect_value_name(t, arg.name, expected_arg.name, "arg name")
				expect_value_name(t, arg.type.index, expected_arg.type.index, "arg type index")
				test.expectf(t, arg.type.non_null_flags == expected_arg.type.non_null_flags, "arg type flags expected %b, got %b", expected_arg.type.non_null_flags, arg.type.non_null_flags)
			}
		}

		expect_value_name(t, len(type.interfaces), len(expected.interfaces), "interfaces")
		for interface, j in type.interfaces {
			expect_value_name(t, interface, expected.interfaces[j], "interface")
		}

		expect_value_name(t, len(type.members), len(expected.members), "members")
		for member, j in type.members {
			expect_value_name(t, member, expected.members[j], "member")
		}

		expect_value_name(t, len(type.enum_values), len(expected.enum_values), "enum_values")
		for enum_value, j in type.enum_values {
			expect_value_name(t, enum_value, expected.enum_values[j], "enum_value")
		}
	}
}

expect_value_name :: proc(t: ^test.T, value, expected: $T, name: string, loc := #caller_location) -> bool where intrinsics.type_is_comparable(T) {
	return test.expectf(t, value == expected, "%s expected %v, got %v", name, expected, value, loc=loc)
}