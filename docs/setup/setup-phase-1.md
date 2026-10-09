# Phase 1: Run the app locally and in Docker

[← Before you start](setup-phase-0.md) · [All phases](../../README.md#getting-started) · [Phase 2 →](setup-phase-2.md)

## 1. Clone and set up Python

```bash
git clone https://github.com/<your-github-username>/devops-portfolio.git
cd devops-portfolio

python3 -m venv .venv
source .venv/bin/activate
pip install -r myapp/requirements-dev.txt     # runtime deps + pytest, ruff, httpx
```

## 2. Run the app with auto-reload

```bash
uvicorn myapp.main:app --reload --port 8000
```

In a second terminal:

```bash
curl localhost:8000/            # {"message":"Hello World"}
curl localhost:8000/health      # {"status":"ok"}
curl localhost:8000/metrics     # Prometheus-format text (used in Phase 6)
```

## 3. Run the same checks CI runs

```bash
ruff format --check .
ruff check .
pytest -v
```

## 4. Build and run the container

```bash
docker build -t devops-portfolio myapp
docker run --rm -p 8080:80 devops-portfolio     # container listens on 80, mapped to 8080

curl localhost:8080/health
```

✅ **Checkpoint:** all 4 tests pass, and `/health` returns `{"status":"ok"}` both locally and from the container.

---

[← Before you start](setup-phase-0.md) · [All phases](../../README.md#getting-started) · [Phase 2 →](setup-phase-2.md)
