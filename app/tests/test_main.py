import importlib

from fastapi.testclient import TestClient


def make_client(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("APP_VERSION", "test")
    import main

    importlib.reload(main)
    return TestClient(main.app)


def test_root_says_version(tmp_path, monkeypatch):
    r = make_client(tmp_path, monkeypatch).get("/")
    assert r.status_code == 200
    assert r.json()["version"] == "test"


def test_healthz(tmp_path, monkeypatch):
    assert make_client(tmp_path, monkeypatch).get("/healthz").json() == {"status": "ok"}


def test_items_are_saved(tmp_path, monkeypatch):
    c = make_client(tmp_path, monkeypatch)
    assert c.post("/items", json={"nombre": "gpu"}).status_code == 201
    assert [i["nombre"] for i in c.get("/items").json()] == ["gpu"]
    assert (tmp_path / "items.json").exists()
