# ---------- Stage 1: builder ----------
FROM python:3.14-slim AS builder
WORKDIR /code
COPY requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade --target=/install -r /code/requirements.txt

# ---------- Stage 2: final runtime ----------
FROM python:3.14-slim
WORKDIR /code

# Update OS packages to patch Debian-layer CVEs (the 9 findings)
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Upgrade the base image's own build tools to patched versions (fixes setuptools)
RUN pip install --no-cache-dir --upgrade "setuptools>=78.1.1" pip

COPY --from=builder /install /usr/local/lib/python3.14/site-packages
COPY . /code/myapp

CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]