from types import SimpleNamespace

import pytest

import app.services.auth_service as auth_service
from app.services.auth_service import AuthService, AuthServiceError


class FakeQuery:
    def __init__(self, user):
        self.user = user

    def filter_by(self, **filters):
        assert filters == {'firebase_uid': 'firebase-user-1'}
        return self

    def first(self):
        return self.user


class FakeSession:
    def commit(self):
        pass


@pytest.fixture
def login_context(monkeypatch):
    user = SimpleNamespace(
        firebase_uid='firebase-user-1',
        usn_or_employee_id='1KS23CS001',
        is_active=True,
        last_login=None,
    )

    monkeypatch.setattr(
        AuthService,
        'verify_firebase_token',
        staticmethod(lambda token: {'firebase_uid': 'firebase-user-1'}),
    )
    monkeypatch.setattr(
        auth_service,
        'User',
        SimpleNamespace(query=FakeQuery(user)),
    )
    monkeypatch.setattr(AuthService, '_serialize_user', staticmethod(lambda value: {'user_id': 1}))
    monkeypatch.setattr(auth_service, 'db', SimpleNamespace(session=FakeSession()))

    return user


def test_login_accepts_matching_identifier(login_context):
    result = AuthService.login_user('firebase-token', usn_or_employee_id='1KS23CS001')

    assert result['user'] == {'user_id': 1}


def test_login_rejects_mismatching_identifier(login_context):
    with pytest.raises(AuthServiceError) as error:
        AuthService.login_user('firebase-token', usn_or_employee_id='1KS23CS999')

    assert error.value.status_code == 401
    assert error.value.error_code == 'invalid_identifier'
    assert error.value.message == 'Invalid USN or employee ID.'


def test_login_normalizes_identifier(login_context):
    result = AuthService.login_user('firebase-token', usn_or_employee_id=' 1ks23cs001 ')

    assert result['user'] == {'user_id': 1}


def test_login_without_identifier_preserves_firebase_only_behavior(login_context):
    result = AuthService.login_user('firebase-token')

    assert result['user'] == {'user_id': 1}