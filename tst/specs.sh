#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bats --timing "$DIR/spec/offline.bats"
bats --timing "$DIR/spec/online.bats"

