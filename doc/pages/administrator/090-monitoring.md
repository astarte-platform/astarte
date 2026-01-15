# Monitoring

Astarte is a complex, distributed system that may pose several challenges when deployed in production. Individual services report health and metrics to ensure production clusters can be properly monitored and proactive actions can be taken in case of faults or unexpected behavior.

## Health checks

Every Astarte service, whether it's an API service or not, exposes an HTTP endpoint `/health`, without versioning, on its HTTP port. By default, services use port `4000`.
`/health` is meant to be called frequently and reports the individual health state of a service. It will return `200` in case the service is healthy, or other errors in case the service is having issues. Among those issues, there might be failure in accessing RabbitMQ/RPC communications or failure in accessing the Database.

### Health checks and Kubernetes

The aforementioned health checks are integrated in Kubernetes, when using Astarte Operator, as `LivenessProbe` and `ReadinessProbe`. As such, health monitoring and forced restarts are automatically handled without the need for the administrator to integrate any additional logic.

## Service metrics

Just like `/health`, every service exposes a `/metrics` endpoint. This endpoint exposes a series of metrics in [Prometheus](https://prometheus.io/) format, which can be easily integrated and queried from any Prometheus-compatible monitoring solution. Each service, besides exposing stats on its Erlang VM, resource consumption and HTTP stats (where applicable), also exposes a number of service-specific metric, which can be queried to obtain information about Astarte's usage and behavior.

### Authentication and access to metrics

`/metrics`, being Prometheus-compatible, does not implement any kind of authentication or access control. Ideally, only your scraper should have access to `/metrics`, as it can leak sensitive information and should not be exposed to the outer world.

Astarte Operator, by default, forbids access to `/metrics` through its ingress, as it assumes your scraper lives within the Kubernetes cluster or has means to access the cluster on its own. However, this behavior can be overridden through by setting `serveMetrics: true` in the `api` section. An additional parameter, `serveMetricsToSubnet`, can be specified to restrict access to `/metrics` only to source IPs in a specific subnet. It is strongly recommended to set this up in case an external scraper needs to have access to `/metrics`, to ensure access is restricted.
