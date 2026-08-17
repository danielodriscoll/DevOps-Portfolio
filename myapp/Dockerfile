# ---------- Stage 1: builder ----------
FROM python:3.14-slim AS builder

WORKDIR /code

COPY requirements.txt /code/requirements.txt

RUN pip install --no-cache-dir --upgrade --target=/install -r /code/requirements.txt

# ---------- Stage 2: final runtime ----------
FROM python:3.14-slim

WORKDIR /code

COPY --from=builder /install /usr/local/lib/python3.14/site-packages

COPY . /code/myapp

CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]