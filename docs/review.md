# Phase 8: Senior Engineer Review

A review of the finished repo, written the way I'd review a PR from a junior or mid-level engineer on my team. Every finding links to the file it's about. The code is left as built; this document is the to-do list for the next iteration.

**How to read it:** 🔴 fix first · 🟠 should fix · 🟡 worth knowing. Each finding gives the issue and the fix, then a short *Why* to learn from.

---

## Overall verdict

**Strong for a self-taught, from-scratch project.** What stands out:

- The debugging write-ups are real. Diagnosing resource exhaustion from kubelet logs, rather than chasing each failing pod, is senior-level thinking.
- Security instincts are good: least privilege on the `GITHUB_TOKEN`, scan-before-push, IMDSv2, encrypted EBS, a separate bootstrap state, one token per environment, `read -rsp` for secrets.
- Trade-offs are documented honestly (Loki scoped out, KMS default key, `--kubelet-insecure-tls`), which is exactly what reviewers want to see.
- The setup guides have checkpoints and teardown steps. Most portfolios can't be rebuilt by anyone else; this one can.

**Where it falls short:** several things are *described* in the docs but not actually *wired up* in the code (probes, config, the EC2 role, provider pinning). Closing the gap between "what the docs say" and "what the code does" is the main theme of this review.

---

## Fixed during this review

- **`LICENSE` belonged to kubeconform.** Commit `038e2b2` replaced it with kubeconform's Apache licence ("Copyright 2017-2022 Yann Hamon"). Running the CI's `tar -xzf kubeconform.tar.gz` from the repo root extracts kubeconform's `LICENSE` over yours, and `git add .` committed it, along with `rendered.yaml`. Now Apache 2.0 under your name.
  - Lesson: run tool installs in a temp dir (`cd "$(mktemp -d)"`) and read `git diff --stat` before committing.
  - *Why: tarballs extract into the current folder; `git add .` commits whatever is there.*
- README updated: roadmap ticks, licence, the Phase 8 section, and "least-privilege IAM user" reworded.
  - *Why: the user started with `*FullAccess` policies, so "least privilege" overstated it.*

---

## 🔴 Security risks

- **The image you push is not the image you scanned.** [`push-image.yml`](../.github/workflows/push-image.yml) builds once to scan, then builds *again* with `pull: true` to push. Fix: build once, scan it, push that exact image or digest.
  - *Why: a rebuild can pull a newer base image, so an unscanned image ships.*
- **Releases don't require tests to pass.** Any `v*` tag triggers a release, even on a commit that failed CI. Fix: make `ci.yml` reusable (`workflow_call`) and have the release job depend on it with `needs:`.
  - *Why: tags bypass branch protection.*
- **Container runs as root.** The [`Dockerfile`](../myapp/Dockerfile) has no `USER`. Fix: listen on `8080`, add `USER 10001`, map 80→8080 outside the container.
  - *Why: a container escape starts as root.*
