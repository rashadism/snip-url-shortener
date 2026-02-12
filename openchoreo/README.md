# Deploying on OpenChoreo

## Prerequisites

- An OpenChoreo cluster with the control plane and build plane installed
- `kubectl` access to the cluster

## Deploy

Apply the project first, then all components:

```bash
kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/components/
```

This creates:
- **postgres** — built from `db/Dockerfile` (schema baked in)
- **redis** — image-based (`redis:7-alpine`)
- **api-service** — built from source
- **analytics-service** — built from source
- **frontend** — built from source

## How it works

Source-based components (postgres, api-service, analytics-service, frontend) use the `docker` workflow to build from `github.com/rashadism/snip-url-shortener`. Each service has a `workload.yaml` descriptor that defines its endpoints and environment variables — no env vars are baked into Dockerfiles.

Inter-service communication uses OpenChoreo service discovery (`<component-name>:80`). The frontend proxies all API requests to backend services, so the browser only makes relative requests.
