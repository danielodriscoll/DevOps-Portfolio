# DevOps Portfolio

I plan to have a small fastapi app deployed end-to-end through a modern DevOps toolchain, containerised with Docker, orchestrated with Kubernetes, provisioned on AWS with Terraform, configured with Ansible, and wired together by a GitHub Actions CI/CD pipeline. I'll build this as a learning project from scratch independently, then use Claude Code to audit the final product for security risks and best-practices to see where I can improve.

![Architecture](docs/devops_portfolio_architecture.svg)

## What this project demonstrates

- **Containerisation** — multi-stage Dockerfile, non-root user, `.dockerignore`
- **CI/CD** — GitHub Actions pipeline: lint, test, build, scan, push to GHCR
- **Orchestration** — Kubernetes deployment on a local `kind` cluster, packaged as a Helm chart
- **Infrastructure as Code** — Terraform-provisioned AWS resources with remote state in S3
- **Configuration management** — Ansible playbook to configure the EC2 host
- **Observability** — Prometheus metrics, Grafana dashboards, Loki log aggregation
- **DevSecOps** — image scanning with Trivy, least-privilege IAM, secrets handled via GitHub Actions

## Tech stack

| Layer | Tool |
|---|---|
| Application | Python 3.14, fastapi, gunicorn |
| Testing & linting | pytest, ruff |
| Containers | Docker, Docker Compose |
| Orchestration | Kubernetes (kind), Helm |
| IaC | Terraform |
| Config management | Ansible |
| CI/CD | GitHub Actions |
| Registry | GitHub Container Registry (ghcr.io) |
| Cloud | AWS (EC2, S3) |
| Monitoring | Prometheus, Grafana |
| Logging | Loki, Promtail |
| Security | Trivy |

## Repository structure

```
.
├── app/                # FastApi application + Dockerfile
├── k8s/                # Kubernetes manifests (raw) and Helm chart
├── terraform/          # AWS infrastructure as code
├── ansible/            # EC2 configuration playbooks
├── observability/      # Prometheus, Grafana, Loki configuration
├── .github/workflows/  # CI/CD pipelines
└── docs/               # Architecture diagram and ADRs
```

## Getting started

### Prerequisites

- Python 3.14+
- Docker Desktop
- Make (optional, but recommended)

### Run locally

```bash
# Clone and enter the repo
git clone https://github.com/YOUR-USERNAME/devops-portfolio.git
cd devops-portfolio

# Set up the Python environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt

# Run the app via Docker
make up

# Verify it's running
curl localhost:8080/health
```

### Run the tests

```bash
make test
```

### Deploy to a local Kubernetes cluster

*(Phase 3 — coming soon)*

### Deploy to AWS

*(Phase 4 — coming soon)*

## Build phases

This project will be built incrementally. Each tagged release reflects the completion of one phase.

- [x] **Phase 1** — Fastapi app + Docker
- [x] **Phase 2** — GitHub Actions CI/CD pipeline
- [ ] **Phase 3** — Kubernetes deployment (kind + Helm)
- [ ] **Phase 4** — AWS infrastructure with Terraform
- [ ] **Phase 5** — Ansible configuration management
- [ ] **Phase 6** — Observability (Prometheus, Grafana, Loki)
- [ ] **Phase 7** — Polish, ADRs, documentation
- [ ] **Phase 8** — AI-assisted code review and hardening

## Architecture decisions

Key decisions and trade-offs are documented in [`docs/decisions.md`](docs/decisions.md).

## What I learned

*(Update as I complete each phase.)*

### Phase 1 — Fastapi app + Docker

*(Update!)*

### Phase 2 — CI/CD

*(
- Using `cache: 'pip'` makes the pipeline faster by restoring dependencies instead of downloading each run.

- Set up branch rules so features can't merge to main unless lint, test and docker-build pass. Also blocks force pushes and deletion of main.

- Scanning an image after pushing it to a registry defeats the point. Changed the flow to lint, test, docker, where docker builds and scans before pushing, and only pushes on main.

- A lot of failed runs were things I could have checked locally first. Running commands like `ruff check .` and `pytest` before pushing saves the push and wait cycle.

- Trivy shows what CVEs are in an image. Learned the difference between fixable and unfixable ones, and that severity doesn't always mean real risk. Learned to work around unfixable errors.

- `.gitignore` won't hide sensitive info on Docker image, use dockerignore file)*

- Combining lint, pytest and docker build was causing mulitple slow runs together on every push, instead spilt into two worfklows and docker only runs on a pushed tag e.g v0.1.0

- 

### Phase 3 — Kubernetes deployment (kind + Helm)

## Final review and hardening

After completing all build phases, this project went through a comprehensive code review using Claude Code. The goal was to treat the finished repo the way a senior engineer would on a real PR -> looking for vulnerabilities, anti-patterns, and improvements I'd missed.

Findings, the changes I made in response, and anything I deliberately *didn't* change (and why) are documented in [`docs/review.md`](docs/review.md).(Phase8)

This step happened **after** the project was built, the code, decisions, and structure throughout the phases are mine. The review was a final quality gate, not a co-author.

## License

MIT — see [LICENSE](LICENSE).

## About me

Built by [Daniel O'Driscoll](https://github.com/danielodriscoll) — recent graduate, [link to published research](https://link.springer.com/chapter/10.1007/978-3-032-07938-1_16), [link to LinkedIn](www.linkedin.com/in/danielodriscoll1999).
