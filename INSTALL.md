---
title: Installation Guide
version: v0.1
---

# Prerequisites

- **Neo4j 5.x** (running and accessible), with at least one database (e.g. `neo4j`).
- **cypher-shell** in your `PATH` (bundled with Neo4j, see Desktop section below).
- **Bash** (macOS/Linux or Windows via WSL) plus standard tools: `awk`, `grep`, `sed`, `mktemp`, `date`.
- Network access to the **Bolt** endpoint (e.g. `neo4j://localhost:7687`).

> Note: `db-reset` requires access to the **system** database.

⚠️  Note on Neo4j Tools: Neopop requires `cypher-shell`, which is part of the official Neo4j distribution. It is **not included** with Neopop and must be available on your system's `PATH`. Neo4j Desktop and `cypher-shell` are subject to their own license terms (Neo4j license / Apache 2.0). Using Neopop does not change or override these terms.

# Install Neopop

```bash
git clone https://github.com/normenmueller/neopop.git
cd neopop
make install
neopop --version
```

*(Uninstall via `make uninstall`.)*

# Optional: Local Neo4j (Desktop)

## Install Neo4j Desktop

Download **Neo4j Desktop v5** for your platform: <https://neo4j.com/download/>

- Available for macOS, Windows, Linux
- Requires a free Neo4j account at first launch
- **Does not install `cypher-shell` globally** — see below

**macOS example paths:**

After first launch, the following directories appear:

```
~/Library/Application Support/neo4j-desktop/Application/Data/dbmss/bin        # cypher-shell, neo4j-admin
~/Library/Application Support/neo4j-desktop/Application/Data/dbmss/conf       # neo4j.conf
```

> Desktop adds the `bin` directory to your `PATH` automatically **while an instance is running**.

## Create project & instance

1. Start Neo4j Desktop.
2. Create a new instance, e.g.:
   **Name:** `sandbox` · **Version:** `5.x` · **User:** `neo4j` (fixed) · **Password:** `12345678`
   The instance starts with two databases: **`neo4j`** and **`system`**.

## Tune memory (optional but recommended)

Edit `NEO4J_HOME/conf/neo4j.conf`:

- `server.memory.heap.initial_size`
- `server.memory.heap.max_size`
- optional: `server.memory.pagecache.size`
- optional (transaction limit): `dbms.memory.transaction.total.max`

Recommendation: Set **heap initial = max**, define page cache explicitly. Start with `neo4j-admin server memory-recommendation`. Example:

```properties
server.memory.heap.initial_size=8G
server.memory.heap.max_size=8G
server.memory.pagecache.size=16G
dbms.memory.transaction.total.max=2G
```

*Note*: For large `UNWIND` or batch writes, `dbms.memory.transaction.total.max` can be a bottleneck. Reduce it or split queries into chunks.

Restart the database after editing.

**Docs:** [neo4j.conf][1] · [Memory configuration][2]

# Prepare Neopop

## Determine connection details

### Local (Desktop)

In Neo4j Desktop, open your running instance and copy the **Connection URL** (usually `neo4j://127.0.0.1:7687`). Use it with `-a` when calling `neopop`.

### Remote

Obtain address, user, password, and database name from your administrator. Ensure Bolt port is reachable (firewall/VPN).

## Test the connection

> ⚠️ **Global options** (`-u/-p/-a/-d`) must appear **before** the subcommand.

```bash
neopop -u neo4j -p 12345678 -a neo4j://localhost:7687 -d neo4j db-check
```

Example output:

```
[2025-08-09 14:28:06] ✅ Connection OK
```

Typical issues:

- Wrong Bolt URL (wrong host/port)
- Database not running
- Invalid password
- Firewall or VPN blocking access

[1]: https://neo4j.com/docs/operations-manual/current/configuration/neo4j-conf/ "The neo4j.conf file - Operations Manual"
[2]: https://neo4j.com/docs/operations-manual/current/performance/memory-configuration/ "Memory configuration - Operations Manual"

