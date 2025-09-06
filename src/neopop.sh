#!/usr/bin/env bash
# neopop © 2025 nemron
set -euo pipefail
> neopop.log

VERSION="0.1"

# Preliminaries {{{1
# Globals {{{2
LIB="neopop"
SYS="$(mktemp --version >/dev/null 2>&1 && echo GNU || echo BSD)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Defaults {{{2
readonly FMT_DFT="plain"
readonly EXM_DFT="ff"      # execution model default: fail-fast
readonly CMT_DFT="stm"     # commit model default: statement-wise
readonly PKG_MIN=2         # minimum package size for pkg-wise

readonly DBCLN_BATCH_DFT=10000
readonly DBRST_TIMEOUT_DFT=30
# Arguments {{{2
# Neo4j
URI=""
USER=""
PASS=""
DBNAME=""

# Neopop
CMD=""  # modular, monolithic, db-check, db-clean, db-reset

# Echo Cypher output (only for stmtx/pkgtx)
ECHO=false

# Payload (neutral — no hard coupling to GSK!)
PL_MIX=""  # Cypher with mixed DDL/DML (path or "-" for STDIN)
PL_PRE=""  # Cypher containing DDL (optional)
PL_GRP=""  # Cypher containing pure DML (path or "-")
PL_PST=""  # Cypher containing DDL (optional)

# Execution Model: "ff" (fail-fast, default) or "bf" (fail-at-end)
EXM=""
EXM_FF_SET=false
EXM_BF_SET=false

# Commit Model: "stm" (statement-wise) or "pkg" (package-wise)
CMT=""
PKG_N=0    # package size (N >= 2 when CMT="pkg")

# DB Preparation
DBP_CLN=false  # clean database before seeding
DBP_RST=false  # reset database before seeding
# Exit Codes {{{2
. "$SCRIPT_DIR/$LIB/ec.sh"
# Usage {{{1
usage() { # {{{2
  cat "$SCRIPT_DIR/$LIB/usg/neopop.txt" \
    || exit $EXIT_INTERNAL_USG_FAIL
  exit ${1:-$EXIT_RTFM}
}
using() { # {{{2
  case "$1" in
    monolithic)
      cat "$SCRIPT_DIR/$LIB/usg/monolithic.txt" \
        || exit $EXIT_INTERNAL_USG_MONO_FAIL
      ;;
    modular)
      cat "$SCRIPT_DIR/$LIB/usg/modular.txt" \
        || exit $EXIT_INTERNAL_USG_MOD_FAIL
      ;;
    db-check)
      cat "$SCRIPT_DIR/$LIB/usg/db-check.txt" \
        || exit $EXIT_INTERNAL_USG_DBCHK_FAIL
      ;;
    db-clean)
      cat "$SCRIPT_DIR/$LIB/usg/db-clean.txt" \
        || exit $EXIT_INTERNAL_USG_DBCLN_FAIL
      ;;
    db-reset)
      cat "$SCRIPT_DIR/$LIB/usg/db-reset.txt" \
        || exit $EXIT_INTERNAL_USG_DBRST_FAIL
      ;;
    *)  # umbrella usage
      cat "$SCRIPT_DIR/$LIB/usg/neopop.txt" \
        || exit $EXIT_INTERNAL_USG_FAIL
      ;;
  esac
  exit $EXIT_SUCCESS
}
# Logging {{{1
log() { # {{{2
  echo "[$(date +'%F %T')] $*" | tee -a neopop.log >&2
}
# Utilities {{{1
cys() { # {{{2
  # Signature: cys <format> <exm> [file]
  #
  # Run cypher-shell with logging.
  #
  # Positional args:
  #   $1: fmt  -> plain | verbose     (default: plain)
  #   $2: exm  -> ff | bf             (default: EXM_DFT)
  #   $3: src  -> readable src path   (optional; else STDIN)
  #
  # Usage:
  #   echo "RETURN 1" | cys plain ff
  #   cys verbose bf my.cypher
  #
  # Returns: cypher-shell exit code; never exits.

  local fmt="${1:-$FMT_DFT}" exm="${2:-$EXM_DFT}" src="${3-}" rc

  case "$fmt" in
    plain|verbose) : ;;
    *) log "❌ cys: invalid format '$fmt'"
       return $EXIT_INTERNAL_API_MISUSE ;;
  esac
  case "$exm" in
    ff|bf) : ;;
    *) log "❌ cys: invalid execution model '$exm'"
       return $EXIT_INTERNAL_API_MISUSE ;;
  esac
  if [[ -n "$src" ]] && ! readable "$src"; then
    log "❌ cys: unreadable '$src'"
    return $EXIT_INTERNAL_API_MISUSE
  fi

  local -a opts=(-u "$USER" -p "$PASS" -a "$URI" -d "$DBNAME"
                 --format "$fmt" --non-interactive)
  if [[ "$exm" == "ff" ]]; then
    opts+=( --fail-fast )
  else
    opts+=( --fail-at-end )
  fi

  set +e
  if [[ -n "$src" ]]; then
    cypher-shell "${opts[@]}" -f "$src" 2>&1 | tee -a neopop.log
    rc=${PIPESTATUS[0]}
  else
    cypher-shell "${opts[@]}" 2>&1 | tee -a neopop.log
    rc=${PIPESTATUS[0]}
  fi
  set -e

  (( rc == 0 )) || { log "❌ cypher-shell failed (rc=$rc)"; }
  return $rc
}
wrp() { # {{{2
  # Emits wrapped content to stdout (single :begin/:commit; DML-only).
  # args:
  #   $1: src -> "-" for STDIN, else readable file path
  #
  # returns: 0 always (no execution here), logs and emits nothing if empty file
  local src="${1:--}"

  if [[ "$src" != "-" ]]; then
    if [[ ! -r "$src" || ! -s "$src" ]] || \
       ! LC_ALL=C grep -q '[^[:space:]]' -- "$src"; then
      log "🪵 Skipping $(basename "$src")"
      return 0
    fi
    printf ':begin\n'; cat -- "$src"; printf '\n:commit\n'
  else
    # stdin mode: do not try to pre-check emptiness, just wrap stream
    printf ':begin\n'; cat; printf '\n:commit\n'
  fi
}
mktmp() { # {{{2
  case $1 in
    -d)
      shift
      [ "$SYS" = GNU ] && mktemp -d "/tmp/$1" || mktemp -d -t "$1"
      ;;
    *)
      [ "$SYS" = GNU ] && mktemp "/tmp/$1" || mktemp -t "$1"
      ;;
  esac
}

