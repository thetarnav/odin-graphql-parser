# Odin GraphQL Parser

This is a GraphQL language parser based on the [GraphQL spec](https://spec.graphql.org/October2021) written in [Odin](https://odin-lang.org/).

Currently only parsing the schema is supported.

## Usage

```odin
package example

import "core:fmt"
import gql "odin-graphql-parser"

schema_src := #load("schema.gql", string)

main :: proc() {
    schema := gql.schema_make()
    err := gql.schema_parse(&schema, schema_src)
    defer gql.schema_delete(schema) // Or free the used allocator

    if err != nil {
        fmt.printfln("Error parsing schema: %v", err)
        return
    }

    for type in schema.types {
        fmt.printfln("Type: %s", type.name)
    }
}
```

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
