# Phase 1

# A small fastapi app to be pushed along a CI/CD pipeline
# 3 endpoints -> root, health, metrics


from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

Instrumentator().instrument(app).expose(
    app
)  # this plugin automatically creates /metrics endpoint needed for observability phase


@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.get("/health")
async def health():
    return {"status": "ok"}
