import pytest
import json
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.responses import JSONResponse
from unittest.mock import MagicMock, patch

from utils.idempotency import IdempotencyMiddleware

test_app = FastAPI()
test_app.add_middleware(IdempotencyMiddleware)

call_count = 0

@test_app.post("/execute-action")
def run_action():
    global call_count
    call_count += 1
    return {"status": "success", "call_count": call_count}

client = TestClient(test_app)

def test_invalid_key_length_returns_400():
    response = client.post("/execute-action", headers={"Idempotency-Key": "short"})
    assert response.status_code == 400
    assert "Invalid Idempotency-Key" in response.json()["detail"]

def test_missing_header_passes_through():
    global call_count
    call_count = 0
    res1 = client.post("/execute-action")
    res2 = client.post("/execute-action")
    assert res1.status_code == 200
    assert res2.status_code == 200
    assert call_count == 2

def test_idempotent_replay_returns_cached_response():
    with patch("config.firebase.db") as mock_db:
        mock_snap = MagicMock()
        mock_snap.exists = True
        mock_snap.to_dict.return_value = {
            "status": "completed",
            "response_body": json.dumps({"status": "success", "cached": True}),
            "status_code": 200,
        }
        mock_doc_ref = mock_db.collection.return_value.document.return_value
        from google.api_core.exceptions import AlreadyExists
        mock_doc_ref.create.side_effect = AlreadyExists("mock already exists")
        mock_doc_ref.get.return_value = mock_snap

        valid_key = "idemp_test_uuid_98765432101234"
        response = client.post("/execute-action", headers={"Idempotency-Key": valid_key})
        assert response.status_code == 200
        assert response.headers.get("x-idempotent-replay") == "true"
        assert response.json()["cached"] is True
