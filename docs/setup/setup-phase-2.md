# Phase 2: CI/CD with GitHub Actions

[← Phase 1](setup-phase-1.md) · [All phases](../../README.md#getting-started) · [Phase 3 →](setup-phase-3.md)

## 1. Make the fork yours

Swap my username for yours in the files that reference it: the image names, the Ansible GHCR login and the Terraform state bucket name. Use your username **in lowercase**, because GHCR image names and S3 bucket names must be lowercase.

```bash
GH_USER=<your-github-username-lowercase>
sed -i "s/danielodriscoll/$GH_USER/g" \
  .github/workflows/push-image.yml \
  k8s/helm/fastapi-app/values.yaml \
  ansible/playbook.yml \
  terraform/bootstrap/main.tf \
  terraform/backend.tf

git diff --stat     # should show those 5 files changed
```

Commit and push the change.

## 2. Watch CI run

[`ci.yml`](../../.github/workflows/ci.yml) runs on every push and pull request to `main`: Ruff lint, pytest, `helm lint`, `kubeconform`, `terraform fmt`/`validate` and `tfsec`. Check the **Actions** tab after pushing.

## 3. Protect `main` *(recommended)*

In **Settings → Branches → Add branch ruleset** for `main`, require a pull request and these status checks to pass: `lint`, `test`, `helm-lint`, `kubeconform`, `terraform-validate`, `terraform-security`. Also block force pushes and deletion.

## 4. Release an image

[`push-image.yml`](../../.github/workflows/push-image.yml) runs only on version tags. It builds the image, scans it with Trivy (failing on fixable HIGH/CRITICAL CVEs) and only pushes to GHCR if the scan passes.

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 5. Make the image private and create a pull token

- On GitHub, open **your profile → Packages → devops-portfolio → Package settings** and set visibility to **Private**.
- Create a **classic** personal access token (**Settings → Developer settings → Personal access tokens → Tokens (classic)**) with **only** the `read:packages` scope and a short expiry (I used 30 days). Don't save it anywhere; you'll paste it in Phase 3. You'll create a second one for Phase 5.

✅ **Checkpoint:** CI is green on `main`, and `ghcr.io/<your-github-username>/devops-portfolio:v0.1.0` appears under your Packages as private.

---

[← Phase 1](setup-phase-1.md) · [All phases](../../README.md#getting-started) · [Phase 3 →](setup-phase-3.md)
