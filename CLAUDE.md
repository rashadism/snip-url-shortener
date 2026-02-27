# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Start all services (postgres, redis, api, analytics, frontend)
docker compose up --build

# Rebuild a single service
docker compose up --build api-service

# Frontend available at http://localhost:9700
# API service at http://localhost:9701, Analytics at http://localhost:9702
```

No tests, linter, or CI pipeline exists yet. Each service is a standalone Go module under a `go.work` workspace (Go 1.23).

### Build & Push Images

```bash
# Set your DockerHub username, then log in
echo "your-username" > REGISTRY
docker login

# Bump patch version, build & push all images, update from-image manifests
make build
```

Version is tracked in `VERSION` (currently `0.2.4`). `make build` auto-bumps the patch number if source dirs changed since the last bump (tracked via `.version-ref`).

## Architecture

Three Go microservices behind a **BFF (Backend-For-Frontend)** pattern:

```
Browser → Frontend (:3000) → API Service (:8080) → Postgres / Redis
                            → Analytics Service (:8081) → Postgres / Redis
```

The Frontend Go server **proxies** all `/api/*` and `/r/*` requests to backend services (configured via `API_SERVICE_URL`, `ANALYTICS_SERVICE_URL` env vars). This avoids hardcoded service hostnames in the browser — the JS SPA only makes relative requests (`/api/shorten`, `/r/{code}`). This is the key architectural choice: it makes the app work identically in docker-compose, port-forwarded k8s, and OpenChoreo without URL changes.

**Redis is optional.** All cache operations (`cache.go`) are nil-safe — the system works without Redis, just slower.

## Key Patterns

- **Async goroutines**: Metadata fetching and click recording use `context.WithoutCancel(ctx)` so they survive after the HTTP handler returns while preserving trace context.
- **Redirect proxy**: The frontend's HTTP client uses `CheckRedirect: func(...) error { return http.ErrUseLastResponse }` to pass 302s through instead of following them.
- **URL validation**: The API auto-prepends `https://` if no scheme is provided (handlers.go).
- **OpenTelemetry**: Each service has its own `tracing.go`. Uses OTLP over HTTP (port 4318). Disabled by default (`OTEL_ENABLED=false`). The `otlptracehttp` client auto-appends `/v1/traces` to the endpoint.

## Database

Schema is in `db/init.sql`, baked into a custom postgres image (`db/Dockerfile`) to avoid volume-mount complexity. Two tables: `urls` (with click_count denormalized) and `clicks` (event log).

## OpenChoreo Deployment

Manifests live in `openchoreo/` with two deployment modes:

- **`from-image/`** — Component + Workload YAMLs using pre-built Docker images (`rashadxyz/snip-*`)
- **`from-source/`** — Component + ComponentWorkflowRun YAMLs that build from `github.com/rashadism/snip-url-shortener` via the `docker` workflow

Service discovery in OpenChoreo uses `<component-name>:80` regardless of the container's actual port. Connections between services are declared in Workload manifests (from-image) or injected at runtime (from-source).

**`alerting-demo/`** contains resources for demonstrating observability alerting (notification channels, ReleaseBindings, traffic scripts). Alert traits are patched onto components via `kubectl patch` rather than baked into the base manifests, so the demo works with either deployment mode.
