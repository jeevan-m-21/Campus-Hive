"""Authentication service for CampusHive.

Firebase Authentication is the source of truth for identity. This service only
verifies Firebase ID tokens and syncs the authenticated user record to MySQL.
"""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any, Dict, Optional

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from flask import current_app

from app.database import db
from app.models import User, Organization, Department, AcademicDepartment


class AuthServiceError(Exception):
    """Base exception for auth service failures."""

    status_code = 400
    error_code = 'auth_service_error'

    def __init__(self, message: str, *, error_code: Optional[str] = None, status_code: Optional[int] = None):
        super().__init__(message)
        self.message = message
        if error_code is not None:
            self.error_code = error_code
        if status_code is not None:
            self.status_code = status_code

    def to_dict(self) -> Dict[str, Any]:
        return {
            'error': self.error_code,
            'message': self.message,
            'status_code': self.status_code,
        }


class AuthConfigurationError(AuthServiceError):
    status_code = 500
    error_code = 'auth_configuration_error'


class AuthenticationError(AuthServiceError):
    status_code = 401
    error_code = 'authentication_error'


class AuthorizationError(AuthServiceError):
    status_code = 403
    error_code = 'authorization_error'


class NotFoundError(AuthServiceError):
    status_code = 404
    error_code = 'not_found'


class ConflictError(AuthServiceError):
    status_code = 409
    error_code = 'conflict'


class ValidationError(AuthServiceError):
    status_code = 400
    error_code = 'validation_error'


