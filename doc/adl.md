---
title: Architecture Decision Log
version: 0.1
---

# ADR-001: Use shell script with `cypher-shell` for data import
<a name="adr-wrp-cshl"></a>

## Status

Accepted

## Context

To import `.cypher` files into Neo4j, multiple technical options were considered:

- `cypher-shell` (official Neo4j CLI)
- CSV + `LOAD CSV`
- APOC imports
- REST/HTTP APIs
- Custom clients (e.g., Haskell, Python, JavaScript)

Additionally, orchestration could have been done via:

- Bash shell script
- Haskell CLI
- Python script
- Makefile automation

## Decision

We use a Bash shell script (`neopop`) that invokes the officially supported `cypher-shell` command-line client.

## Rationale

- `cypher-shell` is officially maintained and cross-platform
- Bash is widely available, zero-dependency, and CI-friendly
- Easy integration into Makefiles, pipelines, or manual runs
- No external dependencies (e.g., Python, Haskell)

**Why Bash works now**:

| Reason                    | Justification                                       |
| ------------------------- | --------------------------------------------------- |
| OS proximity              | Can invoke binaries, manage files and logs easily   |
| Lightweight               | No virtualenvs or builds required                   |
| Minimal data modeling     | No complex in-memory objects needed                 |
| DevOps-native             | Familiar to infra/CI engineers                      |

## Consequences

- Fast setup and simple distribution
- Passwords passed via CLI (→ can be hardened later)
- Error handling delegated to `cypher-shell`
- Script complexity may grow over time

**Why Bash may fail later**:

| Limitation               | Symptoms                               |
| ------------------------ | -------------------------------------- |
| CLI parsing complexity   | Option validation becomes brittle      |
| No structured logging    | Difficult to trace or log with levels  |
| Hard to unit-test        | No dependency injection or mocks       |
| Fragile error handling   | Exit code reliance without granularity |
| Limited portability      | BSD vs GNU tool differences            |
| Weak Windows story       | Requires Cygwin/WSL                    |

## Non-Goals (explicitly out of scope for Bash solution)

- Structured logging (JSON, log levels)
- Rich error model beyond exit codes
- Cross-platform Windows-native support (WSL/Cygwin acceptable)
- Complex DDL/DML validation of input files
- Parallel execution, retries, or backoff strategies
- Full secrets management beyond simple CLI/env handling

## Alternatives Considered

**Migration paths**:

| Language  | When to switch                                                                 |
| --------- | ------------------------------------------------------------------------------ |
| Python    | Rich CLI (Typer), validation (Pydantic), structured logs, retry/backoff needed |
| Rust      | Performance-critical, static typing, cross-platform binaries                   |
| Haskell   | Full type-safe orchestration and declarative pipelines                         |

## Future Considerations

- Migrate to Python or Haskell once feature scope exceeds Bash’s sweet spot
- Extract reusable modules for schema or logging
- Support `.env` or password prompts for better security
- Add structured logging if migrated beyond Bash

