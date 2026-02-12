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

.PHONY: build bump manifests $(addprefix build-,$(SERVICES)) $(addprefix push-,$(SERVICES))

# --- Build, push, bump version, update manifests ---
build: $(addprefix push-,$(SERVICES)) bump manifests

# --- Per-service build ---
define BUILD_RULE
build-$(1):
	docker build -t $(IMAGE_$(1)):v$(VERSION) -t $(IMAGE_$(1)):latest -f $(DOCKERFILE_$(1)) $(CONTEXT_$(1))
endef
$(foreach svc,$(SERVICES),$(eval $(call BUILD_RULE,$(svc))))

# --- Per-service push ---
define PUSH_RULE
push-$(1): build-$(1)
	docker push $(IMAGE_$(1)):v$(VERSION)
	docker push $(IMAGE_$(1)):latest
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
# Compares HEAD against the commit that last modified VERSION.
bump:
	@last_bump=$$(git log -1 --format=%H -- VERSION 2>/dev/null || echo ""); \
	if [ -z "$$last_bump" ]; then \
		changed="first build"; \
	else \
		changed=$$(git log --oneline "$$last_bump..HEAD" -- api-service/ analytics-service/ frontend/ db/); \
	fi; \
	if [ -n "$$changed" ]; then \
		current=$$(cat VERSION); \
		major=$$(echo $$current | cut -d. -f1); \
		minor=$$(echo $$current | cut -d. -f2); \
		patch=$$(echo $$current | cut -d. -f3); \
		new_patch=$$((patch + 1)); \
		echo "$$major.$$minor.$$new_patch" > VERSION; \
		echo "Bumped version: $$current -> $$major.$$minor.$$new_patch"; \
	else \
		echo "No code changes since last bump, skipping (v$$(cat VERSION))"; \
	fi
