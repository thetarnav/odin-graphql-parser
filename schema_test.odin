package gql

import "core:fmt"
import test "core:testing"

schema_src := `
schema {
	query: Root
}

type Root {
	test: Test
}

type Test implements Node {
	name: String!
	items: [Item]!
}

type Item implements Node {
	name: String
}

interface Node {
	id: ID!
}
`


@(test)
test_schema :: proc(t: ^test.T) {
	schema := schema_make()
	err := schema_parse_string(&schema, schema_src)

	test.expect_value(t, err, nil)

	fmt.printf("\ntypes: \n%v\n\n", schema.types[USER_TYPES_START:])

	test.expect_value(t, len(schema.types), USER_TYPES_START + 4)

	expected_types: []Type = {
		{ // USER_TYPES_START + 0
			name       = "Root",
			kind       = Type_Kind.Object,
			fields     = {
				{
					name = "test",
					type = {
						index = USER_TYPES_START + 1,
					},
				},
			},
		},
		{ // USER_TYPES_START + 1
			name       = "Test",
			kind       = Type_Kind.Object,
			interfaces = {2},
			fields     = {
				{
					name = "name",
					type = {
						index = 1,
						non_null_flags = 0b00000001,
					},
				},
				{
					name = "items",
					type = {
						index = USER_TYPES_START + 3,
						lists = 1,
						non_null_flags = 0b00000010,
					},
				},
			},
		},
		{ // USER_TYPES_START + 2
			name       = "Node",
			kind       = Type_Kind.Interface,
			fields     = {
				{
					name = "id",
					type = {
						index = 5,
						non_null_flags = 0b00000001,
					},
				},
			},
		},
		{ // USER_TYPES_START + 3
			name       = "Item",
			kind       = Type_Kind.Object,
			fields     = {
				{
					name = "name",
					type = {
						index = 1,
					},
				},
			},
		},
	}

	for type, i in schema.types[USER_TYPES_START:] {
		expected := expected_types[i]
		test.expect_value(t, type.name, expected.name)
	}
}