rmtmp() { # {{{2
  local d="${CHUNKDIR:-}"
  if [[ -n "$d" && -d "$d" && "$(basename "$d")" == neopop-chunks-* ]]; then
    rm -rf -- "$d"
    log "🧹 Removed chunk dir: $d"
  fi
  CHUNKDIR=""
}
dbprep() { # {{{2
  # Run optional DB preparation before seeding.
  # Uses globals: DBP_CLN, DBP_RST. Returns rc, never exits.
  local rc
  if $DBP_RST; then
    log "🔄 --reset-db requested…"
    if dbrst; then
      log "✅ Database reset completed"
      return 0
    else
      rc=$?
      log "❌ Database reset failed (rc=$rc)"
      return $rc
    fi
  elif $DBP_CLN; then
    log "🧹 --clean-db requested…"
    if dbcln; then
      log "✅ Database cleaning completed"
      return 0
    else
      rc=$?
      log "❌ Database cleaning failed (rc=$rc)"
      return $rc
    fi
  fi
  return 0
}
channel(){ # {{{2
  # Echoes "stdin" for "-", otherwise "file".
  # Does NOT check readability; that is validated separately.
  # Returns 1 if arg is empty.
  local p="$1"

  [[ -z "$p" ]] && return 1
  [[ "$p" == "-" ]] && { printf '%s\n' stdin; return 0; }

  printf '%s\n' file
}
readable(){ # {{{2
  # true iff arg is a readable regular file
  local p="$1"

  [[ -n "$p" && -f "$p" && -r "$p" ]]
}
# Actions {{{1
stmtx() { # {{{2
  # Execute Cypher source statement-wise (implicit tx per statement).
  #
  # args:
  #   $1: exm   -> ff | bf  (required)
  #   $2: src   -> "-" for STDIN, else readable file path (required)
  #
  # returns: cypher-shell exit code (never exits)

  local exm="${1:-}" src="${2-}" rc fmt

  [[ -n "$src" ]] || {
    log "❌ stmtx: missing source"
    return $EXIT_INTERNAL_API_MISUSE
  }

  if $ECHO; then fmt="verbose"; else fmt="plain"; fi

  case "$(channel "$src")" in
    stdin)
      set +e
      cys "$fmt" "$exm" <&0; rc=$?
      set -e
      ;;
    file)
      readable "$src" || {
        log "❌ stmtx: unreadable '$src'"
        return $EXIT_INTERNAL_API_MISUSE
      }
      set +e
      cys "$fmt" "$exm" "$src"; rc=$?
      set -e
      ;;
    *)  log "❌ stmtx: invalid source '$src'"
        return $EXIT_INTERNAL_API_MISUSE
        ;;
  esac

  ((rc==0)) || {
    log "❌ stmtx failed (rc=$rc)"
    return $rc
  }
  return $EXIT_SUCCESS
}
pkgtx() { # {{{2
  # Execute Cypher source package-wise (explicit TX per package).
  #
  # args:
  #   $1: exm    -> ff | bf             (required)
  #   $2: pkg_n  -> integer ≥ PKG_MIN   (required)
  #   $3: src    -> "-" for STDIN, else readable file path (required)
  #
  # returns: cypher-shell exit code semantics
  #   - ff: first non-zero rc
  #   - bf: last non-zero rc (or 0 if all ok)

  local exm="${1:-}" pkg_n="${2:-}" src="${3-}"
  local rc=0 last_rc=0 mode="" tmpdir=""
  local awk_file="$SCRIPT_DIR/$LIB/awk/pkgtx.awk"

  # Validations {{{3
  [[ -n "$exm" && -n "$pkg_n" && -n "$src" ]] || {
    log "❌ pkgtx: missing arguments"
    return $EXIT_INTERNAL_API_MISUSE
  }
  case "$exm" in ff|bf) : ;; *)
    log "❌ pkgtx: invalid execution model '$exm'"
    return $EXIT_INTERNAL_API_MISUSE ;;
  esac
  if ! [[ "$pkg_n" =~ ^[0-9]+$ ]] || (( pkg_n < PKG_MIN )); then
    log "❌ pkgtx: invalid package size '$pkg_n' (min=$PKG_MIN)"
    return $EXIT_INTERNAL_API_MISUSE
  fi
  case "$(channel "$src")" in
    stdin) mode="stdin" ;;
    file)  readable "$src" || {
             log "❌ pkgtx: unreadable source '$src'"
             return $EXIT_INTERNAL_API_MISUSE
           }
           mode="file" ;;
    *)     log "❌ pkgtx: empty source path"
           return $EXIT_INTERNAL_API_MISUSE ;;
  esac
  [[ -r "$awk_file" ]] || {
    log "❌ pkgtx: awk script not found: $awk_file"
    return $EXIT_INTERNAL_API_MISUSE
  }
  # Prepare temp dir {{{3
  tmpdir="$(mktmp -d neopop-chunks-XXXXXX)" || {
    log "❌ pkgtx: failed to create chunk dir"
    return $EXIT_INTERNAL_API_MISUSE
  }
  CHUNKDIR="$tmpdir"  # to support rmtmp helper (cleanup + debug)
  # Chunking {{{3
  # Create chunks {{{4
  local chunk_list
  local -a awk_args=(-v tmpdir="$tmpdir" -v max_stmt="$pkg_n" -f "$awk_file")
  if [[ "$mode" == "stdin" ]]; then
    if ! chunk_list="$(awk "${awk_args[@]}")"; then
      log "❌ pkgtx: chunking failed"
      rmtmp; return $EXIT_INTERNAL_API_MISUSE
    fi
  else
    if ! chunk_list="$(awk "${awk_args[@]}" -- "$src")"; then
      log "❌ pkgtx: chunking failed"
      rmtmp; return $EXIT_INTERNAL_API_MISUSE
    fi
  fi
  # turn into array; ignore empty lines
  local -a chunks=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && chunks+=("$line")
  done <<<"$chunk_list"

  if (( ${#chunks[@]} == 0 )); then
    log "ℹ️  pkgtx: nothing to execute (no statements found)"
    rmtmp
    return $EXIT_SUCCESS
  fi
  # Execute chunks {{{4
  log "  📦 Executing DML in packages of N=$pkg_n (count=${#chunks[@]})…"

  local idx=0
  for chk in "${chunks[@]}"; do
    ((idx++))
    local disp="$(basename "$chk")"
    log "    → pkg #$idx: $disp"

    # wrap the chunk with :begin/:commit and pipe to stmtx via STDIN
    set +e
    wrp "$chk" | stmtx "$exm" "-"
    rc=$?
    set -e

    if (( rc != 0 )); then
      log "    ✖ pkg #$idx failed (rc=$rc)"
      last_rc=$rc
      if [[ "$exm" == "ff" ]]; then
        rmtmp
        return $rc
      fi
    else
      log "    ✓ pkg #$idx ok"
    fi
  done

  rmtmp
  (( last_rc != 0 )) && return $last_rc
  return $EXIT_SUCCESS
}
dbcln() { # {{{2
  # Clean DB: delete data, drop constraints, drop indexes
  local BATCH=${1:-$DBCLN_BATCH_DFT} rc out deleted name

  log "  ➤ Deleting all nodes/relationships (batchSize=$BATCH)" # {{{3
  while :; do
    out="$(printf '%s\n' "
CALL () {
  MATCH (n) WITH n LIMIT $BATCH
  DETACH DELETE n
  RETURN count(*) AS deleted
}
RETURN deleted;" | cys plain ff)"
    rc=$?
    ((rc==0)) || {
      log "❌ Batch delete failed (rc=$rc)"
      return $EXIT_DBCLN_FAIL_DEL_BATCH
    }
    deleted="$(printf '%s' "$out" | tail -n1 | tr -d '\"[:space:]')"
    [[ "$deleted" =~ ^[0-9]+$ ]] || {
      log "❌ Unexpected delete output: '$out'"
      return $EXIT_DBCLN_FAIL_DEL
    }
    if (( deleted == 0 )); then
      #log "    …no more nodes"
      break
    else
      log "    …deleted $deleted node(s) in this batch"
    fi
  done
  # }}}3
  log "  ➤ Dropping constraints" # {{{3
  out="$(printf '%s\n' \
    'SHOW CONSTRAINTS YIELD name RETURN name;' | cys plain ff)"
  rc=$?
  ((rc==0)) || {
    log "❌ Failed to list constraints (rc=$rc)"
    return $EXIT_DBCLN_FAIL_CONST_LST
  }
  rc=0
  while IFS= read -r name; do
    name="${name//\"/}"; name="${name//\`/}"; [[ -z "$name" ]] && continue
    if ! printf 'DROP CONSTRAINT `%s` IF EXISTS;' "$name" | cys plain ff; then
      rc=$?; break
    fi
  done < <(printf '%s\n' "$out" | awk 'NR>1 && NF')
  ((rc==0)) || {
    log "❌ Failed to drop constraints"
    return $EXIT_DBCLN_FAIL_CONST_DRP
  }
  # }}}3
  log "  ➤ Dropping indexes" # {{{3
  out="$(printf '%s\n' \
    'SHOW INDEXES YIELD name RETURN name;' | cys plain ff)"
  rc=$?
  ((rc==0)) || {
    log "❌ Failed to list indexes (rc=$rc)"
    return $EXIT_DBCLN_FAIL_IDX_LST
  }
  rc=0
  while IFS= read -r name; do
    name="${name//\"/}"; name="${name//\`/}"; [[ -z "$name" ]] && continue
    if ! printf 'DROP INDEX `%s` IF EXISTS;' "$name" | cys plain ff; then
      rc=$?; break
    fi
  done < <(printf '%s\n' "$out" | awk 'NR>1 && NF')
  ((rc==0)) || {
    log "❌ Failed to drop indexes"
    return $EXIT_DBCLN_FAIL_IDX_DRP
  }
  # }}}3

  return $EXIT_SUCCESS
}
dbrst() { # {{{2
  # Reset DB: Drops & recreates the target DB via the system DB and polls until
  # online. Intentionally performs a short-lived global DBNAME switch to
  # "system".
  local timeout_s=${1:-$DBRST_TIMEOUT_DFT} interval_s=0.5
  local rc out status start now elapsed
  local target_db="$DBNAME" old_db="$DBNAME"

  log "  ➤ Dropping and recreating database '$target_db'" # {{{3
  DBNAME="system"
  local drop_create_q='DROP DATABASE `%s` IF EXISTS; CREATE DATABASE `%s`;'
  out="$(printf "$drop_create_q" "$target_db" "$target_db" | cys plain ff)"
  rc=$?
  DBNAME="$old_db"
  ((rc==0)) || {
    log "❌ Failed to reset database (rc=$rc)"
    return $EXIT_DBRST_FAIL
  }
  # }}}3
  log "  ➤ Waiting for database to be online (timeout=${timeout_s}s)" # {{{3
  start="$(date +%s)"
  local show_q='SHOW DATABASE `%s` YIELD currentStatus RETURN currentStatus;'
  while :; do
    DBNAME="system"
    out="$(printf "$show_q" "$target_db" | cys plain ff)"
    rc=$?
    DBNAME="$old_db"
    ((rc==0)) || out=""

    status="$(printf '%s\n' "$out" \
      | grep -vE '(^$|currentStatus)' \
      | tail -n1 \
      | tr -d '\"[:space:]')"

    [[ "$status" == "online" ]] && {
      log "ℹ️  Database '$target_db' is back online"
      return $EXIT_SUCCESS
    }

    now="$(date +%s)"; elapsed=$(( now - start ))
    (( elapsed >= timeout_s )) && {
      log "❌ Timeout waiting for database (last='$status')"
      return $EXIT_DBRST_FAIL_TOUT
    }
    sleep "$interval_s"
  done
  # }}}3
}
# Commands {{{1
popmon() { # {{{2
  # Populate monolithic graph seed (always statement-wise).
  # arg1: exm -> ff|bf
  # arg2: cmt -> must be "stm" (validated here)
  # arg3: src -> "-" for STDIN, else readable file path
  local exm="$1" cmt="$2" src="$3" rc

  # Commit model guard: monolithic is always stmt-wise
  if [[ "$cmt" != "stm" ]]; then
    log "❌ popmon: invalid commit model '$cmt' (expected 'stm')"
    return $EXIT_INTERNAL_API_MISUSE
  fi

  if [[ "$src" == "-" ]]; then
    log "🌱 Monolithic seeding (stm-wise) from STDIN…"
  else
    log "🌱 Monolithic seeding (stm-wise) from '$(basename "$src")'…"
  fi

  if stmtx "$exm" "$src"; then
    log "✅ Statement-wise population completed"
    return $EXIT_SUCCESS
  else
    rc=$?
    log "❌ Statement-wise population failed (rc=$rc)"
    return $rc
  fi
}
popmod() { # {{{2
  # Populate modular graph seed.
  # arg1: exm   -> ff|bf
  # arg2: cmt   -> stm|pkg
  # arg3: pre   -> "" or readable file (DDL only)
  # arg4: grp   -> "-" for STDIN, else readable file (pure DML)
  # arg5: pkg_n -> integer ≥2 when cmt=pkg, else ignored
  # arg6: pst   -> "" or readable file (DDL only)
  local exm="$1" cmt="$2" pre="$3" grp="$4" pkg_n="$5" pst="$6"
  local rc

  # 1. Validate commit model {{{3
  case "$cmt" in
    stm|pkg) : ;;
    *) log "❌ popmod: invalid commit model '$cmt' (stm|pkg)"
       return $EXIT_INTERNAL_API_MISUSE ;;
  esac
  # 2. Validate grp source {{{3
  case "$(channel "$grp")" in
    stdin) : ;;
    file)  readable "$grp" || {
             log "❌ popmod: --seed-grp '$grp' not readable"
             return $EXIT_MOD_GRP_INV_ARG
           } ;;
    *)     log "❌ popmod: empty --seed-grp"
           return $EXIT_MOD_GRP_INV_ARG ;;
  esac
  # 3. Validate pre/pst source (if provided) {{{3
  if [[ -n "$pre" ]]; then
    readable "$pre" || {
      log "❌ popmod: --seed-pre '$pre' not readable"
      return $EXIT_MOD_PRE_INV_ARG
    }
  fi
  if [[ -n "$pst" ]]; then
    readable "$pst" || {
      log "❌ popmod: --seed-post '$pst' not readable"
      return $EXIT_MOD_PST_INV_ARG
    }
  fi
  # 4. Validate pkg_n when needed {{{3
  if [[ "$cmt" == "pkg" ]]; then
    if ! [[ "$pkg_n" =~ ^[0-9]+$ ]] || (( pkg_n < PKG_MIN )); then
      log "❌ popmod: --pkg-size must be integer ≥ $PKG_MIN"
      return $EXIT_MOD_PKG_N_INV
    fi
  fi
  # }}}3

  # PRE (DDL) — statement-wise {{{3
  if [[ -n "$pre" ]]; then
    log "🌱 Modular seeding DB pre-processing (stm-wise): '$(basename "$pre")'"
    if ! stmtx "$exm" "$pre"; then
      rc=$?
      log "❌ PRE failed (rc=$rc)"
      return $rc
    fi
  fi
  # GRP (DML) — stm or pkg {{{3
  # stm-wise {{{4
  if [[ "$cmt" == "stm" ]]; then
    if [[ "$grp" == "-" ]]; then
      log "🌱 Modular seeding GRP (stm-wise) from STDIN…"
    else
      log "🌱 Modular seeding GRP (stm-wise): '$(basename "$grp")'"
    fi
    if ! stmtx "$exm" "$grp"; then
      rc=$?
      log "❌ GRP (stm-wise) failed (rc=$rc)"
      return $rc
    fi
  # pkg-wise {{{4
  else
    if [[ "$grp" == "-" ]]; then
      log "🌱 Modular seeding GRP (pkg-wise, N=$pkg_n) from STDIN…"
    else
      log "🌱 Modular seeding GRP (pkg-wise, N=$pkg_n): '$(basename "$grp")'"
    fi
    if ! pkgtx "$exm" "$pkg_n" "$grp"; then
      rc=$?
      log "❌ GRP (pkg-wise) failed (rc=$rc)"
      return $rc
    fi
  fi
  # PST (DDL) — statement-wise {{{3
  if [[ -n "$pst" ]]; then
    log "🌱 Modular seeding DB post-processing (stm-wise): '$(basename "$pst")'"
    if ! stmtx "$exm" "$pst"; then
      rc=$?
      log "❌ PST failed (rc=$rc)"
      return $rc
    fi
  fi
  # }}}3

  log "✅ Modular population completed"
  return $EXIT_SUCCESS
}
db_check() { # {{{2
  # Currently, only the ability to establish a connection to the DB is being
  # checked. In other words, `check-db` is currently more like `ping-db`.
  log "🔌 Test connection to database '$DBNAME'…"
  local rc
  if printf '%s\n' "RETURN 1" | cys plain ff >/dev/null; then
    log "✅ Connection OK"; exit $EXIT_SUCCESS
  else
    rc=$?
    log "❌ Connection failed (rc=$rc)"
    exit $EXIT_DB_CON_FAIL
  fi
}
db_clean() { # {{{2
  log "🧹 Cleaning database '$DBNAME'…"
  local rc
  if dbcln; then
    log "✅ Database cleaning completed"
    exit $EXIT_SUCCESS
  else
    rc=$?
    log "❌ Database cleaning failed (rc=$rc)"
    exit $rc
  fi
}
db_reset() { # {{{2
  log "🔄 Resetting database '$DBNAME'…"
  local rc
  if dbrst; then
    log "✅ Database reset completed"
    exit $EXIT_SUCCESS
  else
    rc=$?
    log "❌ Database reset failed (rc=$rc)"
    exit $rc
  fi
}
# Parsing {{{1
# Phase 1: global params (options & switches) {{{2
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--address) # {{{3
      if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        log "❌ Missing argument for -a"
        exit $EXIT_GLB_ROPT_A_MIS_ARG
      fi
      URI="$2"; shift 2
      ;;
    -u|--user) # {{{3
      if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        log "❌ Missing argument for -u"
        exit $EXIT_GLB_ROPT_U_MIS_ARG
      fi
      USER="$2"; shift 2
      ;;
    -p|--password) # {{{3
      if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        log "❌ Missing argument for -p"
        exit $EXIT_GLB_ROPT_P_MIS_ARG
      fi
      PASS="$2"; shift 2
      ;;
    -d|--database) # {{{3
      if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        log "❌ Missing argument for -d"
        exit $EXIT_GLB_ROPT_D_MIS_ARG
      fi
      DBNAME="$2"; shift 2
      ;;
    monolithic|modular|db-check|db-clean|db-reset) # {{{3
      CMD="$1"; shift; break
      ;;
    -h|--help) # {{{3
      usage $EXIT_SUCCESS
      ;;
    --version) # {{{3
      if [[ $# -gt 1 ]]; then
        log "❌ --version cannot be combined with other parameters"
        exit $EXIT_RTFM
      fi
      echo "🪢 neopop v$VERSION, © 2025 nemron"
      exit $EXIT_SUCCESS
      ;;
    -*) # {{{3
      log "❌ Invalid global parameter: $1"
      log "👉 Run 'neopop --help' for usage."
      exit $EXIT_GLB_INV_PAR
      ;;
    *) # {{{3
      log "❌ Invalid command: $1"
      log "👉 Run 'neopop --help' for usage."
      exit $EXIT_GLB_INV_CMD
      ;;
  esac
