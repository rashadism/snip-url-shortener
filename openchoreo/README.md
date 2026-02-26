# Deploying on OpenChoreo

## Prerequisites

- An OpenChoreo cluster with the control plane and observability plane installed
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

A log-based alert rule on the frontend triggers when `status=500` appears more than 5 times within 1 minute.

### Setup

```bash
# Set up the webhook notification channel and its secret
kubectl apply -f openchoreo/alerting-demo/alert-notification-channels.yaml

# Patch the frontend component to add the log-based alert trait
kubectl patch component frontend --type='json' -p='[
  {"op": "add", "path": "/spec/traits", "value": [
    {
      "name": "observability-alert-rule",
      "instanceName": "frontend-5xx-log-alert",
      "parameters": {
        "description": "Alert when frontend logs indicate HTTP 500 responses",
        "severity": "critical",
        "source": {
          "type": "log",
          "query": "status=500"
        },
        "condition": {
          "window": "1m",
          "interval": "1m",
          "operator": "gt",
          "threshold": 5
        }
      }
    }
  ]}
]'

# Enable the alert, AI RCA, and notification channel
kubectl apply -f openchoreo/alerting-demo/enable-alert.yaml
```

### Trigger the Alert

`failure-scenario.yaml` misconfigures the api-service's `POSTGRES_DSN` to point to a non-existent host. The api-service starts but every DB query fails, returning 500s. The frontend logs `"upstream error"` on each proxied request, breaching the alert threshold. The RCA agent then traces from the frontend alert → api-service 500s → Postgres connection errors → misconfigured DSN.

```bash
# Start generating traffic (creates 3 short URLs, then visits them every 2s)
bash openchoreo/alerting-demo/trigger-alerts.sh

# For a remote cluster, pass the BFF URL as an argument
bash openchoreo/alerting-demo/trigger-alerts.sh http://<your-bff-host>
```

```bash
# Inject the misconfigured Postgres DSN
kubectl apply -f openchoreo/alerting-demo/failure-scenario.yaml
```

After the alert fires, revert:

```bash
kubectl patch releasebinding api-service-development --type=json \
  -p '[{"op":"remove","path":"/spec/workloadOverrides"}]'
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
