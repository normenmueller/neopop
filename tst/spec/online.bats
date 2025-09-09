#!/usr/bin/env bats

# Setup / Helpers {{{1
setup() { #{{{2
  neopop=./src/neopop.sh

  user=neo4j
  pass=12345678
  db=neo4j
  uri=neo4j://127.0.0.1:7687

  source ./src/neopop/ec.sh

  # Mons
  movies1_mxf="./tst/data/mon/movies-1.cypher"
  movies2_mxf="./tst/data/mon/movies-2.cypher"
  movies3_mxf="./tst/data/mon/movies-3.cypher"
  living_mxf="./tst/data/mon/living.cypher"
  tricky_mxf="./tst/data/mon/tricky.cypher"

  # Mods
  living_grp="./tst/data/mod/living/living-grp.cql"
  living_pre="./tst/data/mod/living/living-pre.cql"

  movies1_grp="./tst/data/mod/movies/movies-1-grp.cql"
  movies1_pre="./tst/data/mod/movies/movies-1-pre.cql"

  movies2_grp="./tst/data/mod/movies/movies-2-grp.cql"
  movies2_pre="./tst/data/mod/movies/movies-2-pre.cql"

  movies3_grp="./tst/data/mod/movies/movies-3-grp.cql"
  movies3_pre="./tst/data/mod/movies/movies-3-pre.cql"
}
cval() { #{{{2
  # Run a Cypher query and print the single scalar result (plain output)
  local q="$1"
  cypher-shell \
    -u "$user" -p "$pass" -a "$uri" -d "$db" \
    --format plain --encryption false --non-interactive "$q" \
  | tail -n +2
}
assert() { #{{{2
  # Assert label/rel counts
  local lab1="$1" exp1="$2"
  local lab2="$3" exp2="$4"
  local rtyp="$5" exp3="$6"

  local c1; c1="$(cval "MATCH (n:$lab1) RETURN count(n) AS c")"
  local c2; c2="$(cval "MATCH (n:$lab2) RETURN count(n) AS c")"
  local cr; cr="$(cval "MATCH ()-[r:$rtyp]->() RETURN count(r) AS c")"

  [ "$c1" -eq "$exp1" ]
  [ "$c2" -eq "$exp2" ]
  [ "$cr" -eq "$exp3" ]
}
run_neopop() { #{{{2
  run "$neopop" -u "$user" -p "$pass" -a "$uri" -d "$db" "$@"
}
# db-check {{{1
@test "[online/db/check] succeeds against running DB" { #{{{2
  run_neopop db-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"Connection OK"* ]]
}
# db-clean {{{1
@test "[online/db/clean] wipes graph contents" { #{{{2
  # seed
  run_neopop monolithic --reset-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  local seeded; seeded="$(cval 'MATCH (n) RETURN count(n) AS c')"
  [ "$seeded" -gt 0 ]

  # clean
  # Note: labels, relationship types, property keys are still there
  run_neopop db-clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"Database cleaning completed"* ]]
  local after; after="$(cval 'MATCH (n) RETURN count(n) AS c')"
  [ "$after" -eq 0 ]
}
# db-reset {{{1
@test "[online/db/reset] drops & recreates DB" { #{{{2
  # seed
  run_neopop monolithic --reset-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  local seeded; seeded="$(cval 'MATCH (n) RETURN count(n) AS c')"
  [ "$seeded" -gt 0 ]

  # reset
  run_neopop db-reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"Database reset completed"* ]]
  local after; after="$(cval 'MATCH (n) RETURN count(n) AS c')"
  [ "$after" -eq 0 ]
}
# monolithic {{{1
@test "[online/mon] living with --clean-db" { #{{{2
  run_neopop monolithic --clean-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mon] living with --clean-db & --stm-wise" { #{{{2
  run_neopop monolithic --stm-wise --clean-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mon] living with --reset-db" { #{{{2
  run_neopop monolithic --reset-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mon] living with --reset-db & --stm-wise" { #{{{2
  run_neopop monolithic --stm-wise --reset-db --seed "$living_mxf"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mon] movies1 with --clean-db" { #{{{2
  run_neopop monolithic --clean-db --seed "$movies1_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
