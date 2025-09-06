---
title: Design Decision Log
showMiniToc: true
version: 0.1
---

# Readability validation

Readability is validated by CLI parsing exclusively.

# Wrapping & Execution Guidelines

| Scenario                                        | Command                          | Notes                                               |
| ----------------------------------------------- | -------------------------------- | --------------------------------------------------- |
| Execute a file *as-is* (statement-wise commits) | `csy file.cypher`                | Uses `cypher-shell -f` for efficiency.              |
| Execute stdin *as-is* (statement-wise commits)  | `some_command | csy -`           | Reads from stdin, one transaction per statement.    |
| Execute a file wrapped in a single transaction  | `wrp file.cypher \| csy -`       | Wraps with `:begin/:commit` before piping to `csy`. |
| Execute stdin wrapped in a single transaction   | `some_command \| wrp - \| csy -` | Wraps stdin data and pipes to `csy`.                |

**Notes:**

- `wrp` outputs wrapped content to stdout; always pipe its output into `csy -`.
- Wrapping is **DML-only** — do not include DDL in wrapped content.
- For large imports, use chunking logic to split into multiple calls to `wrp ... | csy -`.

**Use statement‑wise (`csy`) when**

- Script mixes DDL and DML.
- You want fault isolation (partial progress on errors).
- Queries are already set‑based (large `UNWIND` blocks).

**Use bundled (`wrp … | csy -`) when**

- DML‑only with many small `CREATE`/`MERGE` statements.
- You want fewer commits for better throughput.

⚠️  Bundled imports use more heap/page cache and lock time; one error rolls back the chunk.

⚠️  Never bundle DDL.

**Guidelines**

- Chunk large imports (e.g., 5k–20k statements per chunk).

