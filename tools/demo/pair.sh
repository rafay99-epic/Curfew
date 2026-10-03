#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$ROOT/logs"
CURFEW_DRY=1 CURFEW_PORT=$2 CURFEW_STATE="$ROOT/.dry/$1" nohup python3 -u "$ROOT/agents/linux/curfew.py" pair > "$ROOT/logs/pair-$1.log" 2>&1 &
sleep 1.5
grep -E "Address|Code" "$ROOT/logs/pair-$1.log"
