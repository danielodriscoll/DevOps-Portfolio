# Before you start

[All phases](../../README.md#getting-started) · [Phase 1 →](setup-phase-1.md)

These guides rebuild the project **one phase at a time**, in the order I built it. Each phase ends with a ✅ **Checkpoint**, so you know it worked before moving on. Phases 1–3 and 6 run entirely on your laptop for free. Phases 4–5 create real AWS resources at a small cost (see the warning in Phase 4).

Anything in `<angle-brackets>` is a value you supply yourself. Never paste real tokens, keys or IPs into files that get committed.

## Tools

Install only what the phase you're on needs.

| Tool | Needed from | Check it's installed |
|---|---|---|
| Git, Python 3.14+ | Phase 1 | `python3 --version` |
| Docker | Phase 1 | `docker version` |
| A GitHub account | Phase 2 | — |
| `kind`, `kubectl`, `helm` | Phase 3 | `kind version`, `kubectl version --client`, `helm version` |
| An AWS account, AWS CLI v2, `terraform` ≥ 1.10 | Phase 4 | `aws --version`, `terraform version` |
| `ansible` (+ `boto3`, installed in Phase 5) | Phase 5 | `ansible --version` |
| `hey` *(optional load generator)* | Phase 6 | `hey` |

> **Low-spec machine or WSL?** Phases 3 and 6 run a whole Kubernetes cluster plus Prometheus and Grafana. On an 8GB laptop, cap WSL in `%UserProfile%\.wslconfig` (`memory=3GB`, `swap=4GB`, `processors=4`) and close browser tabs you don't need.

## Fork first

Phase 1 works from a plain clone, but from Phase 2 onwards you need your own copy: CI runs in your account, and the image is pushed to your own registry. Fork the repo on GitHub and clone your fork.

## Security ground rules

These apply in every phase:

- Secrets are typed in with `read -rsp` (hidden input, kept out of shell history) and never written to a file in the repo.
- `terraform.tfvars`, `*.tfstate` and `.env` are already gitignored. Run `git status` before every commit anyway.
- GitHub tokens get the smallest scope that works (`read:packages`), a short expiry, and **one token per environment** (cluster, EC2), so a leak in one place doesn't force rotation everywhere.
- AWS work uses a dedicated IAM user, never the root account.

---

[All phases](../../README.md#getting-started) · [Phase 1 →](setup-phase-1.md)
