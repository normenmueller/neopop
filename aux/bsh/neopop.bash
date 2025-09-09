# neopop bash-completion
# Save as: /etc/bash_completion.d/neopop  or  ~/.local/share/bash-completion/neopop

_neopop() {
  local cur prev words cword
  COMPREPLY=()
  if type _init_completion &>/dev/null; then
    _init_completion -n : || return
  else
    words=("${COMP_WORDS[@]}"); cword=$COMP_CWORD
    cur="${COMP_WORDS[COMP_CWORD]}"; prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  # helpers
  _has_word() { local w; for w in "${words[@]}"; do [[ "$w" == "$1" ]] && return 0; done; return 1; }
  _file_complete() {
    if type _filedir &>/dev/null; then
      # prefer common Cypher extensions; fallback to any file
      _filedir || COMPREPLY+=( $(compgen -f -- "$cur") )
    else
      COMPREPLY+=( $(compgen -f -- "$cur") )
    fi
  }

  # detect subcommand (after global options and their args)
  local subcmd=""
  for ((i=1;i<${#words[@]};i++)); do
    case "${words[i]}" in
      -u|--user|-p|--password|-a|--address|-d|--database) ((i++));;
      --help|--version|--echo-cys) : ;;
      monolithic|modular|db-check|db-clean|db-reset) subcmd="${words[i]}"; break;;
    esac
  done

  # value positions
  case "$prev" in
    -u|--user|-p|--password|-d|--database|--pkg-size) return 0;;
    -a|--address)
      COMPREPLY=( $(compgen -W "neo4j:// bolt:// neo4j+s:// neo4j+ssc://" -- "$cur") )
      return 0
      ;;
    --seed|--seed-pre|--seed-grp|--seed-post)
      _file_complete
      return 0
      ;;
  esac

  local gopts="-u --user -p --password -a --address -d --database --echo-cys --help --version"

  # before subcommand -> offer subcommands + global opts
  if [[ -z "$subcmd" ]]; then
    COMPREPLY=( $(compgen -W "monolithic modular db-check db-clean db-reset $gopts" -- "$cur") )
    return 0
  fi

  # mutually exclusive guards
  local have_fail_fast=$(_has_word --fail-fast && echo 1 || echo 0)
  local have_best_effort=$(_has_word --best-effort && echo 1 || echo 0)
  local have_clean=$(_has_word --clean-db && echo 1 || echo 0)
  local have_reset=$(_has_word --reset-db && echo 1 || echo 0)

  case "$subcmd" in
    db-check|db-clean|db-reset)
      COMPREPLY=( $(compgen -W "$gopts" -- "$cur") )
      return 0
      ;;
    monolithic)
      # base switches
      local base="--seed --stm-wise --echo-cys"
      # execution control (mutually exclusive)
      if [[ $have_best_effort -eq 0 ]]; then base+=" --fail-fast"; fi
      if [[ $have_fail_fast  -eq 0 ]]; then base+=" --best-effort"; fi
      # db prep (mutually exclusive)
      if [[ $have_reset -eq 0 ]]; then base+=" --clean-db"; fi
      if [[ $have_clean -eq 0 ]]; then base+=" --reset-db"; fi
      COMPREPLY=( $(compgen -W "$gopts $base" -- "$cur") )
      return 0
      ;;
    modular)
      local base="--seed-pre --seed-grp --seed-post --stm-wise --pkg-wise --pkg-size --echo-cys"
      # execution control
      if [[ $have_best_effort -eq 0 ]]; then base+=" --fail-fast"; fi
      if [[ $have_fail_fast  -eq 0 ]]; then base+=" --best-effort"; fi
      # db prep
      if [[ $have_reset -eq 0 ]]; then base+=" --clean-db"; fi
      if [[ $have_clean -eq 0 ]]; then base+=" --reset-db"; fi
      COMPREPLY=( $(compgen -W "$gopts $base" -- "$cur") )
      return 0
      ;;
  esac
}

# Register for the command name you use to invoke the tool
complete -F _neopop neopop
# If your script is named differently (e.g., neopop.sh), also enable:
# complete -F _neopop neopop.sh

