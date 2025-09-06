# 🌱 Neopop

**Neopop** is a thin wrapper around [`cypher-shell`](https://neo4j.com/docs/operations-manual/current/tools/cypher-shell/) for structured graph population in [Neo4j 5](https://neo4j.com/).

It provides **consistent commit models**, **execution control**, and **database preparation** when executing Cypher workloads.

## Features

**Two graph seed kinds**:

- *Monolithic*: a single Cypher file (DDL and/or DML)
- *Modular*: DDL pre/post files + a pure DML file

**Commit models**:

- *Statement-wise*: each statement runs in its own implicit transaction
- *Package-wise*: explicit transaction blocks of size N

**Execution control**:

- `--fail-fast` (default)
- `--best-effort`

**Database preparation**:

- `--clean-db`
- `--reset-db`

**Other**:
- `--echo-cys` echo cypher-shell output during seeding

*(also cf. [Design](doc/dsg.txt).)*

## Usage

```bash
neopop --help
```

or

```bash
man neopop
````

*(also cf. [Synopsis](doc/syn.txt).)*

### Monolithic

```bash
neopop -u neo4j -p secret -a neo4j://localhost:7687 -d test \
  monolithic --seed mixed.cypher
```

- `--seed FILE` Input file containing DDL and/or DML (`-` = STDIN)
- `--stm-wise` (default) Statement-wise commit model
- `--echo-cys` echo cypher-shell output during seeding

### Modular

```bash
neopop -u neo4j -p secret -a neo4j://localhost:7687 -d test \
  modular --seed-pre pre.cypher \
          --seed-grp graph.cypher \
          --seed-post post.cypher \
          --pkg-wise --pkg-size 500
```

- `--seed-grp FILE` (mandatory) pure DML (`-` = STDIN)
- `--seed-pre FILE` / `--seed-post FILE` (optional) DDL only
- `--stm-wise` or `--pkg-wise --pkg-size N`
- `--echo-cys` echo cypher-shell output during seeding

### Database commands

- `db-check` → test connectivity (`RETURN 1`)
- `db-clean` → delete all nodes, relationships, constraints, indexes
- `db-reset` → drop + recreate database, wait until online

## Examples

Monolithic seed from stdin:

```bash
cat mixed.cypher | neopop -u neo4j -p secret -a ... -d test \
  monolithic --seed -
```

Modular seed (statement-wise):

```bash
neopop -u neo4j -p secret -a ... -d test \
  modular --seed-grp graph.cypher --stm-wise
```

Reset database and run workload:

```bash
neopop -u neo4j -p secret -a ... -d test db-reset
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Installation

See [INSTALL.md](INSTALL.md).

## License

See [LICENSE](./LICENSE).
© 2025 [nemron](https://github.com/normenmueller)

