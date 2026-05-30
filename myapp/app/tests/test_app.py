import pytest
from myapp import app
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    return TestClient(app)


def test_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello World"}


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_metrics(client):
    response = client.get("/metrics")
    assert response.status_code == 200
    assert response.json() == "Coming in Phase 6 of this project"


def test_404_route(client):
    response = client.get("/doesnt_exist")
    assert response.status_code == 404
