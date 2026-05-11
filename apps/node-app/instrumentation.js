'use strict'

const { NodeSDK } = require('@opentelemetry/sdk-node')
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node')
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http')
const { resourceFromAttributes } = require('@opentelemetry/resources')
const { ATTR_SERVICE_NAME, ATTR_DEPLOYMENT_ENVIRONMENT } = require('@opentelemetry/semantic-conventions')

const serviceName = process.env.OTEL_SERVICE_NAME || 'node-app'
const environment = process.env.OTEL_DEPLOYMENT_ENVIRONMENT || process.env.NODE_ENV || 'production'
const tracesEndpoint = process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || 'http://127.0.0.1:4318/v1/traces'

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: serviceName,
    [ATTR_DEPLOYMENT_ENVIRONMENT]: environment,
  }),
  traceExporter: new OTLPTraceExporter({
    url: tracesEndpoint,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
})

sdk.start()

const shutdown = async () => {
  try {
    await sdk.shutdown()
  } catch (error) {
    console.error(JSON.stringify({
      level: 'warn',
      msg: 'Failed to shutdown OpenTelemetry SDK cleanly',
      error: error.message,
      time: new Date().toISOString(),
    }))
  }
}

process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)