- **No pod security context.** [`deployment.yaml`](../k8s/helm/fastapi-app/templates/deployment.yaml) lacks `runAsNonRoot`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`.
  - *Why: limits what an attacker can do inside a compromised pod.*
- **Supply chain: everything is pinned by tag, not by content.**
  - Actions use mutable tags (`@v6`, `@v1.0.0`). Pin third-party actions to a commit SHA.
    - *Why: tags can be moved to malicious code (tj-actions, March 2025).*
  - kubeconform is downloaded with no checksum check ([`ci.yml`](../.github/workflows/ci.yml) line 52). Verify it against the release checksums.
    - *Why: proves the binary wasn't tampered with.*
  - CRD schemas come from datreeio's `main` branch (line 60). Pin to a commit SHA or vendor them. (This answers your What-I-Learned question.)
    - *Why: anyone who can push to `main` changes your CI.*
  - metrics-server uses `releases/latest` and kube-prometheus-stack has no `--version`. Pin both, like Gateway API and NGF.
    - *Why: "latest" makes rebuilds unrepeatable.*
- **The EC2 IAM role isn't actually used.** The `lookup()` in [`playbook.yml`](../ansible/playbook.yml) runs on your laptop with `terraform-user` credentials. Fix: fetch the secret in a task that runs on the host.
  - *Why: lookups run on the controller, so the token passes through your laptop.*
- **GHCR token left on disk.** `docker_login` writes it to `/root/.docker/config.json` on the EC2. Fix: `docker logout` after pull; long term, use **ECR** with the instance role.
  - *Why: base64 is not encryption; anyone with root on the box can read it.*
- **Classic PATs are account-wide.** `read:packages` can read *every* package your account can see.
  - *Why: a leak exposes more than this one image.*

## 🟠 Security: should fix

- **`host_key_checking = False`** ([`ansible.cfg`](../ansible/ansible.cfg)).
  - *Why: a man-in-the-middle on first connect goes unnoticed.*
- **Replace SSH and the IP allowlist with AWS SSM Session Manager** (Ansible supports it as a connection plugin).
  - *Why: no open port 22, no keys, no IP churn, and access is logged in CloudTrail.*
- **`terraform-user` is over-privileged and uses long-lived keys.** Fix: a custom scoped policy, plus IAM Identity Center or `aws-vault`.
  - *Why: leaked long-lived keys with FullAccess = whole account.*
- **`/metrics` is public.** The HTTPRoute matches `PathPrefix: /`. Exclude it; only Prometheus needs it.
  - *Why: leaks internal details to anyone who can reach the app.*
- **No TLS anywhere.** Fine while locked to your IP; needs cert-manager or ACM once public.
  - *Why: plain HTTP can be read and modified in transit.*
- **The tfsec egress suppression has the wrong justification.** Decisions Phase 4 calls it a "false positive" because of your IP lock, but that lock is on *ingress*; egress is `0.0.0.0/0`.
  - *Why: "accepted risk" and "false positive" mean different things in a security review.*
- **No secret scanning.** Add `gitleaks` to CI and pre-commit, and turn on GitHub push protection.
  - *Why: you nearly leaked your IP once; automation catches what eyes miss.*
- **State bucket hardening:** deny non-TLS (`aws:SecureTransport`), `prevent_destroy`, and expire old versions.
  - *Why: state holds secrets and is your only record of the infrastructure.*

---

## 🟠 Flaws and bugs

- **`.gitignore` inline comments: the same bug as Phase 4, still there.** `rendered.yaml   # ...` and `charts/*.tgz   # ...` (lines 43–44) match nothing, and `rendered.yaml` was committed in `038e2b2`.
  - *Why: git treats `#` mid-line as part of the pattern.*
- **No liveness or readiness probes**, despite `/health` being built "for probes" (Decisions Phase 1).
  - *Why: traffic hits pods before they're ready, and hung pods never restart.*
- **The ConfigMap is decorative.** `APP_ENV`, `LOG_LEVEL` and `APP_PORT` are injected but [`main.py`](../myapp/main.py) never reads them. Read them with `pydantic-settings` or remove them.
  - *Why: config that isn't read misleads whoever changes it.*
- **Terraform main config has no `provider` or `required_providers` block.**
  - The provider version is unpinned (the `~> 5.0` pin only exists in `bootstrap/`).
    - *Why: a provider major release can break `apply`.*
  - `var.region` is unused; the region comes from your AWS CLI profile.
    - *Why: someone with another default region deploys elsewhere.*
  - `.terraform.lock.hcl` is gitignored; commit it.
    - *Why: everyone gets the exact same provider build.*
- **`replicaCount: 3` fights the HPA.** Leave `replicas` out of the template when an HPA owns the Deployment.
  - *Why: every `helm upgrade` resets the pod count to 3.*
- **Chart metadata is stale.** `appVersion: "v0.1.1"` vs image `v0.6.0-observability`, and `version` never bumped. Default `image.tag` to `.Chart.AppVersion`.
  - *Why: versions should tell you what's actually deployed.*
- **Hardcoded `namespace: default`** in the ConfigMap and Secret only. Use `{{ .Release.Namespace }}`.
  - *Why: `helm install -n other` splits the release across two namespaces.*
- **The ServiceMonitor forces an install order.** Wrap it in `{{- if .Values.serviceMonitor.enabled }}`.
  - *Why: the chart should install on any cluster.*
- **Unused runtime dependencies:** `msgpack`, `python-dotenv`, `python-multipart`, `pydantic-settings`.
  - *Why: every unused package is attack surface you scan and patch for nothing.*
- **Ansible deploys `:latest`.** Pass a specific tag or digest as a variable.
  - *Why: `:latest` isn't necessarily what you tested and can't be rolled back.*
- **No single source of truth.** `eu-west-1` is in five places (Terraform variable, bootstrap, backend, inventory, playbook); the username in five files. Pass Terraform outputs into Ansible.
  - *Why: values duplicated in several places drift apart; that's why the fork guide needs `sed`.*
