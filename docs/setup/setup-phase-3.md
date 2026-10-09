# Phase 3: Kubernetes on kind (Helm, Gateway API, HPA)

[← Phase 2](setup-phase-2.md) · [All phases](../../README.md#getting-started) · [Phase 4 →](setup-phase-4.md)

The chart README at [`k8s/helm/fastapi-app/README.md`](../../k8s/helm/fastapi-app/README.md) explains the cluster in more depth and has a troubleshooting table.

## 1. Create the cluster

```bash
kind create cluster --name devops-portfolio-cluster
kubectl cluster-info
```

## 2. Install the Gateway API CRDs and NGINX Gateway Fabric

The app is exposed through the Gateway API rather than Ingress. These two versions are pinned because they're tested together.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 1.5.1 --create-namespace -n nginx-gateway

kubectl get pods -n nginx-gateway     # wait for Running
```

## 3. Install metrics-server (the HPA needs it to read CPU)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind's kubelets use self-signed certs, so metrics-server needs this flag to start.
# Fine for a local cluster, never for production.
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

## 4. Give the cluster a pull secret for your private image

```bash
read -rsp "GHCR read:packages token: " GHCR_TOKEN; echo
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password="$GHCR_TOKEN"
unset GHCR_TOKEN
```

## 5. Install the app chart

> **Heads up:** the chart also contains the ServiceMonitor used in Phase 6, and that resource type only exists once the monitoring stack is installed. On a fresh cluster, run [Phase 6 step 1](setup-phase-6.md#1-install-the-trimmed-monitoring-stack) first, otherwise Helm fails with `no matches for kind "ServiceMonitor"`.

```bash
helm install fastapi-app ./k8s/helm/fastapi-app --set image.tag=v0.1.0   # the tag you pushed in Phase 2
kubectl get pods -w        # wait for Running 1/1, then Ctrl+C
```

## 6. Reach the app through the Gateway

```bash
kubectl port-forward -n nginx-gateway svc/ngf-nginx-gateway-fabric 8080:80
```

In a second terminal:

```bash
curl localhost:8080/health
kubectl get hpa            # TARGETS shows cpu: <n>%/70% once metrics-server is ready (~1 min)
```

✅ **Checkpoint:** `/health` responds through the Gateway, and `kubectl get hpa` shows a real CPU percentage, not `<unknown>`.

Keep the cluster if you're going on to Phase 6. Otherwise run `kind delete cluster --name devops-portfolio-cluster`. Everything here can be rebuilt in a few minutes.

---

[← Phase 2](setup-phase-2.md) · [All phases](../../README.md#getting-started) · [Phase 4 →](setup-phase-4.md)
