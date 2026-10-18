"""Class 4 demo API: small on purpose, so the Dockerfile and the pipeline are the topic.

GET  /         -> who answers: message, version (baked in at build time) and hostname
GET  /healthz  -> {"status": "ok"} for the smoke test and the deploy check
GET  /items    -> the items saved in DATA_DIR (survive a container restart if /data is a volume)
POST /items    -> {"nombre": "..."} appends one item
GET  /docs     -> Swagger UI, to try everything from the browser
"""

import json
import os
import socket
import time
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel

APP_VERSION = os.getenv("APP_VERSION", "dev")
DATA_DIR = Path(os.getenv("DATA_DIR", "./data"))
ITEMS_FILE = DATA_DIR / "items.json"

app = FastAPI(title="demo-c4", version=APP_VERSION)


class Item(BaseModel):
    nombre: str


def _read_items() -> list[dict]:
    if not ITEMS_FILE.exists():
        return []
    return json.loads(ITEMS_FILE.read_text())


@app.get("/")
def root() -> dict:
    return {
        "mensaje": "Hola desde la clase 4, desplegado por el pipeline",
        "version": APP_VERSION,
        "host": socket.gethostname(),
    }


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/items")
def list_items() -> list[dict]:
    return _read_items()


@app.post("/items", status_code=201)
def create_item(item: Item) -> dict:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    items = _read_items()
    new = {"nombre": item.nombre, "creado": int(time.time())}
    items.append(new)
    ITEMS_FILE.write_text(json.dumps(items))
    return new
