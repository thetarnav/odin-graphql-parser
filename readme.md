# Odin GraphQL Parser

This is a parser for the Odin GraphQL language based on the [GraphQL spec](https://spec.graphql.org/October2021).

Currently only parsing the schema is supported.

## Usage

```gql
# schema.gql
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
	color: Color
}
interface Node {
	id: ID!
}
enum Color {
	RED
	GREEN
	BLUE
}
```

```odin
package example

import "core:fmt"
import gql "odin-graphql-parser"

schema_src := #load("schema.gql", string)

main :: proc() {
    schema := schema_make()
	err := schema_parse(&schema, schema_src)
    defer schema_delete(schema) // Or free the used allocator

    if err != nil {
        fmt.printfln("Error parsing schema: %v", err)
        return
    }

    for type in schema.types {
        fmt.printfln("Type: %s", type.name)
    }
}
```
