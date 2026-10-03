#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
case "${2:-}" in
  a) PORT=8787; FAKE=kids ;;
  b) PORT=8788; FAKE=stress ;;
  me) PORT=8789; FAKE=mine ;;
  *) echo "usage: tools/demo/agent.sh start|stop|cli a|b|me [args]"; exit 1 ;;
esac
export CURFEW_DRY=1 CURFEW_PORT=$PORT CURFEW_STATE="$ROOT/.dry/$2" CURFEW_FAKE="$ROOT/tools/demo/$FAKE.json"
mkdir -p "$ROOT/logs" "$CURFEW_STATE"
PIDS="$CURFEW_STATE/pids"
case "$1" in
  start)
    nohup python3 -u "$ROOT/agents/linux/curfew.py" serve >> "$ROOT/logs/agent-$2.log" 2>&1 &
    echo $! > "$PIDS"
    if command -v dns-sd >/dev/null; then
      ID="$(python3 "$ROOT/agents/linux/curfew.py" id)"
      nohup dns-sd -R "Curfew demo $2" _curfew._tcp local "$PORT" "id=$ID" >/dev/null 2>&1 &
      echo $! >> "$PIDS"
    fi
    echo "demo agent $2 on port $PORT" ;;
  stop)
    [ -f "$PIDS" ] && xargs kill < "$PIDS" 2>/dev/null || true
    rm -f "$PIDS" ;;
  cli) shift 2; python3 "$ROOT/agents/linux/curfew.py" "$@" ;;
  *) echo "usage: tools/demo/agent.sh start|stop|cli a|b|me [args]"; exit 1 ;;
esac
