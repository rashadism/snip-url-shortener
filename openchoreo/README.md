# Deploying on OpenChoreo

## Prerequisites

- An OpenChoreo cluster with the control plane and build plane installed
- `kubectl` access to the cluster

## Deploy

Deploys five components (postgres, redis, api-service, analytics-service, frontend) using pre-built images:

```bash
# Create the cache component type (Recreate strategy for Redis)
kubectl apply -f openchoreo/cache-component-type.yaml

kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/from-image/
```

Alternatively, you can [build from source](from-source/README.md).

## Alerting

Log-based alert setup for the api-service component.

- `alerting-demo/alert-notification-channels.yaml` — Dummy webhook notification channel and secret
- `alerting-demo/api-service-component.yaml` — api-service component with a log-based alert trait
- `alerting-demo/failure-scenario-setup.yaml` — ReleaseBinding that enables the alert, AI RCA, and notification channel
- `alerting-demo/trigger-alerts.sh` — Script that creates short URLs and simulates visits every 2s

### Failure Scenario

Traffic flows through the api-service while Redis is healthy. Deleting the Redis component (`kubectl delete component redis`) causes all subsequent cache lookups to timeout. The api-service logs `"failed to get URL from redis"` on every request, breaching the alert threshold and sending a notification to the webhook channel.

### Apply

```bash
# Set up the webhook notification channel and its secret
kubectl apply -f openchoreo/alerting-demo/alert-notification-channels.yaml

# Deploy the api-service component with the log-based alert trait
kubectl apply -f openchoreo/alerting-demo/api-service-component.yaml

# Enable the alert, AI RCA, and notification channel
kubectl apply -f openchoreo/alerting-demo/failure-scenario-setup.yaml

# Start generating traffic (creates 3 short URLs, then visits them every 2s)
chmod +x openchoreo/alerting-demo/trigger-alerts.sh
bash openchoreo/alerting-demo/trigger-alerts.sh & sleep 1

```

Confirm load is being generated at http://default.frontend-development.openchoreoapis.localhost:19080/

Delete Redis to trigger the failure:

```bash
kubectl delete component redis
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
