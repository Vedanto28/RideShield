import sys
import os
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
root_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)
if root_path not in sys.path:
    sys.path.insert(0, root_path)

import uuid
import asyncio
from datetime import datetime, timezone
import pytest
from unittest.mock import AsyncMock
from fastapi.testclient import TestClient

from main import app
from db.core.session import SessionLocal
from db.models.user import User
from db.models.shift import Shift
from db.models.incident import Incident
from db.models.enums import UserRole, IncidentStatus, ShiftStatus
from app.core.config import settings
from app.services.whatsapp_service import send_whatsapp_message

client = TestClient(app)

@pytest.fixture(scope="module")
def test_rider_user():
    db = SessionLocal()
    rand_id = uuid.uuid4()
    rand_str = str(rand_id.int)[:8]
    phone = f"+91999{rand_str[-7:]}"
    user = User(
        id=rand_id,
        email=f"test_whatsapp_{rand_str}@example.com",
        phone_number=phone,
        hashed_password="hashed_test_pass",
        full_name="Test WhatsApp Rider",
        role=UserRole.RIDER,
        wallet_balance=0.0,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    yield user

    try:
        db.query(Incident).filter(Incident.rider_id == user.id).delete()
        db.query(Shift).filter(Shift.rider_id == user.id).delete()
        db.query(User).filter(User.id == user.id).delete()
        db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()


def test_send_whatsapp_message_meta_success(monkeypatch):
    monkeypatch.setattr(settings, "WHATSAPP_PHONE_NUMBER_ID", "mock_phone_id")
    monkeypatch.setattr(settings, "WHATSAPP_ACCESS_TOKEN", "mock_access_token")

    mock_response_meta = AsyncMock()
    mock_response_meta.status_code = 200
    mock_response_meta.text = "Meta Success"

    mock_post = AsyncMock(return_value=mock_response_meta)
    monkeypatch.setattr("httpx.AsyncClient.post", mock_post)

    success = asyncio.run(send_whatsapp_message("+919876543210", "Test Body"))
    assert success is True

    mock_post.assert_called_once()
    args, kwargs = mock_post.call_args
    assert "graph.facebook.com" in args[0]
    assert kwargs["headers"]["Authorization"] == "Bearer mock_access_token"


def test_send_whatsapp_message_mock_bypass():
    success = asyncio.run(send_whatsapp_message("+15551234567", "Test alert text"))
    assert success is True


def test_whatsapp_webhook_incident_confirmation(test_rider_user, monkeypatch):
    db = SessionLocal()
    
    shift = Shift(
        id=uuid.uuid4(),
        rider_id=test_rider_user.id,
        status=ShiftStatus.ACTIVE,
        distance_km=0.0,
        premium_amount=0.0
    )
    db.add(shift)
    db.commit()
    db.refresh(shift)

    incident = Incident(
        id=uuid.uuid4(),
        shift_id=shift.id,
        rider_id=test_rider_user.id,
        status=IncidentStatus.DETECTED,
        detected_at=datetime.now(timezone.utc),
        peak_g_force=3.5,
        confidence_score=0.9,
        latitude=19.0760,
        longitude=72.8777
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)

    mock_send = AsyncMock(return_value=True)
    monkeypatch.setattr("app.api.whatsapp.send_whatsapp_message", mock_send)

    payload = {
        "From": f"whatsapp:{test_rider_user.phone_number}",
        "Body": "YES"
    }
    
    response = client.post("/api/whatsapp/twilio-webhook", data=payload)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/xml")

    db.refresh(incident)
    assert incident.status == IncidentStatus.FALSE_POSITIVE

    db.query(Incident).filter(Incident.id == incident.id).delete()
    db.query(Shift).filter(Shift.id == shift.id).delete()
    db.commit()
    db.close()
