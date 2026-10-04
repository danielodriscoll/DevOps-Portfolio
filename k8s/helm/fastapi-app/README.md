# Kubernetes Setup — Local `kind` Cluster

This guide brings up the full local Kubernetes environment from scratch: a
`kind` cluster running the FastAPI app behind the Gateway API, with autoscaling
and a trimmed Prometheus + Grafana observability stack.

It's written to be reproducible — follow it top to bottom and you'll have the
same setup used throughout Phase 3 (Kubernetes) and Phase 6 (Observability).

> **Why this exists:** cluster-internal state (CRDs, metrics-server, the
> monitoring stack) does **not** survive `kind delete cluster`. Rather than
> treat the cluster as a fragile pet to be nursed, it's rebuilt from scratch in
> a few minutes whenever needed. Everything here is captured either in this doc,
> the Helm chart (`k8s/helm/fastapi-app/`), or `observability/values-prometheus.yaml`.

---

## Prerequisites

| Tool | Purpose |
|---|---|
| Docker | `kind` runs the cluster as a Docker container |
| `kind` | Kubernetes-in-Docker — a real cluster on your laptop |
| `kubectl` | CLI for talking to the cluster |
| `helm` | Package manager for Kubernetes (installs the app + monitoring) |
| `hey` *(optional)* | HTTP load generator, for demonstrating autoscaling |

A GitHub Personal Access Token with `read:packages` scope is needed to pull the
app image, because the image is **private** on ghcr.io (see [Image pull secret](#4-image-pull-secret)).

> **Resource note:** the full stack (cluster + app + Prometheus + Grafana) is
> heavy for an 8GB machine. If using WSL, cap it in `.wslconfig`
> (`memory=3GB`, `swap=4GB`, `processors=4`) so the cluster can't starve the
> host, and close memory-heavy apps (browser tabs especially) while it runs.

---

## 1. Create the cluster

```bash
kind create cluster --name devops-portfolio-cluster
kubectl cluster-info
```

`kind` starts a single Docker container that *is* your Kubernetes node, installs
Kubernetes inside it, and writes connection details to `~/.kube/config` so
`kubectl` can reach it automatically.

## 2. Install the Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

The app is exposed with the **Gateway API** (the modern successor to Ingress),
not Ingress. Gateway and HTTPRoute aren't built-in Kubernetes types, so their
Custom Resource Definitions must be installed before the chart's Gateway /
HTTPRoute templates will apply.

## 3. Install metrics-server (for the HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind uses self-signed kubelet certs that metrics-server won't trust by default,
# which makes it crash-loop. This patch tells it to skip that verification.
# Acceptable for local dev; NOT for production.
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

The HorizontalPodAutoscaler needs metrics-server to read pod CPU/memory. Without
the `--kubelet-insecure-tls` patch it fails its own health probe on kind and
never becomes ready.

## 4. Image pull secret

The app image on ghcr.io is private, so the cluster needs credentials to pull
it. This is a separate token from the one AWS Secrets Manager holds for the EC2
path — different environments get different credentials, so a leak in one
doesn't force rotation everywhere.

```bash
# Paste your read:packages token when prompted (input is hidden).
read -rsp "ghcr token: " GHCR_TOKEN; echo
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=danielodriscoll \
  --docker-password="$GHCR_TOKEN"
unset GHCR_TOKEN
```

The Deployment references this secret via `imagePullSecrets`, so every pod uses
it when pulling the image.

## 5. Install the app

```bash
helm install fastapi-app ./k8s/helm/fastapi-app
kubectl get pods -w          # wait for Running 1/1, then Ctrl+C
```

This installs the Deployment, Service, Gateway, HTTPRoute, ConfigMap, Secret,
HPA, and the ServiceMonitor (which tells Prometheus to scrape the app once the
monitoring stack is up).

Verify the app responds:

```bash
kubectl port-forward svc/fastapi-app 8080:80
curl localhost:8080/health      # {"status":"ok"}
curl localhost:8080/metrics     # Prometheus-format text, not JSON
```

## 6. Install the monitoring stack (Phase 6)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f observability/values-prometheus.yaml
```

The default `kube-prometheus-stack` is built for real multi-node clusters and
will overwhelm a laptop. `observability/values-prometheus.yaml` trims it to only
what's needed (Prometheus + Grafana + Operator), disables the rest
(Alertmanager, node-exporter, kube-state-metrics, built-in rules, control-plane
scrapers), and puts hard CPU/memory limits on everything. See that file's
comments for the reasoning behind each choice.

Wait for the pods to settle:

```bash
kubectl get pods -n monitoring -w     # Grafana reaches 3/3 Running, then Ctrl+C
```

## 7. View the dashboard

```bash
# Prometheus — check scrape targets at http://localhost:9090/targets
kubectl port-forward -n monitoring svc/kube-prom-stack-kube-prome-prometheus 9090:9090

# Grafana — dashboards at http://localhost:3000
kubectl port-forward -n monitoring svc/kube-prom-stack-grafana 3000:80

# Grafana admin password:
kubectl get secret -n monitoring kube-prom-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

In Grafana (`admin` / the password above): **Dashboards → New → Import**, paste
`observability/dashboards/fastapi.json`, and select the Prometheus data source.
The dashboard shows requests/sec, p95 latency, error rate, and running pod count.

## 8. Demonstrate autoscaling (optional)

With the app port-forwarded and the dashboard open:

```bash
kubectl get hpa -w                              # watch replicas change
hey -z 90s -c 8 http://localhost:8080/          # drive CPU past the 70% target
```

As CPU crosses the HPA's 70% target the pod count climbs toward its max, then
settles back down after a ~5-minute cooldown once traffic stops.

---

## Tear down

The cluster bills nothing locally, but it's heavy — delete it when you're done:

```bash
kind delete cluster --name devops-portfolio-cluster
```

Everything above rebuilds from this doc (or `scripts/setup-cluster.sh`) in a few
minutes. Nothing of value lives only inside the cluster.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `ImagePullBackOff` on app pods | Pull secret missing or token wrong/expired | Recreate the secret (step 4) with a fresh token, then `kubectl rollout restart deployment fastapi-app-deployment` |
| HPA shows `cpu: <unknown>/70%` | metrics-server not ready | Confirm the `--kubelet-insecure-tls` patch (step 3); check `kubectl get pods -n kube-system \| grep metrics-server` |
| App's Prometheus target is `DOWN` with "unsupported Content-Type" | `/metrics` returning JSON, not Prometheus text | The instrumentator isn't wired into the app — confirm `Instrumentator().instrument(app).expose(app)` in `main.py` |
| Grafana crash-loops (exit 1, no error in logs) | CPU limit too tight → slow start → missed liveness probe | Already handled in `values-prometheus.yaml` (raised limits + relaxed probes) |
| Many components failing at once; `iptables` slow | Host resource exhaustion, not a config bug | Cap/raise WSL resources in `.wslconfig`; close other apps; the trimmed values file is the main mitigation |
| `kubectl` or terminal sluggish | WSL holding memory, or the stuck live-refresh in Grafana | Set Grafana dashboard refresh to Off/30s; `wsl --shutdown` between sessions to reclaim memory |