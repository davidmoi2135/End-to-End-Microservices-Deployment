# Kubernetes GitOps layout

This directory now has two deployable Kustomize environments:

```text
k8s/
  base/                  Shared application manifests
  overlays/dev/          Dev environment, branch/image tag: dev
  overlays/production/   Production environment, branch/image tag: main
  platform/              Cluster-wide prerequisites applied once
```

## Render or apply manually

Apply cluster-wide resources once:

```bash
kubectl apply -k spring-boot-app/k8s/platform
```

Create the environment secret before syncing the app. Copy the matching example to `secrets.yaml`, replace all `change-me` values, then apply the ignored local file:

```bash
cp spring-boot-app/k8s/overlays/dev/secret-example.yaml spring-boot-app/k8s/overlays/dev/secrets.yaml
kubectl apply -f spring-boot-app/k8s/overlays/dev/secrets.yaml

cp spring-boot-app/k8s/overlays/production/secret-example.yaml spring-boot-app/k8s/overlays/production/secrets.yaml
kubectl apply -f spring-boot-app/k8s/overlays/production/secrets.yaml
```

Render or apply dev:

```bash
kubectl kustomize spring-boot-app/k8s/overlays/dev
kubectl apply -k spring-boot-app/k8s/overlays/dev
```

Render or apply production:

```bash
kubectl kustomize spring-boot-app/k8s/overlays/production
kubectl apply -k spring-boot-app/k8s/overlays/production
```

## GitOps flow

Dev:

```text
push to dev
  -> GitHub Actions builds images tagged :dev
  -> ArgoCD app argocd/dev-app.yaml syncs spring-boot-app/k8s/overlays/dev
  -> ArgoCD Image Updater writes image digests back to dev
```

Production:

```text
merge/push to main
  -> GitHub Actions builds images tagged :main
  -> ArgoCD app argocd/production-app.yaml syncs spring-boot-app/k8s/overlays/production
  -> ArgoCD Image Updater writes image digests back to main
```

The app services are `ClusterIP`. Public traffic should enter through the cloud load balancer for the ingress-nginx controller, then route by `microservices-ingress`.