- **Leftover local state:** `ansible/terraform.tfstate`. Delete it.
  - *Why: stray state files cause confusion about which state is real.*

---

## 🟡 Better design decisions

- **Build once, promote by digest:** tag with git SHA + semver, deploy the digest everywhere.
  - *Why: one change fixes the scan gap, `:latest` and rollbacks.*
- **ECR for the AWS route.**
  - *Why: the instance role pulls natively, so no PAT, no secret, no `docker login`.*
- **External Secrets Operator** to sync AWS Secrets Manager into the cluster.
  - *Why: delivers your Phase 3 plan and replaces the empty `PLACEHOLDER` Secret.*
- **Scale on requests/sec or latency** (KEDA or prometheus-adapter), not CPU.
  - *Why: an I/O-bound API can be overloaded at low CPU.*
- **GitOps (Argo CD or Flux)** instead of manual `helm install`.
  - *Why: Git becomes the source of truth and drift self-heals.*
- **`kind-config.yaml` + `Makefile`** (`make cluster`, `make app`).
  - *Why: one command beats 8 manual steps; scripts don't skip steps.*
- **Define your own VPC** instead of relying on the default one.
  - *Why: many organisations delete the default VPC.*
- **Switch tfsec to `trivy config`.**
  - *Why: tfsec has been folded into Trivy; one scanner for images and IaC.*

---

## 🟡 Better practices

- **Smoke-test the container in CI** (`docker run -d` + `curl /health`).
  - *Why: would have caught the Phase 5 missing-binary bug before AWS.*
- **pre-commit hooks** (ruff, `terraform fmt`, gitleaks, yamllint).
  - *Why: automates your own Phase 2 lesson of checking locally first.*
- **Dependabot or Renovate** for pip, Actions, base image, providers.
  - *Why: pins go stale silently.*
- **`ansible-lint`, `yamllint`, and pinned collection versions.**
  - *Why: lint everything you ship, not just Python.*
- **Test the chart, not just lint it** (`helm test` / chart-testing on kind in CI).
  - *Why: lint checks syntax, not whether it actually runs.*
- **Reproducible Docker builds:** drop `apt-get upgrade`, pin the base image by digest, avoid the hardcoded `python3.14/site-packages` path.
  - *Why: the same commit should always build the same image.*
- **Comment the *why*, not the *what*.**
  - *Why: in a team, "what" comments are noise and go stale.*
- **Short ADRs** (context → decision → consequences) alongside the learning log.
  - *Why: the reasoning can be found later without reading the whole history.*

---

## 🟡 Docs vs code: things that don't line up

Left as written in the authentic logs, recorded here so readers don't trip over them:

- Decisions Phase 1: `/health` built for probes → no probes exist.
- Decisions Phase 4: provider "pinned to `~> 5.0`" → only in `bootstrap/`.
- Decisions Phase 4: egress finding called a "false positive" → accepted risk.
- Decisions Phase 5: "the identity making the AWS call is the EC2 itself" → it's the laptop (the next bullet in the same file is correct).
- Decisions Phase 6: CloudWatch "planned Phase 6.5" → not on the roadmap; listed under future work below.
- What-I-Learned Phase 4: the last bullet ("uploaded new tag which triggers image to be built which contains docker") is unfinished.
- What-I-Learned Phase 4: the `.gitignore` inline comment lesson → the same pattern is still in `.gitignore`.

---

## What to build next

Roughly in order of portfolio value per hour:

1. **Close the 🔴 list.** *Why: biggest risk reduction for the least work.*
2. **Alerting and SLOs** (Alertmanager burn-rate alerts on error rate and p95). *Why: dashboards only help when someone is looking.*
3. **TLS** with cert-manager + Let's Encrypt. *Why: table stakes for anything public.*
4. **Image signing and SBOM** (`cosign` + `syft`). *Why: proves what's deployed is what you built.*
5. **GitHub OIDC → AWS** for `terraform plan` on PRs. *Why: no stored AWS keys, and infra changes get reviewed.*
6. **Logs and traces** (CloudWatch or Loki, plus OpenTelemetry). *Why: completes the three pillars of observability.*
7. **Policy as code** (Kyverno or Gatekeeper). *Why: blocks root containers and `:latest` automatically.*
8. **Managed Kubernetes** (short-lived EKS or k3s on EC2) with the same chart. *Why: proves the chart is portable beyond kind.*

---

*Review carried out with Claude Code (Opus 5.5), October 2026.*
