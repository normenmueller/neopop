---
title: Design
version: 0.1
---

# Terminology

## Graph Seed

A **graph seed** is a declarative specification of how a graph should be initialized (DDL/DML combination). There are two kinds graph seeds:

- modular
- monolithic

### Modular

A **modular graph seed** is a triple of Cypher DDL and DML statements:

```
( pre-stms
, grp-decl
, post-stms
)
```

#### Pre / Post Statements (`pre-` & `post-stms`)

DDL statements for setup, configuration, teardown etc.:

- [Schema](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_schema)
- [Database Management](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_database_management)
- [Access Control](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_access_control)
- [ON GRAPH](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_on_graph)
- [ON DATABASE](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_on_database)
- [ON DBMS](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_on_dbms)

#### Graph Declaration (`grp-decl`)

DML Statements only.

##### Pure
<a name="pgd"></a>

A **pure graph declaration** exclusively allows:

- [Read Query](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_read_query_structure) statements
- [Write Query](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_write_query) statements

In short, [Read-Write Query](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_read_write_query_structure) statements.

##### Impure
<a name="igd"></a>

An **impure graph declaration** allows all of [pure graph declratation](#pgd) and:

- [Clauses](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_clauses)
- [Subqueries](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_subqueries)
- [Predicates](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_predicates)
- [Expressions](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_expressions)
- [Functions](https://neo4j.com/docs/cypher-cheat-sheet/5/all/#_functions)

### Monolithic

A **monolithic graph seed** is a modular impure graph seed flattened in one file.

## Graph Population

A **graph population** is an operational process of executing a graph seed into a live database, governed by an execution control (what happens on errors) and a commit model (how transactions are grouped), i.e., it specifies the transport behavior (what) and commit model (how).

# CLI Client

## Synopsis

cf. [Usage](../src/neopop/usg/neopop.txt)

## Populations

### Seeding: monolithic

cf. [Using](../src/neopop/usg/monolithic.txt) Neopop `monolithic` command.

⚠️  Monolithic graph seeds can only be populated with statement-wise commit model. This is due to the fact that, as to Neo4j, DDL Statements must not be warpped in `:begin ... :commit`! A graph declaration, however, might be populated statement-wise or packaged-wise.

### Seeding: modular

cf. [Using](../src/neopop/usg/modular.txt) Neopop `modular` command.

## Exkursion: Realization of commit models

**Statement-wise commit model realization**

````plaintext
cypher-shell --fail-fast|--fail-at-end -f FILE
````

**Package-wise commit model realization**

In pseudo code:

````plaintext
cypher-shell --fail-fast|--fail-at-end -f <ddl-pre.cypher>

chks = create_chunks N FILE
for f in chks; do
  { printf ':begin\n'; cat "$f"; printf '\n:commit\n'; } \
  | cypher-shell --fail-fast|--fail-at-end || {
    echo "❌ failed on $f"
    exit 1
  }

cypher-shell --fail-fast|--fail-at-end -f <ddl-post.cypher>
````

⚠️  In case of `--fail-at-end` loop runs to the end.

## DB Preparations

### Checking: db-check

cf. [Using](../src/neopop/usg/db-check.txt) Neopop `db-check` command.

### Cleaning: db-clean

cf. [Using](../src/neopop/usg/db-clean.txt) Neopop `db-clean` command.

### Resetting: db-reset

cf. [Using](../src/neopop/usg/db-clean.txt) Neopop `db-reset` command.

# Outlook

## Aliases

### Check DB

````plaintext
neopop -u usr -p pass -a url -d db db-check
  -> ( exec .neopop/check-db.sh
     | neopop -u usr -p pass -a url -d db monolithic --seed .neopop/check-db.cypher
     )
````

### Clean DB

````plaintext
neopop -u usr -p pass -a url -d db db-clean
  -> ( exec .neopop/clean-db.sh
     | neopop -u usr -p pass -a url -d db monolithic --seed .neopop/clean-db.cypher
     )
````

Delete all nodes/relationships, drop constraints, and drop indexes.

### Reset DB

````plaintext
neopop -u usr -p pass -a url -d db db-reset
  -> ( exec .neopop/reset-db.sh
     | neopop -u usr -p pass -a url -d db monolithic --seed .neopop/reset-db.cypher
     )
````

Drop and create database.

[^cysdoc]: <https://neo4j.com/docs/operations-manual/current/cypher-shell/>

