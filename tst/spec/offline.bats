#!/usr/bin/env bats

# Setup / Teardown / Helpers {{{1
setup() { # {{{2
  neopop=./src/neopop.sh

  # irrelevant for offline tests
  user="user"
  pass="pass"
  uri="neo4j://invalid:4711"
  db="db"

  tmpfiles=()

  source ./src/neopop/ec.sh
}
teardown() { # {{{2
  if [ "${#tmpfiles[@]}" -gt 0 ]; then
    for f in "${tmpfiles[@]}"; do
      [ -n "$f" ] && [ -e "$f" ] && rm -f "$f"
    done
  fi
}
mktmp() { # {{{2
  local f
  if mktemp --version >/dev/null 2>&1; then
    # GNU mktemp: suffix allowed
    f="$(mktemp /tmp/neoject-offline.XXXXXX.cypher)"
  else
    # BSD mktemp (macOS): use -t and no suffix
    f="$(mktemp -t neoject-offline.XXXXXX)"
  fi
  printf 'RETURN 1;\n' > "$f"
  tmpfiles+=("$f")
  echo "$f"
}
run_neopop() { # {{{2
  run "$neopop" -u "$user" -p "$pass" -a "$uri" -d "$db" "$@"
}
# Phase 1: Global params (options & switches) {{{1
# Required Globals {{{2
@test "[offline/rglb] missing required global options (a)" { #{{{3
  run "$neopop" -u user -p secret -d db
  [ "$status" -eq $EXIT_GLB_MIS_ROPT ]
  [[ "$output" == *"Missing required global options (-u/-p/-a/-d)!"* ]]
}
@test "[offline/rglb] missing required global options (u)" { #{{{3
  run "$neopop" -p secret -a neo4j://localhost:7687 -d db
  [ "$status" -eq $EXIT_GLB_MIS_ROPT ]
  [[ "$output" == *"Missing required global options (-u/-p/-a/-d)!"* ]]
}
@test "[offline/rglb] missing required global options (p)" { #{{{3
  run "$neopop" -u user -a neo4j://localhost:7687 -d db
  [ "$status" -eq $EXIT_GLB_MIS_ROPT ]
  [[ "$output" == *"Missing required global options (-u/-p/-a/-d)!"* ]]
}
@test "[offline/rglb] missing required global options (d)" { #{{{3
  run "$neopop" -u user -p pass -a neo4j://localhost:7687
  [ "$status" -eq $EXIT_GLB_MIS_ROPT ]
  [[ "$output" == *"Missing required global options (-u/-p/-a/-d)!"* ]]
}
@test "[offline/rglb] missing value -a" { #{{{3
  run "$neopop" -u user -p secret -a -d db
  [ "$status" -eq $EXIT_GLB_ROPT_A_MIS_ARG ]
  [[ "$output" == *"Missing argument for -a"* ]]
}
@test "[offline/rglb] missing value -u" { #{{{3
  run "$neopop" -u -p secret -a neo4j://localhost:7687
  [ "$status" -eq $EXIT_GLB_ROPT_U_MIS_ARG ]
  [[ "$output" == *"Missing argument for -u"* ]]
}
@test "[offline/rglb] missing value -p" { #{{{3
  run "$neopop" -u user -p -a neo4j://localhost:7687
  [ "$status" -eq $EXIT_GLB_ROPT_P_MIS_ARG ]
  [[ "$output" == *"Missing argument for -p"* ]]
}
@test "[offline/rglb] missing value -d" { #{{{3
  run "$neopop" -u user -p secret -a neo4j://localhost:7687 -d
  [ "$status" -eq $EXIT_GLB_ROPT_D_MIS_ARG ]
  [[ "$output" == *"Missing argument for -d"* ]]
}
# General Globals {{{2
@test "[offline/gglb] invalid global switch" { #{{{3
  run_neopop --foo cmd
  [ "$status" -eq $EXIT_GLB_INV_PAR ]
  [[ "$output" == *"Invalid global parameter"* ]]
}
@test "[offline/gglb] invalid global option" { #{{{3
  run_neopop --foo bar cmd
  [ "$status" -eq $EXIT_GLB_INV_PAR ]
  [[ "$output" == *"Invalid global parameter"* ]]
}
@test "[offline/gglb] missing command" { #{{{3
  run_neopop
  [ "$status" -eq $EXIT_GLB_MIS_CMD ]
  [[ "$output" == *"Missing command"* ]]
}
@test "[offline/gglb] invalid command" { #{{{3
  run_neopop foo
  [ "$status" -eq $EXIT_GLB_INV_CMD ]
  [[ "$output" == *"Invalid command"* ]]
}
@test "[offline/gglb] --version rejects any command" { #{{{3
  run_neopop --version foo
  [ "$status" -eq $EXIT_RTFM ]
  [[ "$output" == *"--version cannot be combined with other parameters"* ]]
}
@test "[offline/gglb] --version allows required parameters only" { #{{{3
  run_neopop --version --foo
  [ "$status" -eq $EXIT_RTFM ]
  [[ "$output" == *"--version cannot be combined with other parameters"* ]]
}
# Phase 2: Command-specific parameters {{{1
# modular {{{2
@test "[offline/seed/mod] help" { #{{{3
  run_neopop modular --help
  [ "$status" -eq 0 ]
}
@test "[offline/seed/mod] missing --seed-grp" { #{{{3
  run_neopop modular
  [ "$status" -eq $EXIT_MOD_GRP_REQ ]
  [[ "$output" == *"--seed-grp is required"* ]]
}
@test "[offline/seed/mod] seed-grp unreadable" { #{{{3
  run_neopop modular --seed-grp /no/such/file.cypher
  [ "$status" -eq $EXIT_MOD_GRP_INV_ARG ]
  [[ "$output" == *"--seed-grp '/no/such/file.cypher' not readable"* ]]
}
@test "[offline/seed/mod] seed-pre rejects '-'" { #{{{3
  run_neopop modular --seed-grp - --seed-pre -
  [ "$status" -eq $EXIT_MOD_PRE_INV_ARG ]
  [[ "$output" == *"--seed-pre expects readable file (no '-')"* ]]
}
@test "[offline/seed/mod] seed-post rejects '-'" { #{{{3
  run_neopop modular --seed-grp - --seed-post -
  [ "$status" -eq $EXIT_MOD_PST_INV_ARG ]
  [[ "$output" == *"--seed-post expects readable file (no '-')"* ]]
}
@test "[offline/seed/mod] pkg-wise requires pkg-size" { #{{{3
  run_neopop modular --seed-grp - --pkg-wise
  [ "$status" -eq $EXIT_MOD_PKG_N_REQ ]
  [[ "$output" == *"requires --pkg-size"* ]]
}
@test "[offline/seed/mod] pkg-size without pkg-wise" { #{{{3
  run_neopop modular --seed-grp - --pkg-size 4
  [ "$status" -eq $EXIT_MOD_INV_PAR ]
  [[ "$output" == *"--pkg-size only valid with --pkg-wise"* ]]
}
@test "[offline/seed/mod] pkg-size below PKG_MIN" { #{{{3
  run_neopop modular --seed-grp - --pkg-wise --pkg-size 1
  [ "$status" -eq $EXIT_MOD_PKG_N_INV ]
  [[ "$output" == *"expects integer ≥ 2"* ]]
}
@test "[offline/seed/mod] EXM mutually exclusive" { #{{{3
  run_neopop modular --seed-grp - --fail-fast --best-effort
  [ "$status" -eq $EXIT_EXEC_MX ]
  [[ "$output" == *"mutually exclusive"* ]]
}
@test "[offline/seed/mod] DB prep mutually exclusive" { #{{{3
  run_neopop modular --seed-grp - --clean-db --reset-db
  [ "$status" -eq $EXIT_DBP_MX ]
  [[ "$output" == *"mutually exclusive"* ]]
}
@test "[offline/seed/mod] invalid parameter" { #{{{3
  run_neopop modular --seed-grp - --foo bar
  [ "$status" -eq $EXIT_MOD_INV_PAR ]
  [[ "$output" == *"Invalid modular parameter"* ]]
}
# monolithic {{{2
@test "[offline/seed/mon] help" { #{{{3
  run_neopop monolithic --help
  [ "$status" -eq 0 ]
}
@test "[offline/seed/mon] missing --seed" { #{{{3
  run_neopop monolithic
  [ "$status" -eq $EXIT_MONO_SEED_REQ ]
  [[ "$output" == *"--seed is required"* ]]
}
@test "[offline/seed/mon] seed unreadable file" { #{{{3
  run_neopop monolithic --seed /no/such/file.cypher
  [ "$status" -eq $EXIT_MONO_SEED_INV_ARG ]
  [[ "$output" == *"--seed '/no/such/file.cypher' not readable"* ]]
}
@test "[offline/seed/mon] EXM mutually exclusive" { #{{{3
  # Important: provide some seed (name ok, file needn't exist due to early exit)
  run_neopop monolithic --fail-fast --best-effort --seed foo.cypher
  [ "$status" -eq $EXIT_EXEC_MX ]
  [[ "$output" == *"mutually exclusive"* ]]
}
@test "[offline/seed/mon] DB prep mutually exclusive" { #{{{3
  run_neopop monolithic --clean-db --reset-db --seed foo.cypher
  [ "$status" -eq $EXIT_DBP_MX ]
  [[ "$output" == *"mutually exclusive"* ]]
}
@test "[offline/seed/mon] invalid parameter" { #{{{3
  run_neopop monolithic --foo bar
  [ "$status" -eq $EXIT_MONO_INV_PAR ]
  [[ "$output" == *"Invalid monolithic parameter"* ]]
}
# db-check {{{2
@test "[offline/db/check] invalid switch" { #{{{3
  run_neopop db-check --foo
  [ "$status" -eq $EXIT_DBCHK_INV_PAR ]
  [[ "$output" == *"db-check allows no parameters"* ]]
}
@test "[offline/db/check] invalid option" { #{{{3
  run_neopop db-check --foo bar
  [ "$status" -eq $EXIT_DBCHK_INV_PAR ]
  [[ "$output" == *"db-check allows no parameters"* ]]
}
@test "[offline/db/check] invalid sub-cmd" { #{{{3
  run_neopop db-check foobar
  [ "$status" -eq $EXIT_DBCHK_INV_PAR ]
  [[ "$output" == *"db-check allows no parameters"* ]]
}
@test "[offline/db/check] connection to fake host fails" { #{{{3
  run_neopop db-check
  [ "$status" -eq $EXIT_DB_CON_FAIL ]
  [[ "$output" == *"Connection failed"* ]]
}
# db-clean {{{2
@test "[offline/db/clean] invalid switch" { #{{{3
  run_neopop db-clean --foo
  [ "$status" -eq $EXIT_DBCLN_INV_PAR ]
  [[ "$output" == *"db-clean allows no parameters"* ]]
}
@test "[offline/db/clean] invalid option" { #{{{3
  run_neopop db-clean --foo bar
  [ "$status" -eq $EXIT_DBCLN_INV_PAR ]
  [[ "$output" == *"db-clean allows no parameters"* ]]
}
@test "[offline/db/clean] invalid sub-cmd" { #{{{3
  run_neopop db-clean foobar
  [ "$status" -eq $EXIT_DBCLN_INV_PAR ]
  [[ "$output" == *"db-clean allows no parameters"* ]]
}
# reset-db {{{2
@test "[offline/db/reset] invalid switch" { #{{{3
  run_neopop db-reset --foo
  [ "$status" -eq $EXIT_DBRST_INV_PAR ]
  [[ "$output" == *"db-reset allows no parameters"* ]]
}
@test "[offline/db/reset] invalid option" { #{{{3
  run_neopop db-reset --foo bar
  [ "$status" -eq $EXIT_DBRST_INV_PAR ]
  [[ "$output" == *"db-reset allows no parameters"* ]]
}
@test "[offline/db/reset] invalid sub-cmd" { #{{{3
  run_neopop db-reset foobar
  [ "$status" -eq $EXIT_DBRST_INV_PAR ]
  [[ "$output" == *"db-reset allows no parameters"* ]]
}

