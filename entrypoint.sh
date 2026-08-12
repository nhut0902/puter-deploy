#!/bin/sh
# entrypoint.sh — run Puter directly.
# Falls back to serving the startup log on $PORT if Puter crashes,
# so we can debug via the public URL without dashboard access.

set -e

LOG=/tmp/puter.log
PORT="${PORT:-10000}"

# Start Puter in background, capture all output.
( node -r ./dist/src/backend/telemetry.js ./dist/src/backend/index.js ) > "$LOG" 2>&1 &
PUTER_PID=$!

# Wait up to 90s for Puter to either crash or stay alive.
for i in $(seq 1 90); do
  if ! kill -0 $PUTER_PID 2>/dev/null; then
    wait $PUTER_PID
    EXIT_CODE=$?
    echo "" >> "$LOG"
    echo "=== Puter exited after ${i}s with code: $EXIT_CODE ===" >> "$LOG"
    echo "=== Serving log on port $PORT ===" >> "$LOG"
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

# Puter is still running — but we need to also serve the log on a side port.
# Trick: puter listens on $PORT already. We can't serve the log too.
# Just exec into the Puter process (foreground).
echo "" >> "$LOG"
echo "=== Puter healthy after 90s; going foreground ===" >> "$LOG"
wait $PUTER_PID
