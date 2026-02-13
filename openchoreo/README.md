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

Alternatively, you can [build from source](from-source/README.md).

## Alerting

Log-based alert setup for the api-service component.

- `alerting-demo/alert-notification-channels.yaml` — Dummy webhook notification channel and secret
- `alerting-demo/frontend-component.yaml` — Frontend component with a log-based alert trait
- `alerting-demo/enable-alert.yaml` — ReleaseBinding that enables the alert, AI RCA, and notification channel
- `alerting-demo/failure-scenario-setup.yaml` — ReleaseBinding that misconfigures the api-service Postgres DSN
- `alerting-demo/trigger-alerts.sh` — Script that creates short URLs and simulates visits every 2s

### Failure Scenario

The `failure-scenario-setup.yaml` misconfigures the api-service's `POSTGRES_DSN` to point to a non-existent host. The api-service starts but every DB query fails, returning 500s. The frontend logs `"upstream error"` on each proxied request, breaching the alert threshold. The RCA agent then traces from the frontend alert → api-service 500s → Postgres connection errors → misconfigured DSN.

### Apply

```bash
# Set up the webhook notification channel and its secret
kubectl apply -f openchoreo/alerting-demo/alert-notification-channels.yaml

# Deploy the frontend component with the log-based alert trait
kubectl apply -f openchoreo/alerting-demo/frontend-component.yaml

# Enable the alert, AI RCA, and notification channel
kubectl apply -f openchoreo/alerting-demo/enable-alert.yaml

# Start generating traffic (creates 3 short URLs, then visits them every 2s)
chmod +x openchoreo/alerting-demo/trigger-alerts.sh
bash openchoreo/alerting-demo/trigger-alerts.sh
```

Confirm load is being generated at http://default.frontend-development.openchoreoapis.localhost:19080/

Apply the failure scenario (misconfigures Postgres DSN):

```bash
kubectl apply -f openchoreo/alerting-demo/failure-scenario-setup.yaml
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
