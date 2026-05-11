require("./instrumentation");
const express = require('express')
const client = require('prom-client')

const app = express()
const register = new client.Registry()

// Default Node.js + process metrics
client.collectDefaultMetrics({ register })

// Custom HTTP metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
})

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
})

// Middleware: record metrics for every request
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer()
  res.on('finish', () => {
    const labels = {
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode,
    }
    end(labels)
    httpRequestTotal.inc(labels)
  })
  next()
})

// Health / readiness probes
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' })
})

app.get('/ready', (req, res) => {
  // Add downstream dependency checks here (DB, cache, etc.)
  res.status(200).json({ status: 'ready' })
})

// Prometheus metrics scrape endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType)
  res.end(await register.metrics())
})

// Application route
app.get('/', (req, res) => {
  res.json({ message: 'Hello from AKS GitOps' })
})

// Global error handler — must be last app.use()
app.use((err, req, res, next) => {
  console.error(JSON.stringify({
    level: 'error',
    msg: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    time: new Date().toISOString(),
  }))
  res.status(500).json({ error: 'Internal server error' })
})

const PORT = process.env.PORT || 3000
const server = app.listen(PORT, () => {
  console.log(JSON.stringify({
    level: 'info',
    msg: `Server listening on port ${PORT}`,
    time: new Date().toISOString(),
  }))
})

// Graceful shutdown on SIGTERM (Kubernetes rolling deploy)
process.on('SIGTERM', () => {
  console.log(JSON.stringify({ level: 'info', msg: 'SIGTERM received, shutting down gracefully', time: new Date().toISOString() }))
  server.close(() => {
    console.log(JSON.stringify({ level: 'info', msg: 'HTTP server closed', time: new Date().toISOString() }))
    process.exit(0)
  })
  // Force exit if drain takes too long
  setTimeout(() => process.exit(1), 10000)
})

// Catch unhandled errors so the pod doesn't crash silently
process.on('uncaughtException', (err) => {
  console.error(JSON.stringify({ level: 'fatal', msg: 'Uncaught exception', error: err.message, stack: err.stack, time: new Date().toISOString() }))
  process.exit(1)
})

process.on('unhandledRejection', (reason) => {
  console.error(JSON.stringify({ level: 'fatal', msg: 'Unhandled promise rejection', reason: String(reason), time: new Date().toISOString() }))
  process.exit(1)
})
