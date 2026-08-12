#!/bin/sh
# entrypoint.sh — run Puter with diagnostics on crash.

set -e

LOG=/tmp/puter.log
PORT="${PORT:-10000}"

# Pre-create writable data dirs (Render may run as non-root UID 1001,
# not the node user the upstream image expects).
mkdir -p /tmp/puter || true

echo "=== Puter entrypoint ===" > "$LOG"
echo "Time: $(date -Iseconds)" >> "$LOG"
echo "User: $(id)" >> "$LOG"
echo "CWD: $(pwd)" >> "$LOG"
echo "PORT: $PORT" >> "$LOG"
echo "" >> "$LOG"
echo "=== /opt/puter ownership ===" >> "$LOG"
ls -la /opt/puter 2>&1 | head -10 >> "$LOG"
echo "" >> "$LOG"
echo "=== /opt/puter/volatile ===" >> "$LOG"
ls -la /opt/puter/volatile 2>&1 | head -10 >> "$LOG"
echo "" >> "$LOG"
echo "=== /tmp/puter ===" >> "$LOG"
ls -la /tmp/puter 2>&1 >> "$LOG"
echo "" >> "$LOG"
echo "=== Starting Puter ===" >> "$LOG"

# Start Puter in background, capture all output to log.
( node -r ./dist/src/backend/telemetry.js ./dist/src/backend/index.js ) >> "$LOG" 2>&1 &
PUTER_PID=$!

# Wait up to 90s for Puter to either crash or stay alive.
for i in $(seq 1 90); do
  if ! kill -0 $PUTER_PID 2>/dev/null; then
    wait $PUTER_PID
    EXIT_CODE=$?
    echo "" >> "$LOG"
    echo "=== Puter exited after ${i}s with code: $EXIT_CODE ===" >> "$LOG"
    # Crash mode: serve the log so it's visible externally.
    exec node -e "
const http=require('http'),fs=require('fs');
const LOG='$LOG',PORT=$PORT;
http.createServer((req,res)=>{
  res.writeHead(200,{'Content-Type':'text/plain;charset=utf-8'});
  res.end(fs.existsSync(LOG)?fs.readFileSync(LOG,'utf8'):'(no log)');
}).listen(PORT,'0.0.0.0');
"
    exit 0
  fi
  sleep 1
done

# Puter is still running — go foreground.
echo "" >> "$LOG"
echo "=== Puter healthy after 90s; going foreground ===" >> "$LOG"
wait $PUTER_PID
