#!/bin/sh
# entrypoint-debug.sh
# Run Puter in background, capture all output to /tmp/puter.log,
# then expose that log via a tiny HTTP server on $PORT.
# This is a debugging build — once we know what fails, we'll switch
# back to running Puter directly.

set -e

LOG=/tmp/puter.log
PORT="${PORT:-10000}"

echo "=== Puter debug entrypoint ===" > "$LOG"
echo "Time: $(date -Iseconds)" >> "$LOG"
echo "PORT: $PORT" >> "$LOG"
echo "PUTER_CONFIG_PATH: ${PUTER_CONFIG_PATH:-unset}" >> "$LOG"
echo "Node: $(node --version)" >> "$LOG"
echo "" >> "$LOG"

# Start Puter in background; capture stdout+stderr to the log file
( node -r ./dist/src/backend/telemetry.js ./dist/src/backend/index.js ) >> "$LOG" 2>&1 &
PUTER_PID=$!

# Wait up to 60s. If Puter exits before that, capture exit code.
EXIT_CODE=""
for i in $(seq 1 60); do
  if ! kill -0 $PUTER_PID 2>/dev/null; then
    wait $PUTER_PID || EXIT_CODE=$?
    echo "" >> "$LOG"
    echo "=== Puter exited after ${i}s with code: ${EXIT_CODE:-0} ===" >> "$LOG"
    break
  fi
  sleep 1
done

# If still running, mark as healthy
if [ -z "$EXIT_CODE" ] && kill -0 $PUTER_PID 2>/dev/null; then
  echo "" >> "$LOG"
  echo "=== Puter still running (PID $PUTER_PID) ===" >> "$LOG"
fi

# Now serve the log on $PORT using a tiny Node one-liner.
# Container stays alive so Render can fetch the log.
echo "" >> "$LOG"
echo "=== Serving log on port $PORT ===" >> "$LOG"

node -e "
const http = require('http');
const fs = require('fs');
const LOG = process.env.LOG_FILE || '/tmp/puter.log';
const PORT = parseInt(process.env.PORT || '10000', 10);
http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/test') {
    res.writeHead(200, {'Content-Type':'text/plain'});
    res.end('OK');
    return;
  }
  const log = fs.existsSync(LOG) ? fs.readFileSync(LOG, 'utf8') : '(no log)';
  res.writeHead(200, {'Content-Type':'text/plain; charset=utf-8'});
  res.end(log);
}).listen(PORT, '0.0.0.0', () => {
  console.log('Log server listening on ' + PORT);
});
" &
LOG_SERVER_PID=$!

# Keep container alive
wait $LOG_SERVER_PID
