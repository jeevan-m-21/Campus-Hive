"""Firebase authentication middleware for CampusHive.

This module authenticates requests using Firebase ID tokens, loads the
corresponding user from MySQL, and exposes decorators for login and role
protection.
"""

from functools import wraps
from typing import Callable, Iterable, Optional, TypeVar

from flask import current_app, g, jsonify, request

from app.models import User
from app.services.auth_service import AuthService, AuthServiceError


F = TypeVar('F', bound=Callable)


def _json_error(message: str, status_code: int, error: str = 'error'):
	"""Return a compact JSON error response."""

	response = jsonify({'success': False, 'error': error, 'message': message})
	return response, status_code


def _extract_bearer_token() -> str:
	"""Extract the Firebase ID token from the Authorization header."""

	authorization_header = request.headers.get('Authorization', '')
	if not authorization_header:
		raise AuthServiceError('Missing Authorization header.', status_code=401, error_code='missing_token')

	scheme, _, token = authorization_header.partition(' ')
	if scheme.lower() != 'bearer' or not token.strip():
		raise AuthServiceError('Invalid Authorization header format.', status_code=401, error_code='invalid_token')

	return token.strip()


def _load_current_user(firebase_uid: str) -> User:
	"""Fetch the active user for the verified Firebase identity."""

	user = User.query.filter_by(firebase_uid=firebase_uid).first()
	if user is None:
		raise AuthServiceError('User not found.', status_code=401, error_code='user_not_found')

	if not user.is_active:
		raise AuthServiceError('User is inactive.', status_code=403, error_code='user_inactive')

	return user


def _authenticate_request() -> User:
	"""Authenticate the request and store the current user in flask.g."""

	token = _extract_bearer_token()

	try:
		claims = AuthService.verify_firebase_token(token)
		firebase_uid = claims.get('firebase_uid')
		if not firebase_uid:
			raise AuthServiceError('Firebase token did not include a firebase_uid.', status_code=401, error_code='invalid_token')

		user = _load_current_user(firebase_uid)
	except AuthServiceError:
		raise
	except Exception as exc:  # pragma: no cover - defensive guard for unexpected runtime failures
		current_app.logger.exception('Unexpected Firebase authentication failure')
		raise AuthServiceError('Authentication failed.', status_code=401, error_code='authentication_failed') from exc

	g.current_user = user
	g.firebase_claims = claims
	return user


def firebase_login_required(fn: F) -> F:
	"""Require a valid Firebase login for the wrapped endpoint."""

	@wraps(fn)
	def wrapper(*args, **kwargs):
		try:
			_authenticate_request()
		except AuthServiceError as exc:
			return _json_error(exc.message, exc.status_code, exc.error_code)

		return fn(*args, **kwargs)

	return wrapper  # type: ignore[return-value]


def role_required(*roles: str):
	"""Require the current user to have one of the allowed roles."""

	allowed_roles = {role.upper() for role in roles if role}

	def decorator(fn: F) -> F:
		@wraps(fn)
		def wrapper(*args, **kwargs):
			try:
				user = _authenticate_request()
			except AuthServiceError as exc:
				return _json_error(exc.message, exc.status_code, exc.error_code)

			if allowed_roles and user.role.upper() not in allowed_roles:
				return _json_error(
					'You do not have permission to access this resource.',
					403,
					'forbidden',
				)

			return fn(*args, **kwargs)

		return wrapper  # type: ignore[return-value]

	return decorator