done
# Ensure requirements are met! {{{2
if [[ -z "$USER" || -z "$PASS" || -z "$URI" || -z "$DBNAME" ]]; then
  log "❌ Missing required global options (-u/-p/-a/-d)!"
  log "👉 Run 'neopop --help' for usage."
  exit $EXIT_GLB_MIS_ROPT
fi
# Phase 2: command-specific parameters {{{2
case "$CMD" in
  monolithic) # {{{3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --echo-cys) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --echo-cys takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          ECHO=true; shift
          ;;
        --fail-fast) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --fail-fast takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          EXM="ff"; EXM_FF_SET=true; shift
          ;;
        --best-effort) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --best-effort takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          EXM="bf"; EXM_BF_SET=true; shift
          ;;
        --clean-db) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --clean-db takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          DBP_CLN=true; shift
          ;;
        --reset-db) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --reset-db takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          DBP_RST=true; shift
          ;;
        --stm-wise) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --stm-wise takes no value"
            exit $EXIT_MONO_INV_PAR
          }
          CMT="stm"; shift
          ;;
        --seed) # {{{4
          if [[ $# -lt 2 ]]; then
            log "❌ Missing argument for --seed"
            exit $EXIT_MONO_SEED_REQ
          fi
          PL_MIX="$2"; shift 2
          ;;
        -h|--help) # {{{4
          using monolithic
          ;;
        *) # {{{4
          log "❌ Invalid monolithic parameter: $1"
          log "👉 Run 'neopop monolithic --help' for usage."
          exit $EXIT_MONO_INV_PAR
          ;;
      esac
    done
    # Validations {{{4
    if $EXM_FF_SET && $EXM_BF_SET; then
      log "❌ --fail-fast and --best-effort are mutually exclusive"
      exit $EXIT_EXEC_MX
    fi
    if $DBP_CLN && $DBP_RST; then
      log "❌ --clean-db and --reset-db are mutually exclusive"
      exit $EXIT_DBP_MX
    fi
    if [[ -z "$PL_MIX" ]]; then
      log "❌ --seed is required"
      exit $EXIT_MONO_SEED_REQ
    fi
    case "$(channel "$PL_MIX")" in
      stdin) : ;;
      file)  readable "$PL_MIX" || {
               log "❌ --seed '$PL_MIX' not readable"
               exit $EXIT_MONO_SEED_INV_ARG
             }
             ;;
      *)     log "❌ --seed: empty path"
             exit $EXIT_MONO_SEED_INV_ARG
             ;;
    esac
    # }}}4
    ;;
  modular) # {{{3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --echo-cys) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --echo-cys takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          ECHO=true; shift
          ;;
        --fail-fast) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --fail-fast takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          EXM="ff"; EXM_FF_SET=true; shift
          ;;
        --best-effort) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --best-effort takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          EXM="bf"; EXM_BF_SET=true; shift
          ;;
        --clean-db) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --clean-db takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          DBP_CLN=true; shift
          ;;
        --reset-db) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --reset-db takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          DBP_RST=true; shift
          ;;
        --stm-wise) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --stm-wise takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          CMT="stm"; shift
          ;;
        --pkg-wise) # {{{4
          [[ -n "${2-}" && "${2:0:1}" != "-" ]] && {
            log "❌ --pkg-wise takes no value"
            exit $EXIT_MOD_INV_PAR
          }
          CMT="pkg"; shift
          ;;
        --pkg-size) # {{{4
          if [[ $# -lt 2 || "$2" =~ ^- ]]; then
            log "❌ Missing argument for --pkg-size"
            exit $EXIT_MOD_PKG_N_REQ
          fi
          if ! [[ "$2" =~ ^[0-9]+$ ]] || (( $2 < PKG_MIN )); then
            log "❌ --pkg-size expects integer ≥ $PKG_MIN"
            exit $EXIT_MOD_PKG_N_INV
          fi
          PKG_N="$2"; shift 2
          ;;
        --seed-grp) # {{{4
          if [[ $# -lt 2 ]]; then
            log "❌ Missing argument for --seed-grp"
            exit $EXIT_MOD_GRP_REQ
          fi
          PL_GRP="$2"; shift 2
          ;;
        --seed-pre) # {{{4
          if [[ $# -lt 2 || "$2" == "-" ]]; then
            log "❌ --seed-pre expects readable file (no '-')"
            exit $EXIT_MOD_PRE_INV_ARG
          fi
          PL_PRE="$2"; shift 2
          ;;
        --seed-post) # {{{4
          if [[ $# -lt 2 || "$2" == "-" ]]; then
            log "❌ --seed-post expects readable file (no '-')"
            exit $EXIT_MOD_PST_INV_ARG
          fi
          PL_PST="$2"; shift 2
          ;;
        -h|--help) # {{{4
          using modular
          ;;
        *) # {{{4
          log "❌ Invalid modular parameter: $1"
          log "👉 Run 'neopop modular --help' for usage."
          exit $EXIT_MOD_INV_PAR
          ;;
      esac
    done
    # Validations {{{4
    if $EXM_FF_SET && $EXM_BF_SET; then
      log "❌ --fail-fast and --best-effort are mutually exclusive"
      exit $EXIT_EXEC_MX
    fi
    if $DBP_CLN && $DBP_RST; then
      log "❌ --clean-db and --reset-db are mutually exclusive"
      exit $EXIT_DBP_MX
    fi
    if [[ -z "$PL_GRP" ]]; then
      log "❌ --seed-grp is required"
      exit $EXIT_MOD_GRP_REQ
    fi
    case "$(channel "$PL_GRP")" in
      stdin) : ;;
      file)  readable "$PL_GRP" || {
               log "❌ --seed-grp '$PL_GRP' not readable"
               exit $EXIT_MOD_GRP_INV_ARG
             }
             ;;
      *)     log "❌ --seed-grp: empty path"
             exit $EXIT_MOD_GRP_INV_ARG
             ;;
    esac
    if [[ -n "$PL_PRE" ]]; then
      readable "$PL_PRE" || {
        log "❌ --seed-pre '$PL_PRE' not readable"
        exit $EXIT_MOD_PRE_INV_ARG
      }
    fi
    if [[ -n "$PL_PST" ]]; then
      readable "$PL_PST" || {
        log "❌ --seed-post '$PL_PST' not readable"
        exit $EXIT_MOD_PST_INV_ARG
      }
    fi
    if [[ "$CMT" == "pkg" ]]; then
      if (( PKG_N == 0 )); then
        log "❌ --pkg-wise requires --pkg-size"
        exit $EXIT_MOD_PKG_N_REQ
      fi
    else
      if (( PKG_N > 0 )); then
        log "❌ --pkg-size only valid with --pkg-wise"
        exit $EXIT_MOD_INV_PAR
      fi
    fi
    # }}}4
    ;;
  db-check) # {{{3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help) using db-check ;;
        *)
          log "❌ db-check allows no parameters"
          log "👉 Run 'neopop db-check --help' for usage."
          exit $EXIT_DBCHK_INV_PAR
          ;;
      esac
    done
    ;;
  db-clean) # {{{3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help) using db-clean ;;
        *)
          log "❌ db-clean allows no parameters"
          log "👉 Run 'neopop db-clean --help' for usage."
          exit $EXIT_DBCLN_INV_PAR
          ;;
      esac
    done
    ;;
  db-reset) # {{{3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help) using db-reset ;;
        *)
          log "❌ db-reset allows no parameters"
          log "👉 Run 'neopop db-reset --help' for usage."
          exit $EXIT_DBRST_INV_PAR
          ;;
      esac
    done
    ;;
  *) # {{{3
    log "❌ Missing command"
    log "👉 Run 'neopop --help' for usage."
    exit $EXIT_GLB_MIS_CMD
    ;;
esac
# Dispatch {{{1
# Defaults normalization {{{2
EXM="${EXM:-$EXM_DFT}"
CMT="${CMT:-$CMT_DFT}"
# Call-up dedicated functions {{{2
case "$CMD" in
  # populate modular graph seed via commit model $CMT
  modular)
    if ! dbprep; then exit $?; fi
    SEED=("$PL_PRE" "$PL_GRP" "$PKG_N" "$PL_PST")
    popmod "$EXM" "$CMT" "${SEED[@]}"
    ;;
  # populate monolithic graph seed via commit model $CMT (fixed to "stm")
  monolithic)
    if ! dbprep; then exit $?; fi
    popmon "$EXM" "$CMT" "$PL_MIX"
    ;;
  db-check)   db_check ;;
  db-clean)   db_clean ;;
  db-reset)   db_reset ;;
esac