@test "[online/mon] movies2 with --clean-db" { #{{{2
  run_neopop monolithic --clean-db --seed "$movies2_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
@test "[online/mon] movies3 with --clean-db" { #{{{2
  run_neopop monolithic --clean-db --seed "$movies3_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
@test "[online/mon] movies1 with --reset-db" { #{{{2
  run_neopop monolithic --reset-db --seed "$movies1_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
@test "[online/mon] movies2 with --reset-db" { #{{{2
  run_neopop monolithic --reset-db --seed "$movies2_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
@test "[online/mon] movies3 with --reset-db" { #{{{2
  run_neopop monolithic --reset-db --seed "$movies3_mxf"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172
}
# modular {{{1
@test "[online/mod/stm] (_  , living, _   ) with --clean-db" { #{{{2
  run_neopop modular \
    --stm-wise \
    --clean-db \
    --seed-grp "$living_grp"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mod/stm] (pre, living, _   ) with --clean-db" { #{{{2
  run_neopop modular \
    --stm-wise \
    --clean-db \
    --seed-pre "$living_pre" \
    --seed-grp "$living_grp"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mod/pkg] size  2 of (_  , living , _) with --clean-db" { #{{{2
  run_neopop modular \
    --pkg-wise --pkg-size 2 \
    --clean-db \
    --seed-grp "$living_grp"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mod/pkg] size  2 of (pre, living , _) with --clean-db" { #{{{2
  run_neopop modular \
    --pkg-wise --pkg-size 2 \
    --clean-db \
    --seed-pre "$living_pre" \
    --seed-grp "$living_grp"
  [ "$status" -eq 0 ]
  assert Person 2 City 2 LIVES_IN 2
}
@test "[online/mod/pkg] size 10 of (pre, movies1, _) with --clean-db" { #{{{2
  run_neopop modular \
    --pkg-wise --pkg-size 10 \
    --clean-db \
    --seed-pre "$movies1_pre" \
    --seed-grp "$movies1_grp"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172

  # 1) Check the count=... line directly
  echo "$output" | grep -qE 'Executing DML .* \(count=4\)'
  # 2) Count the number of package starts
  #pkg_starts=$(printf "%s" "$output" | grep -cE 'pkg #[0-9]+: ')
  #[ "$pkg_starts" -eq 4 ]
  # 3) Successful packages count
  pkg_ok=$(printf "%s" "$output" | grep -cE '✓ pkg #[0-9]+ ok')
  [ "$pkg_ok" -eq 4 ]
  # Check cleanup track
  echo "$output" | grep -qE 'Removed chunk dir: .*/neopop-chunks-'
}
@test "[online/mod/pkg] size 10 of (pre, movies2, _) with --clean-db" { #{{{2
  run_neopop modular \
    --pkg-wise --pkg-size 10 \
    --clean-db \
    --seed-pre "$movies2_pre" \
    --seed-grp "$movies2_grp"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172

  # 1) Check the count=... line directly
  echo "$output" | grep -qE 'Executing DML .* \(count=3\)'
  # 2) Count the number of package starts
  #pkg_starts=$(printf "%s" "$output" | grep -cE 'pkg #[0-9]+: ')
  #[ "$pkg_starts" -eq 3 ]
  # 3) Successful packages count
  pkg_ok=$(printf "%s" "$output" | grep -cE '✓ pkg #[0-9]+ ok')
  [ "$pkg_ok" -eq 3 ]
  # Check cleanup track
  echo "$output" | grep -qE 'Removed chunk dir: .*/neopop-chunks-'
}
@test "[online/mod/pkg] size 10 of (pre, movies3, _) with --clean-db" { #{{{2
  run_neopop modular \
    --pkg-wise --pkg-size 10 \
    --clean-db \
    --seed-pre "$movies3_pre" \
    --seed-grp "$movies3_grp"
  [ "$status" -eq 0 ]
  assert Person 133 Movie 38 ACTED_IN 172

  # 1) Check the count=... line directly
  echo "$output" | grep -qE 'Executing DML .* \(count=1\)'
  # 2) Count the number of package starts
  #pkg_starts=$(printf "%s" "$output" | grep -cE 'pkg #[0-9]+: ')
  #[ "$pkg_starts" -eq 1 ]
  # 3) Successful packages count
  pkg_ok=$(printf "%s" "$output" | grep -cE '✓ pkg #[0-9]+ ok')
  [ "$pkg_ok" -eq 1 ]
  # Check cleanup track
  echo "$output" | grep -qE 'Removed chunk dir: .*/neopop-chunks-'
}

