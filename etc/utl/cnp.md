---
title: Copy'n'Paste
---

# "Online BATS Debugging"

For example:

````bash
@test "[offline/spc] test-con against fake host → connection failed" {
  run_neoject test-con

  echo "Exit status: $status" >&3
  echo "Output:" >&3
  echo "$output" >&3

  [ "$status" -eq $EXIT_DB_CON_FAIL ]
  [[ "$output" == *"Connection failed"* ]]
}
````

This will print each chunk's file name and its contents to the console.

# Cypher Statements

## Count all nodes in the database, regardless of label

```
MATCH (n)
RETURN count(n) AS totalNodes;
```

## Count all relationships in the database, regardless of type

```
MATCH ()-[r]->()
RETURN count(r) AS totalRels;
```

