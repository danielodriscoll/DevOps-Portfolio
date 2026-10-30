# ---------- PHASE 1 --------
    
# ---------- Multi-Stage Docker Build --------
# ---------- Stage 1: builder ----------
FROM python:3.14-slim AS builder
WORKDIR /code
COPY requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade --target=/install -r /code/requirements.txt

# ---------- Stage 2: final runtime ----------
FROM python:3.14-slim
WORKDIR /code

# Update OS packages to patch Debian Critical Vulnerablities caught by Trivy
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Copy installed dependencies from the builder in stage 1
COPY --from=builder /install /usr/local/lib/python3.14/site-packages
COPY . /code/myapp

# Remove pip and setuptools — not needed at runtime, and their vendored copies set off Trivy, also reduces image size
RUN pip uninstall -y pip setuptools 2>/dev/null || true

#0.0.0.0 means listen on every IP the container gets, so traffic from outside the container reaches the app, on port 80
CMD ["python", "-m", "uvicorn", "myapp.main:app", "--host", "0.0.0.0", "--port", "80"]