class AuthService:
    """Firebase-backed auth workflow for CampusHive users."""

    @staticmethod
    def _ensure_firebase_app() -> None:
        """Initialize Firebase Admin once for the current process."""

        try:
            firebase_admin.get_app()
            return
        except ValueError:
            pass

        credentials_path = current_app.config.get("FIREBASE_CREDENTIALS_PATH")

        if not credentials_path:
            raise AuthConfigurationError(
                "Firebase credentials path is not configured."
            )

        credentials_path = os.path.abspath(credentials_path)

        if not os.path.exists(credentials_path):
            raise AuthConfigurationError(
                f"Firebase credentials file not found: {credentials_path}"
            )

        cred = credentials.Certificate(credentials_path)
        firebase_admin.initialize_app(cred)

    @staticmethod
    def _normalize_role(role: Optional[str]) -> str:
        if not role:
            return 'STUDENT'

        normalized_role = str(role).strip().upper()
        allowed_roles = {'SUPER_ADMIN', 'ORG_ADMIN', 'SUPERVISOR', 'STUDENT'}
        if normalized_role not in allowed_roles:
            raise ValidationError(f'Invalid role: {role}')
        return normalized_role

    @staticmethod
    def _extract_claim_value(claims: Dict[str, Any], *keys: str) -> Any:
        for key in keys:
            value = claims.get(key)
            if value not in (None, ''):
                return value
        return None

    @staticmethod
    def _resolve_organization_id(organization_id: Optional[int], claims: Dict[str, Any]) -> int:
        candidate = organization_id
        if candidate in (None, ''):
            candidate = AuthService._extract_claim_value(
                claims,
                'organization_id',
                'organizationId',
                'org_id',
                'orgId',
            )

        if candidate in (None, ''):
            raise ValidationError('organization_id is required.')

        try:
            return int(candidate)
        except (TypeError, ValueError) as exc:
            raise ValidationError('organization_id must be an integer.') from exc

    @staticmethod
    def _resolve_department_id(department_id: Optional[int], claims: Dict[str, Any]) -> Optional[int]:
        candidate = department_id
        if candidate in (None, ''):
            candidate = AuthService._extract_claim_value(
                claims,
                'department_id',
                'departmentId',
            )

        if candidate in (None, ''):
            return None

        try:
            return int(candidate)
        except (TypeError, ValueError) as exc:
            raise ValidationError('department_id must be an integer.') from exc

    @staticmethod
    def _serialize_user(user: User) -> Dict[str, Any]:
        return {
            'user_id': user.user_id,
            'organization_id': user.organization_id,
            'department_id': user.department_id,
            'academic_department_id': user.academic_department_id,
            'academic_department_name': (
                user.academic_department.department_name
                if user.academic_department
                else None
            ),
            'full_name': user.full_name,
            'usn_or_employee_id': user.usn_or_employee_id,
            'email': user.email,
            'firebase_uid': user.firebase_uid,
            'phone': user.phone,
            'role': user.role,
            'profile_image': user.profile_image,
            'is_active': bool(user.is_active),
            'fcm_token': user.fcm_token,
            'last_login': user.last_login.isoformat() if user.last_login else None,
            'created_at': user.created_at.isoformat() if user.created_at else None,
        }

    @staticmethod
    def verify_firebase_token(id_token: str) -> Dict[str, Any]:
        """Verify a Firebase ID token and return decoded claims."""

        if not id_token:
            raise ValidationError('id_token is required.')

        AuthService._ensure_firebase_app()

        try:
            decoded_token = firebase_auth.verify_id_token(id_token, check_revoked=True)
        except firebase_auth.RevokedIdTokenError as exc:
            raise AuthenticationError('Firebase token has been revoked.') from exc
        except firebase_auth.ExpiredIdTokenError as exc:
            raise AuthenticationError('Firebase token has expired.') from exc
        except firebase_auth.InvalidIdTokenError as exc:
            raise AuthenticationError('Firebase token is invalid.') from exc
        except Exception as exc:  # pragma: no cover - defensive catch for SDK/runtime failures
            raise AuthenticationError('Unable to verify Firebase token.') from exc

        firebase_uid = decoded_token.get('uid') or decoded_token.get('sub')
        if not firebase_uid:
            raise AuthenticationError('Firebase token did not contain a uid.')

        decoded_token['firebase_uid'] = firebase_uid
        return decoded_token

    @staticmethod
    def register_user(
        id_token: str,
        *,
        organization_id: Optional[int] = None,
        academic_department_id: Optional[int] = None,
        department_id: Optional[int] = None,
        role: Optional[str] = None,
        full_name: Optional[str] = None,
        usn_or_employee_id: Optional[str] = None,
        phone: Optional[str] = None,
        profile_image: Optional[str] = None,
        fcm_token: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create or update the user record after Firebase registration."""

        claims = AuthService.verify_firebase_token(id_token)
        firebase_uid = claims['firebase_uid']

        email = AuthService._extract_claim_value(claims, 'email')

        if not email:
            raise ValidationError("Firebase token does not contain an email address.")

        resolved_organization_id = AuthService._resolve_organization_id(organization_id, claims)
        try:
            resolved_academic_department_id = (
                int(academic_department_id)
                if academic_department_id not in (None, "")
                else None
            )
        except (TypeError, ValueError):
            raise ValidationError(
                "academic_department_id must be an integer."
            )
        resolved_department_id = AuthService._resolve_department_id(department_id, claims)
        resolved_role = AuthService._normalize_role(role or AuthService._extract_claim_value(claims, 'role', 'user_role'))
        
        organization = Organization.query.filter_by(
            organization_id=resolved_organization_id
        ).first()
        if organization is None:
            raise ValidationError("Organization not found.")
        
        if resolved_academic_department_id is not None:
            academic_department = AcademicDepartment.query.filter_by(
                academic_department_id=resolved_academic_department_id,
                organization_id=resolved_organization_id,
            ).first()

            if academic_department is None:
                raise ValidationError(
                    "Academic department not found for this organization."
                )
        # Verify email belongs to organization
        email_domain = email.split("@")[-1].lower()

        if organization.email_domain:
            if email_domain != organization.email_domain.lower():
                raise ValidationError(
                    f"Please register using your {organization.email_domain} email address."
                )

        if resolved_department_id is not None:
            department = Department.query.filter_by(
                department_id=resolved_department_id,
                organization_id=resolved_organization_id
            ).first()
        
            if department is None:
                raise ValidationError("Department not found for this organization.")
        
        resolved_full_name = full_name or AuthService._extract_claim_value(claims, 'name', 'full_name') or email
        resolved_usn_or_employee_id = usn_or_employee_id or AuthService._extract_claim_value(
            claims,
            'usn_or_employee_id',
            'employee_id',
            'student_id',
        )
        resolved_phone = phone or AuthService._extract_claim_value(claims, 'phone_number', 'phone')
        resolved_profile_image = profile_image or AuthService._extract_claim_value(claims, 'picture', 'profile_image')

        user = User.query.filter_by(firebase_uid=firebase_uid).first()

        if user is None:
            existing_email = User.query.filter_by(email=email).first()
            if existing_email is not None:
                raise ConflictError('A user with this email already exists.')

            user = User(
                organization_id=resolved_organization_id,
                academic_department_id=resolved_academic_department_id,
                department_id=resolved_department_id,
                full_name=resolved_full_name,
                usn_or_employee_id=resolved_usn_or_employee_id,
                email=email,
                firebase_uid=firebase_uid,
                phone=resolved_phone,
                role=resolved_role,
                profile_image=resolved_profile_image,
                fcm_token=fcm_token,
            )
            db.session.add(user)
        else:
            user.organization_id = resolved_organization_id
            user.academic_department_id = resolved_academic_department_id
            user.department_id = resolved_department_id
            user.full_name = resolved_full_name
            user.usn_or_employee_id = resolved_usn_or_employee_id
            user.email = email
            user.phone = resolved_phone
            user.role = resolved_role
            user.profile_image = resolved_profile_image
            if fcm_token is not None:
                user.fcm_token = fcm_token

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            raise AuthServiceError('Unable to persist registered user.') from exc

        return {
            'user': AuthService._serialize_user(user),
            'firebase_claims': claims,
        }

    @staticmethod
    def login_user(id_token: str, *, fcm_token: Optional[str] = None) -> Dict[str, Any]:
        """Authenticate an existing user using Firebase and sync login metadata."""

        claims = AuthService.verify_firebase_token(id_token)
        firebase_uid = claims['firebase_uid']

        user = User.query.filter_by(firebase_uid=firebase_uid).first()
        if user is None:
            raise NotFoundError('User not found for the provided Firebase identity.')

        if not user.is_active:
            raise AuthorizationError('User account is inactive.')

        user.last_login = datetime.utcnow()
        if fcm_token is not None:
            user.fcm_token = fcm_token

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            raise AuthServiceError('Unable to update login metadata.') from exc

        return {
            'user': AuthService._serialize_user(user),
            'firebase_claims': claims,
        }

    @staticmethod
    def get_current_user(
        *,
        id_token: Optional[str] = None,
        firebase_uid: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Resolve the current user from a Firebase token or uid."""

        resolved_uid = firebase_uid
        claims: Dict[str, Any] = {}

        if id_token:
            claims = AuthService.verify_firebase_token(id_token)
            resolved_uid = claims['firebase_uid']

        if not resolved_uid:
            raise ValidationError('firebase_uid or id_token is required.')

        user = User.query.filter_by(firebase_uid=resolved_uid).first()
        if user is None:
            raise NotFoundError('User not found.')

        if not user.is_active:
            raise AuthorizationError('User account is inactive.')

        return {
            'user': AuthService._serialize_user(user),
            'firebase_claims': claims or None,
        }

    @staticmethod
    def update_fcm_token(
        *,
        fcm_token: str,
        firebase_uid: Optional[str] = None,
        user_id: Optional[int] = None,
        id_token: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Update the user's FCM token."""

        if not fcm_token:
            raise ValidationError('fcm_token is required.')

        resolved_uid = firebase_uid
        if id_token:
            claims = AuthService.verify_firebase_token(id_token)
            resolved_uid = claims['firebase_uid']

        query = User.query
        if resolved_uid:
            user = query.filter_by(firebase_uid=resolved_uid).first()
        elif user_id is not None:
            user = query.filter_by(user_id=user_id).first()
        else:
            raise ValidationError('firebase_uid, user_id, or id_token is required.')

        if user is None:
            raise NotFoundError('User not found.')

        user.fcm_token = fcm_token

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            raise AuthServiceError('Unable to update FCM token.') from exc

        return {
            'user': AuthService._serialize_user(user),
        }
