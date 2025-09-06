Neo4j has changed the preference for subquery syntax in 5.x; both forms work, but depending on the minor you get a deprecation warning for the other variant:

- `CALL { … }`  (older "preferred"; today partly "deprecated")
- `CALL () { … }` (vice versa)

1) Global preset + sample

After the defaults:

```
SUBQ_STYLE=""  # "brace" -> CALL { ... }, "paren" -> CALL () { ... }
```

Auxiliary function:

```
pick_subq_style() { # {{{2
  # Decide which subquery syntax works on this server.
  # Sets SUBQ_STYLE to "brace" or "paren". Returns rc, never exits.
  local q_brace='CALL { RETURN 1 AS x } RETURN x;'
  local q_paren='CALL () { RETURN 1 AS x } RETURN x;'

  # Env override: NEOPOP_SUBQ=brace|paren (optional)
  case "${NEOPOP_SUBQ:-}" in
    brace|paren) SUBQ_STYLE="$NEOPOP_SUBQ"; return 0 ;;
    "") : ;;
    *) log "❌ Invalid NEOPOP_SUBQ (use 'brace' or 'paren')"
       return $EXIT_INTERNAL_API_MISUSE ;;
  esac

  [[ -n "$SUBQ_STYLE" ]] && return 0

  if printf '%s\n' "$q_brace" | cys plain ff >/dev/null; then
    SUBQ_STYLE="brace"; return 0
  fi
  if printf '%s\n' "$q_paren" | cys plain ff >/dev/null; then
    SUBQ_STYLE="paren"; return 0
  fi
  log "❌ No supported subquery syntax detected"
  return $EXIT_INTERNAL_API_MISUSE
}
```

Helper for opening/closing:

````
subq_open(){ [[ "$SUBQ_STYLE" == paren ]] && printf 'CALL () {\n' \
                                   || printf 'CALL {\n'; }
subq_close(){ printf '}\n'; }
````

2) Determine once before DB operations

After the global validations (e.g. directly after "Ensure requirements are met!"):

```
# Decide subquery syntax once (needed by dbcln, etc.)
if ! pick_subq_style; then
  exit $EXIT_INTERNAL_API_MISUSE
fi
```

3) Convert `dbcln` so that it uses `subq_open`/`close`

Replace:

```
out="$(printf '%s\n' "
CALL {
  MATCH (n) WITH n LIMIT $BATCH
  DETACH DELETE n
  RETURN count(*) AS deleted
}
RETURN deleted;" | cys plain ff)"
```

with:

```
out="$(
  {
    subq_open
    printf '%s\n' \
'  MATCH (n) WITH n LIMIT $BATCH
  DETACH DELETE n
  RETURN count(*) AS deleted'
    subq_close
    printf 'RETURN deleted;\n'
  } | cys plain ff
)"
```

