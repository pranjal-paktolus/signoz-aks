const { NodeSDK } = require("@opentelemetry/sdk-node");
const {
  getNodeAutoInstrumentations,
} = require("@opentelemetry/auto-instrumentations-node");

process.env.OTEL_SERVICE_NAME = "node-app";

process.env.OTEL_EXPORTER_OTLP_ENDPOINT =
  "http://signoz-otel-collector.platform:4318";

process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT =
  "http://signoz-otel-collector.platform:4318/v1/traces";

const sdk = new NodeSDK({
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

console.log("Tracing initialized");