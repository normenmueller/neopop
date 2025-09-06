---
title: APOC
---

# Install `apoc-extended`

- Download at <https://github.com/neo4j-contrib/neo4j-apoc-procedures>.
- Copy to `/path/to/neo4j/plugins/`
- `/path/to/neo4j/conf/apoc.conf`

    ```properties
    apoc.export.file.enabled=true
    apoc.import.file.enabled=true
    apoc.import.file.use_neo4j_config=true
    apoc.cypher.runfile.enabled=true
    ```
- `/path/to/neo4j/conf/neo4j.conf`

    ```properties
    dbms.security.procedures.unrestricted=apoc.*
    dbms.security.procedures.allowlist=apoc.*
    ```
- Verify

    ```bash
    echo 'RETURN apoc.version()' \
      | cypher-shell -u neo4j -p <your-pass> -a neo4j://localhost:7687
    ```

  and:

    ```bash
    echo 'SHOW PROCEDURES YIELD name WHERE name CONTAINS("runFile") RETURN name;' \
      | cypher-shell -u neo4j -p <your-pass> -a neo4j://localhost:7687
    ```

  If you see `apoc.cypher.runFile` there → ✔️

> `apoc.cypher.runFile(..., {useTx:true})` turns the entire file into a transaction - but:
>
> - As soon as DDL statements (e.g. CREATE CONSTRAINT, DROP INDEX) occur in it, `useTx:true` fails, as DDL is not permitted in active transactions.
> - The following applies to DDL (as with JDBC / RDBMS): they are implicitly autocommitted and cannot be rolled back.
>
> Conclusion:
>
> - `useTx:true` → only for DML
> - `useTx:false` → for DDL + DML mixed

# APOC & Transactions

| Category                             | Type                                                                        | Description                                                      | In `apply` (APOC)             | In `slurp` (Tx via cypher-shell)   |
| ------------------------------------ | --------------------------------------------------------------------------- | ---------------------------------------------------------------- | ----------------------------- | ---------------------------------- |
| **DDL (Data Definition Language)**   | `CREATE/DROP CONSTRAINT`<br>`CREATE/DROP INDEX`<br>`CREATE/DROP DATABASE`   | Defines structural metadata (constraints, indexes, DBs).         | ✅ (if semicolon-terminated)  | ⚠️ only via `--ddl-pre/--ddl-post`  |
| **DML (Data Manipulation Language)** | `MERGE`, `CREATE`, `MATCH`, `SET`, `REMOVE`, `DELETE` etc.                  | Standard graph operations on nodes, edges, labels, properties    | ✅                            | ✅                                 |
| **Transactions**                     | `:begin`, `:commit`, `:rollback`                                            | Control of transaction frames for batch imports                  | ❌ **(forbidden)**            | ✅ **(mandatory for slurp)**       |
| **CALL procedures**                  | `CALL apoc. *`, `CALL db.*`, `CALL gds.*`                                   | Procedures for extensions or low-level system accesses           | ✅ (if APOC etc. permitted)   | ✅                                 |
| **Cypher syntax extensions**         | `FOREACH`, `UNWIND`, `WITH`, `RETURN`, `CASE`, `EXISTS`, `LIST`, `MAP` etc. | Control flow, queries, conditions, aggregations, data flow       | ✅                            | ✅                                 |
| **Comments**                         | `// single-line`, `/* multi-line */`                                        | Are ignored, also by APOC                                        | ✅                            | ✅                                 |

# Export a Neo4j DB

Neo4j offers the option of exporting a recorded graph as a pure Cypher script via **APOC**. You can then use this script as a `.cypher` or `.cql` file and import it with `neoject.sh`.

## Requirements

- **APOC plugin installed and active**
- Activated in `apoc.conf`:

```properties
apoc.export.file.enabled=true
apoc.import.file.use_neo4j_config=true
```

*Note*: The path can be found in Neo4j Desktop. It can be found under `Path` in the respective instance.

## Export command in the Neo4j browser or `cypher-shell`:

```cypher
CALL apoc.export.cypher.all(null, {format: 'plain', stream: true})
YIELD cypherStatements
RETURN cypherStatements;
````

This command returns the complete database graph as cypher statements - as a large text block that you can copy. ([Stack Overflow][1])

## Save this as a file:

```bash
echo "<copied cypherStatements text>" > export.cql
```

## Import via `neoject.sh`:

```bash
./src/neoject.sh --clean-db -u neo4j -p <password> -a neo4j://localhost:7687 -f export.cql
````

This imports the entire graph into Neo4j in a single, atomic import.

[1]: https://stackoverflow.com/questions/65298867/export-data-from-neo4j-sandbox "Export data from Neo4j Sandbox - cypher"

