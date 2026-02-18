# Set your registry in the REGISTRY file (e.g. your DockerHub username).
# Ensure you are logged in: docker login
REGISTRY := $(shell cat REGISTRY)

VERSION := $(shell cat VERSION)

SERVICES := api analytics frontend postgres

IMAGE_api      := $(REGISTRY)/snip-api-service
IMAGE_analytics := $(REGISTRY)/snip-analytics-service
IMAGE_frontend := $(REGISTRY)/snip-frontend
IMAGE_postgres := $(REGISTRY)/snip-postgres

DOCKERFILE_api      := api-service/Dockerfile
DOCKERFILE_analytics := analytics-service/Dockerfile
DOCKERFILE_frontend := frontend/Dockerfile
DOCKERFILE_postgres := db/Dockerfile

CONTEXT_api      := api-service
CONTEXT_analytics := analytics-service
CONTEXT_frontend := frontend
CONTEXT_postgres := db

PLATFORMS := linux/amd64,linux/arm64

.PHONY: build bump manifests $(addprefix push-,$(SERVICES))

# --- Bump, build+push (multi-arch), update manifests ---
build: bump push manifests

push: $(addprefix push-,$(SERVICES))

# --- Per-service multi-arch build & push ---
define PUSH_RULE
push-$(1):
	docker buildx build --platform $(PLATFORMS) \
		-t $(IMAGE_$(1)):v`cat VERSION` -t $(IMAGE_$(1)):latest \
		-f $(DOCKERFILE_$(1)) $(CONTEXT_$(1)) --push
endef
$(foreach svc,$(SERVICES),$(eval $(call PUSH_RULE,$(svc))))

# --- Update image tags in from-image manifests ---
manifests:
	@reg=$$(cat REGISTRY); \
	ver=$$(cat VERSION); \
	for f in openchoreo/from-image/api-service.yaml openchoreo/from-image/analytics-service.yaml openchoreo/from-image/frontend.yaml openchoreo/from-image/postgres.yaml; do \
		sed -i '' "s|image: .*/snip-\(.*\):.*|image: $$reg/snip-\1:v$$ver|" "$$f"; \
	done; \
	echo "Updated manifests: $$reg, v$$ver"

# --- Bump patch version (only if source dirs changed since last bump) ---
# Compares HEAD against the ref stored in .version-ref.
bump:
	@if [ ! -f .version-ref ]; then \
		changed="first build"; \
	else \
		last_ref=$$(cat .version-ref); \
		changed=$$(git diff --name-only "$$last_ref" -- api-service/ analytics-service/ frontend/ db/); \
	fi; \
	if [ -n "$$changed" ]; then \
		current=$$(cat VERSION); \
		major=$$(echo $$current | cut -d. -f1); \
		minor=$$(echo $$current | cut -d. -f2); \
		patch=$$(echo $$current | cut -d. -f3); \
		new_patch=$$((patch + 1)); \
		echo "$$major.$$minor.$$new_patch" > VERSION; \
		git rev-parse HEAD > .version-ref; \
		echo "Bumped version: $$current -> $$major.$$minor.$$new_patch"; \
	else \
		echo "No code changes since last bump, skipping (v$$(cat VERSION))"; \
	fi
