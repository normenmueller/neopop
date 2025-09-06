#!/usr/bin/env bash
# neopop © 2025 nemron
set -euo pipefail

# Generic
readonly EXIT_RTFM=1
readonly EXIT_SUCCESS=0

# Globals parsing
readonly EXIT_GLB_MIS_ROPT=2
readonly EXIT_GLB_ROPT_A_MIS_ARG=3
readonly EXIT_GLB_ROPT_U_MIS_ARG=4
readonly EXIT_GLB_ROPT_P_MIS_ARG=5
readonly EXIT_GLB_ROPT_D_MIS_ARG=6

readonly EXIT_GLB_INV_PAR=7
readonly EXIT_GLB_MIS_CMD=8
readonly EXIT_GLB_INV_CMD=9

# Cmd/GSK: Monolithic
readonly EXIT_MONO_INV_PAR=10
readonly EXIT_MONO_SEED_REQ=11
readonly EXIT_MONO_SEED_INV_ARG=12

# Cmd/GSK: Modular
readonly EXIT_MOD_INV_PAR=13
readonly EXIT_MOD_GRP_REQ=14
readonly EXIT_MOD_GRP_INV_ARG=15
readonly EXIT_MOD_PRE_INV_ARG=16
readonly EXIT_MOD_PST_INV_ARG=17
readonly EXIT_MOD_PKG_N_REQ=18
readonly EXIT_MOD_PKG_N_INV=19

# Mut-ex sets
readonly EXIT_EXEC_MX=20       # fail-fast vs best-effort
readonly EXIT_DBP_MX=21        # clean-db vs reset-db

# DB command param errors
readonly EXIT_DBCHK_INV_PAR=22
readonly EXIT_DBCLN_INV_PAR=23
readonly EXIT_DBRST_INV_PAR=24

# Operational failures
readonly EXIT_DB_CON_FAIL=25

readonly EXIT_DBCLN_FAIL_DEL_BATCH=26
readonly EXIT_DBCLN_FAIL_DEL=27
readonly EXIT_DBCLN_FAIL_CONST_LST=28
readonly EXIT_DBCLN_FAIL_CONST_DRP=29
readonly EXIT_DBCLN_FAIL_IDX_LST=30
readonly EXIT_DBCLN_FAIL_IDX_DRP=31

readonly EXIT_DBRST_FAIL=32
readonly EXIT_DBRST_FAIL_TOUT=33

readonly EXIT_SEED_STM_FAIL=34

# Internal
readonly EXIT_INTERNAL_USG_FAIL=35
readonly EXIT_INTERNAL_API_MISUSE=36
readonly EXIT_INTERNAL_USG_MONO_FAIL=37
readonly EXIT_INTERNAL_USG_MOD_FAIL=38
readonly EXIT_INTERNAL_USG_DBCHK_FAIL=39
readonly EXIT_INTERNAL_USG_DBCLN_FAIL=40
readonly EXIT_INTERNAL_USG_DBRST_FAIL=41

