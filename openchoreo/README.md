# Deploying on OpenChoreo

## Prerequisites

- An OpenChoreo cluster with the control plane and build plane installed
- `kubectl` access to the cluster

## Deploy

Deploys five components (postgres, redis, api-service, analytics-service, frontend) using pre-built images:

```bash
kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/from-image/
```

Alternatively, you can build from source:

```bash
kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/from-source/
```

## Alerting Demo

Two alert rules have been added to demonstrate OpenChoreo's observability alerting:

1. **Log-based alert** on the frontend — triggers when `status=500` appears more than 5 times within 1 minute
2. **Metric-based alert** on the api-service — triggers when `memory_usage` exceeds 35% of its limit

### Setup

```bash
# Set up the webhook notification channel and its secret
kubectl apply -f openchoreo/alerting-demo/alert-notification-channels.yaml

# Update the frontend component to have the log-based alert trait
kubectl apply -f openchoreo/alerting-demo/frontend-component.yaml

# Update the api-service component to have the metric-based memory alert trait
kubectl apply -f openchoreo/alerting-demo/api-service-component.yaml

# Enable the frontend log alert, AI RCA, and notification channel
kubectl apply -f openchoreo/alerting-demo/enable-alert.yaml
```

### Failure Scenarios

There are two failure scenarios, applied separately:

**1. Log-based alert (misconfigured Postgres DSN)**

The `failure-scenario-setup.yaml` misconfigures the api-service's `POSTGRES_DSN` to point to a non-existent host. The api-service starts but every DB query fails, returning 500s. The frontend logs `"upstream error"` on each proxied request, breaching the alert threshold. The RCA agent then traces from the frontend alert → api-service 500s → Postgres connection errors → misconfigured DSN.

```bash
# Start generating traffic (creates 3 short URLs, then visits them every 2s)
chmod +x openchoreo/alerting-demo/trigger-alerts.sh
bash openchoreo/alerting-demo/trigger-alerts.sh

# For a remote cluster, pass the BFF URL as an argument
bash openchoreo/alerting-demo/trigger-alerts.sh http://<your-bff-host>
```

Confirm load is being generated at http://frontend-development-default.openchoreoapis.localhost:19080/

```bash
# Apply the failure scenario (misconfigures Postgres DSN + lowers api-service memory to 55Mi)
kubectl apply -f openchoreo/alerting-demo/failure-scenario-setup.yaml
```

**2. Metric-based alert (high memory under load)**

The same `failure-scenario-setup.yaml` also lowers the api-service memory limit to 55Mi. Under idle load the service uses ~7 MB (~13%), but under heavy traffic it climbs to ~40 MB (~72%), well above the 35% threshold. Use `generate-load.sh` to drive the traffic:

```bash
chmod +x openchoreo/alerting-demo/generate-load.sh
bash openchoreo/alerting-demo/generate-load.sh

# For a remote cluster, pass the BFF URL after the concurrency and flags
bash openchoreo/alerting-demo/generate-load.sh 50 http://<your-bff-host>
```

## Cleanup

Deleting the project removes all its components:

```bash
kubectl delete -f openchoreo/project.yaml
```

## How it works

Source-based components (postgres, api-service, analytics-service, frontend) use the `docker` workflow to build from `github.com/rashadism/snip-url-shortener`. Each service has a `workload.yaml` descriptor that defines its endpoints and environment variables — no env vars are baked into Dockerfiles.

Inter-service communication uses OpenChoreo service discovery (`<component-name>:80`). The frontend proxies all API requests to backend services, so the browser only makes relative requests.

## Build & Push Images

To build and push the images to your own registry:

```bash
# Set your DockerHub username or registry, then log in
echo "your-username" > REGISTRY
docker login

# Build, push, bump patch version, and update manifests
make build
```
