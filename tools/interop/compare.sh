#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SWIFT_BIN="${1:-$ROOT/agents/macos/.build/release/curfew}"
TMP="$(mktemp -d)"
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null; wait 2>/dev/null; rm -rf "$TMP"' EXIT

run_agent() {
  local name=$1 port=$2; shift 2
  mkdir -p "$TMP/$name"
  export CURFEW_DRY=1 CURFEW_PORT=$port CURFEW_STATE="$TMP/$name" CURFEW_FAKE="$ROOT/tools/demo/kids.json"
  "$@" serve $([ "$name" = swift ] && echo --bind 127.0.0.1) > "$TMP/$name.log" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 50); do nc -z 127.0.0.1 "$port" 2>/dev/null && break; sleep 0.1; done
  "$@" pair > "$TMP/$name.pair" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 50); do grep -q "Code:" "$TMP/$name.pair" && break; sleep 0.1; done
  local code
  code=$(sed -n 's/.*Code: *//p' "$TMP/$name.pair")
  python3 "$ROOT/tools/interop/client.py" "127.0.0.1:$port" "$code" > "$TMP/$name.out" 2>&1
  echo "== $name (exit $?)"
  cat "$TMP/$name.out"
  sleep 1.2
  echo "-- $name pair command:"; tail -1 "$TMP/$name.pair"
  echo "-- $name agent log:"; cat "$TMP/$name.log"
}

run_agent python 18801 python3 -u "$ROOT/tools/interop/python_agent.py"
run_agent swift 18802 "$SWIFT_BIN"
echo "== diff python swift"
diff "$TMP/python.out" "$TMP/swift.out" && echo "identical"
