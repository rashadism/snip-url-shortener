# Deploying on OpenChoreo

## Prerequisites

- An OpenChoreo cluster with the control plane and build plane installed
- `kubectl` access to the cluster

## Deploy

There are two deployment options. Both deploy the same five components (postgres, redis, api-service, analytics-service, frontend). Apply the project first, then pick one:

### Option A: Build from source

Components are built on-cluster from GitHub via the `docker` workflow:

```bash
kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/components/
```

### Option B: Pre-built images

Containers pull directly from the registry, no build workflow runs:

```bash
kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/from-image/
```

To build and push the images to your own registry:

```bash
# Set your DockerHub username or registry, then log in
echo "your-username" > REGISTRY
docker login

# Build, push, bump patch version, and update manifests
make build
```

## Cleanup

Deleting the project removes all its components:

```bash
kubectl delete -f openchoreo/project.yaml
```

## How it works

Source-based components (postgres, api-service, analytics-service, frontend) use the `docker` workflow to build from `github.com/rashadism/snip-url-shortener`. Each service has a `workload.yaml` descriptor that defines its endpoints and environment variables — no env vars are baked into Dockerfiles.

Inter-service communication uses OpenChoreo service discovery (`<component-name>:80`). The frontend proxies all API requests to backend services, so the browser only makes relative requests.
