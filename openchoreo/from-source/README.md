# Build from Source

Components are built on-cluster from GitHub via the `docker` workflow.

```bash
# Create the cache component type (Recreate strategy for Redis)
kubectl apply -f openchoreo/cache-component-type.yaml

kubectl apply -f openchoreo/project.yaml
kubectl apply -f openchoreo/from-source/
```
