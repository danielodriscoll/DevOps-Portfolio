# DevOps Portfolio

A small Flask web app deployed end-to-end through a modern DevOps toolchain — containerised with Docker, orchestrated with Kubernetes, provisioned on AWS with Terraform, configured with Ansible, and wired together by a GitHub Actions CI/CD pipeline. Built as a learning project to cover the core competencies in a junior DevOps role.

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
| Application | Python 3.14, Flask, gunicorn |
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
├── app/                # Flask application + Dockerfile
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

This project was built incrementally. Each tagged release reflects the completion of one phase.

- [x] **Phase 1** — Flask app + Docker
- [ ] **Phase 2** — GitHub Actions CI/CD pipeline
- [ ] **Phase 3** — Kubernetes deployment (kind + Helm)
- [ ] **Phase 4** — AWS infrastructure with Terraform
- [ ] **Phase 5** — Ansible configuration management
- [ ] **Phase 6** — Observability (Prometheus, Grafana, Loki)
- [ ] **Phase 7** — Polish, ADRs, documentation
- [ ] **Phase 8** — AI-assisted code review and hardening

## Architecture decisions

Key decisions and trade-offs are documented in [`docs/decisions.md`](docs/decisions.md).

## What I learned

*(Updated as each phase completes.)*

### Phase 1 — Flask app + Docker

*(Two or three sentences in your own voice about what tripped you up and what you now understand.)*

### Phase 2 — CI/CD

*(...)*

## Final review and hardening

After completing all build phases, this project went through a comprehensive code review using Claude Code. The goal was to treat the finished repo the way a senior engineer would on a real PR — looking for vulnerabilities, anti-patterns, and improvements I'd missed.

Findings, the changes I made in response, and anything I deliberately *didn't* change (and why) are documented in [`docs/review.md`](docs/review.md).

This step happened **after** the project was built — the code, decisions, and structure throughout the phases are mine. The review was a final quality gate, not a co-author.

## License

MIT — see [LICENSE](LICENSE).

## About me

Built by [Your Name](https://github.com/YOUR-USERNAME) — recent graduate, [link to published research](#), [link to LinkedIn](#).
