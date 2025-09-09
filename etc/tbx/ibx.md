---
title: 🧊 Icebox
---

# Overview

| Area            | Idea                                                                                                           |
| --------------- | ---------------------------------------------------------------------------------------------------------------|
| **Usability**   | Make `--password` optional, via prompt (`read -s`)                                                             |
| **Convenience** | `.env` support or `N4J_USER`, `N4J_PASS` via `env`                                                             |
| **Extension**   | `--dry-run`, `--raw`, `--log-level`, `--check-only` etc.                                                       |
| **CI**          | Basic GitHub Action with `cypher-shell --version` + syntax check                                               |
| **Sessions**    | Cypher-shell Daemon                                                                                            |

# Cypher-shell Daemon

At the moment neoject starts cypher-shell once for each chunk, which is simple but expensive (TCP handshake, auth, session init, etc.).

You could build a kind of "cypher-shell daemon" that:

1. opens the connection once when neoject is started
2. passes all chunks one after the other to the same cypher-shell process
3. only closes again at the end

How this would work

1. Start cypher-shell in the background

```
coproc CYPHER { cypher-shell -u "$user" -p "$pass" -a "$url"; }
```

- CYPHER is then a file descriptor pair (`${CYPHER[0]} = stdout`, `${CYPHER[1]} = stdin`)
- You simply write statements in `${CYPHER[1]}` and read the result from `${CYPHER[0]}`.

2. simply pipe chunks into the process

```
cat "$chunkfile" >&"${CYPHER[1]}"
```

3. finish clean

```
exec {CYPHER[1]}>&-  # stdin zum cypher-shell schließen
exec {CYPHER[0]}<&-  # stdout schließen
wait
````

## Advantages

- Significantly faster with many chunks (only one authentication and session setup).
- No OS overhead per chunk.

## Disadvantages

- Error handling becomes more complex:
  - If a chunk fails, you have to decide: Kill session or continue?
  - You may need :begin / :commit or :rollback logic to separate chunks cleanly.
- Must ensure that one chunk does not “run after” another (output parsing!).
- With schema changes (DDL) in the middle, transactions can be tricky because Neo4j does not allow DDL+DML in the same TX → You would have to deliberately set :begin / :commit.

