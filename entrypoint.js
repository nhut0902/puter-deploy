// entrypoint.js — Always-on log+health server that runs Puter in background.
// This guarantees the container stays alive (Render health check passes
// immediately) even if Puter crashes, so we can fetch the log via the
// public URL.

const http = require('http');
const fs = require('fs');
const { spawn } = require('child_process');

const PORT = parseInt(process.env.PORT || '10000', 10);
const LOG = '/tmp/puter.log';
const PUTER_CONFIG_PATH = process.env.PUTER_CONFIG_PATH || '/etc/puter/config.json';

// Pre-create writable data dirs
try { fs.mkdirSync('/tmp/puter', { recursive: true }); } catch (e) {}

// Truncate log
const logStream = fs.createWriteStream(LOG, { flags: 'w' });

function logLine(s) {
  logStream.write(s + '\n');
  console.log(s);
}

logLine('=== Puter entrypoint (Node) ===');
logLine('Time: ' + new Date().toISOString());
logLine('PORT: ' + PORT);
logLine('PUTER_CONFIG_PATH: ' + PUTER_CONFIG_PATH);
logLine('Node: ' + process.version);
logLine('CWD: ' + process.cwd());
logLine('USER/UID: ' + process.getuid());
logLine('');

// Diagnostics
try {
  const stat = fs.statSync('/opt/puter');
  logLine('/opt/puter owner: uid=' + stat.uid + ' gid=' + stat.gid + ' mode=' + stat.mode.toString(8));
} catch (e) {
  logLine('/opt/puter stat error: ' + e.message);
}

try {
  fs.mkdirSync('/opt/puter/volatile/runtime', { recursive: true });
  logLine('Created /opt/puter/volatile/runtime OK');
} catch (e) {
  logLine('mkdir /opt/puter/volatile/runtime FAILED: ' + e.message);
}

try {
  fs.mkdirSync('/tmp/puter', { recursive: true });
  logLine('Created /tmp/puter OK');
} catch (e) {
  logLine('mkdir /tmp/puter FAILED: ' + e.message);
}

logLine('');
logLine('=== Starting Puter ===');

// Start Puter
const puter = spawn('node', [
  '-r', './dist/src/backend/telemetry.js',
  './dist/src/backend/index.js'
], {
  cwd: '/opt/puter',
  stdio: ['ignore', 'pipe', 'pipe'],
  env: process.env,
});

puter.stdout.on('data', d => logStream.write(d));
puter.stderr.on('data', d => logStream.write(d));

puter.on('exit', (code, sig) => {
  logLine('');
  logLine('=== Puter exited code=' + code + ' sig=' + sig + ' ===');
  logLine('=== Container staying alive for log retrieval ===');
});

// HTTP server: always responds with the log (or /health for OK).
const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/test') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK\n');
    return;
  }
  let body = '(no log yet)';
  try { body = fs.readFileSync(LOG, 'utf8'); } catch (e) {}
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(body);
});

server.listen(PORT, '0.0.0.0', () => {
  logLine('Log+health server listening on ' + PORT);
});

// Keep process alive
process.on('SIGTERM', () => { puter.kill('SIGTERM'); process.exit(0); });
