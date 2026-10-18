import os
from pathlib import Path
import pytest
from app import create_app


@pytest.fixture
def app_instance(monkeypatch):
    monkeypatch.setattr('app.init_db', lambda app: None)
    app, _ = create_app('testing')
    backend_dir = Path(__file__).resolve().parent.parent
    app.config['UPLOAD_FOLDER'] = str(backend_dir / 'uploads')
    return app


@pytest.fixture
def client(app_instance):
    return app_instance.test_client()


def test_resolved_upload_directory_is_absolute():
    from config import get_config
    cfg = get_config('development')
    backend_dir = Path(__file__).resolve().parent.parent
    assert os.path.isabs(cfg.UPLOAD_FOLDER)
    assert os.path.normpath(cfg.UPLOAD_FOLDER) == os.path.normpath(str(backend_dir / 'uploads'))


def test_orbit_calculator_image_serves_http_200(client):
    res = client.get('/uploads/complaints/e9d9c659b11d459b856314ec4a43f125.jpg')
    assert res.status_code == 200
    assert res.content_type == 'image/jpeg'
    assert len(res.data) == 261068


def test_nonexistent_image_returns_404(client):
    res = client.get('/uploads/complaints/nonexistent_file_12345.jpg')
    assert res.status_code == 404
    assert res.content_type == 'application/json'
    assert res.get_json()['error'] == 'Not Found'


def test_complaint_upload_uses_configured_upload_dir(app_instance):
    with app_instance.app_context():
        from flask import current_app
        configured_upload = current_app.config.get('UPLOAD_FOLDER')
        upload_dir = os.path.join(configured_upload, 'complaints')
        assert os.path.isabs(upload_dir)
        backend_dir = Path(__file__).resolve().parent.parent
        assert os.path.normpath(upload_dir) == os.path.normpath(str(backend_dir / 'uploads' / 'complaints'))
