// entrypoint.js — Always-on reverse proxy + log server on $PORT (10000).
// Puter runs in background on port 4100 (its default). Render routes
// traffic to port 10000 (this server). This server:
//   - Proxies all HTTP requests to Puter on 4100 when Puter is up
//   - Falls back to serving /tmp/puter.log when Puter is down
//   - Responds to /health and /test for Render's health check

const http = require('http');
const fs = require('fs');
const { spawn } = require('child_process');

const PORT = parseInt(process.env.PORT || '10000', 10);
const PUTER_PORT = 4100;
const LOG = '/tmp/puter.log';
const PUTER_CONFIG_PATH = process.env.PUTER_CONFIG_PATH || '/etc/puter/config.json';

// Pre-create writable data dirs
try { fs.mkdirSync('/tmp/puter', { recursive: true }); } catch (e) {}
try { fs.mkdirSync('/opt/puter/volatile/runtime', { recursive: true }); } catch (e) {}

const logStream = fs.createWriteStream(LOG, { flags: 'w' });
function logLine(s) {
  logStream.write(s + '\n');
  console.log(s);
}

logLine('=== Puter entrypoint (Node proxy) ===');
logLine('Time: ' + new Date().toISOString());
logLine('PORT (Render): ' + PORT);
logLine('PUTER_PORT (internal): ' + PUTER_PORT);
logLine('PUTER_CONFIG_PATH: ' + PUTER_CONFIG_PATH);
logLine('Node: ' + process.version);
logLine('UID: ' + process.getuid());
logLine('');

logLine('=== Starting Puter on port ' + PUTER_PORT + ' ===');

// Start Puter (it reads port from config.json which we set to 4100)
const puter = spawn('node', [
  '-r', './dist/src/backend/telemetry.js',
  './dist/src/backend/index.js'
], {
  cwd: '/opt/puter',
  stdio: ['ignore', 'pipe', 'pipe'],
  env: { ...process.env, PORT: String(PUTER_PORT) },
});

puter.stdout.on('data', d => logStream.write(d));
puter.stderr.on('data', d => logStream.write(d));

let puterAlive = true;
puter.on('exit', (code, sig) => {
  puterAlive = false;
  logLine('');
  logLine('=== Puter exited code=' + code + ' sig=' + sig + ' ===');
  logLine('=== Container staying alive for log retrieval ===');
});

// HTTP server: proxy to Puter, fallback to log.
const server = http.createServer((req, res) => {
  // Health check endpoints — always respond OK so Render health check passes
  if (req.url === '/health' || req.url === '/test') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK\n');
    return;
  }

  // If Puter is alive, proxy the request
  if (puterAlive) {
    const proxyReq = http.request({
      host: '127.0.0.1',
      port: PUTER_PORT,
      method: req.method,
      path: req.url,
      headers: { ...req.headers, host: 'puter.localhost:' + PUTER_PORT },
    }, proxyRes => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });
    proxyReq.on('error', () => {
      // Puter not responding — fall back to log
      serveLog(res);
    });
    req.pipe(proxyReq);
    return;
  }

  // Puter is down — serve the log
  serveLog(res);
});

function serveLog(res) {
  let body = '(no log yet)';
  try { body = fs.readFileSync(LOG, 'utf8'); } catch (e) {}
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(body);
}

server.listen(PORT, '0.0.0.0', () => {
  logLine('Proxy+log server listening on ' + PORT);
});

process.on('SIGTERM', () => { puter.kill('SIGTERM'); process.exit(0); });
