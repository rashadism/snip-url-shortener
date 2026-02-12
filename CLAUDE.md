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

No Makefile, tests, linter, or CI pipeline exists yet. Each service is a standalone Go module under a `go.work` workspace (Go 1.23).

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

Manifests live in `openchoreo/`. Each source-based service has a `workload.yaml` descriptor alongside its Dockerfile defining endpoints and env vars (`configurations.env`). Service discovery in OpenChoreo uses `<component-name>:80` regardless of the container's actual port. Redis is the only image-based component; everything else builds from source via the `docker` workflow pointing at `github.com/rashadism/snip-url-shortener`.
