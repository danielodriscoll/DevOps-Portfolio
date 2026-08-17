# ---------- Stage 1: builder ----------
FROM python:3.14-slim AS builder
WORKDIR /code
COPY requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade --target=/install -r /code/requirements.txt

# ---------- Stage 2: final runtime ----------
FROM python:3.14-slim
WORKDIR /code

# Update OS packages to patch Debian-layer CVEs
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Copy your installed dependencies from the builder
COPY --from=builder /install /usr/local/lib/python3.14/site-packages
COPY . /code/myapp

# Remove pip and setuptools — not needed at runtime, and their vendored copies trip Trivy
RUN pip uninstall -y pip setuptools 2>/dev/null || true

CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]