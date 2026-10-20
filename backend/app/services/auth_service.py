"""Authentication service for CampusHive.

Firebase Authentication is the source of truth for identity. This service only
verifies Firebase ID tokens and syncs the authenticated user record to MySQL.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from flask import current_app
from PIL import Image
from werkzeug.utils import secure_filename

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

        # Public self-registration always creates the STUDENT role.
        requested_role = (
            role or AuthService._extract_claim_value(claims, 'role', 'user_role')
        )
        if requested_role:
            normalized_role = str(requested_role).strip().upper()
            if normalized_role != 'STUDENT':
                raise ValidationError(
                    'Self-registration is only allowed for the STUDENT role.'
                )
        resolved_role = 'STUDENT'

        resolved_organization_id = AuthService._resolve_organization_id(organization_id, claims)
        organization = Organization.query.filter_by(
            organization_id=resolved_organization_id
        ).first()
        if organization is None:
            raise ValidationError("Organization not found.")
        if not organization.is_active:
            raise ValidationError("Organization is inactive.")

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

        if resolved_academic_department_id is None:
            raise ValidationError("academic_department_id is required.")

        academic_department = AcademicDepartment.query.filter_by(
            academic_department_id=resolved_academic_department_id,
            organization_id=resolved_organization_id,
        ).first()

        if academic_department is None or not academic_department.is_active:
            raise ValidationError(
                "Academic department not found for this organization."
            )

        # Verify email belongs to organization if domain configured
        email_domain = email.split("@")[-1].lower()
        if organization.email_domain:
            if email_domain != organization.email_domain.lower():
                raise ValidationError(
                    f"Please register using your {organization.email_domain} email address."
                )

        resolved_department_id = None

        resolved_full_name = (
            full_name
            or AuthService._extract_claim_value(claims, 'name', 'full_name')
            or ''
        ).strip()
        if not resolved_full_name:
            raise ValidationError("Full name is required.")

        raw_identifier = (
            usn_or_employee_id
            or AuthService._extract_claim_value(
                claims,
                'usn_or_employee_id',
                'employee_id',
                'student_id',
            )
        )
        if not raw_identifier or not str(raw_identifier).strip():
            raise ValidationError("USN or student identifier is required.")
        resolved_usn_or_employee_id = str(raw_identifier).strip()

        # Check duplicate identifier within the organization
        duplicate_identifier = User.query.filter(
            User.organization_id == resolved_organization_id,
            db.func.lower(User.usn_or_employee_id) == resolved_usn_or_employee_id.lower(),
            User.firebase_uid != firebase_uid,
        ).first()
        if duplicate_identifier is not None:
            raise ConflictError("A user with this USN or student identifier already exists.")

        resolved_phone = phone or AuthService._extract_claim_value(claims, 'phone_number', 'phone')
        resolved_profile_image = profile_image or AuthService._extract_claim_value(claims, 'picture', 'profile_image')

        user = User.query.filter_by(firebase_uid=firebase_uid).first()

        if user is None:
            existing_email = User.query.filter(
                db.func.lower(User.email) == email.lower(),
            ).first()
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
            existing_email = User.query.filter(
                db.func.lower(User.email) == email.lower(),
                User.user_id != user.user_id,
            ).first()
            if existing_email is not None:
                raise ConflictError('A user with this email already exists.')

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
    def login_user(
        id_token: str,
        *,
        fcm_token: Optional[str] = None,
        usn_or_employee_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Authenticate an existing user using Firebase and sync login metadata."""

        claims = AuthService.verify_firebase_token(id_token)
        firebase_uid = claims['firebase_uid']

        user = User.query.filter_by(firebase_uid=firebase_uid).first()
        if user is None:
            raise NotFoundError('User not found for the provided Firebase identity.')

        if not user.is_active:
            raise AuthorizationError('User account is inactive.')

        if usn_or_employee_id is not None:
            stored_identifier = user.usn_or_employee_id
            if (
                stored_identifier is None
                or str(stored_identifier).strip().casefold()
                != str(usn_or_employee_id).strip().casefold()
            ):
                raise AuthenticationError(
                    'Invalid USN or employee ID.',
                    error_code='invalid_identifier',
                )

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

    @staticmethod
    def _is_safe_image_url(url: Optional[str]) -> bool:
        if not url or not isinstance(url, str):
            return False
        trimmed = url.strip()
        if not trimmed:
            return False
        if '..' in trimmed:
            return False
        if any(c in trimmed for c in ('\r', '\n', '\t', ' ')):
            return False
        lower_url = trimmed.lower()
        if lower_url.startswith(('javascript:', 'data:', 'vbscript:', 'file:', '//')):
            return False
        return True

    @staticmethod
    def update_profile(
        current_user: User,
        data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Update authenticated user's profile with approved editable fields.

        Permitted fields: 'full_name', 'phone', 'profile_image'.
        All other fields are rejected with ValidationError.
        """
        if current_user is None:
            raise AuthenticationError('User is not authenticated.')

        if not current_user.is_active:
            raise AuthorizationError('User account is inactive.')

        if not isinstance(data, dict):
            raise ValidationError('Request body must be a valid JSON object.')

        if not data:
            raise ValidationError('At least one profile field must be provided for update.')

        allowed_fields = {'full_name', 'phone', 'profile_image'}
        unsupported = set(data.keys()) - allowed_fields
        if unsupported:
            disallowed = sorted(list(unsupported))
            raise ValidationError(f"Field '{disallowed[0]}' cannot be modified.")

        if 'full_name' in data:
            full_name = data['full_name']
            if not isinstance(full_name, str):
                raise ValidationError('full_name must be a string.')
            trimmed_name = full_name.strip()
            if not trimmed_name:
                raise ValidationError('full_name cannot be empty.')
            if len(trimmed_name) > 100:
                raise ValidationError('full_name must be 100 characters or fewer.')
            current_user.full_name = trimmed_name

        if 'phone' in data:
            phone = data['phone']
            if phone is None:
                current_user.phone = None
            elif isinstance(phone, str):
                trimmed_phone = phone.strip()
                if not trimmed_phone:
                    current_user.phone = None
                elif len(trimmed_phone) > 15:
                    raise ValidationError('phone must be 15 characters or fewer.')
                else:
                    current_user.phone = trimmed_phone
            else:
                raise ValidationError('phone must be a string or null.')

        if 'profile_image' in data:
            profile_image = data['profile_image']
            if profile_image is None:
                current_user.profile_image = None
            elif isinstance(profile_image, str):
                trimmed_image = profile_image.strip()
                if not trimmed_image:
                    current_user.profile_image = None
                elif len(trimmed_image) > 255:
                    raise ValidationError('profile_image must be 255 characters or fewer.')
                elif not AuthService._is_safe_image_url(trimmed_image):
                    raise ValidationError('Invalid profile_image URL.')
                else:
                    current_user.profile_image = trimmed_image
            else:
                raise ValidationError('profile_image must be a string or null.')

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            raise AuthServiceError('Unable to update profile.') from exc

        return {
            'user': AuthService._serialize_user(current_user),
        }

    @staticmethod
    def _cleanup_old_profile_image(old_image_url: Optional[str], current_user_id: int) -> None:
        """Remove previous profile image file if internal, managed, and unreferenced."""
        if not old_image_url or not isinstance(old_image_url, str):
            return

        trimmed = old_image_url.strip()
        prefix = '/uploads/profile/'
        alt_prefix = 'uploads/profile/'

        if trimmed.startswith(prefix):
            filename = trimmed[len(prefix):]
        elif trimmed.startswith(alt_prefix):
            filename = trimmed[len(alt_prefix):]
        else:
            # External or from another module (complaints, lost_found, etc.) -> preserve
            return

        # Path traversal guard for extracted filename
        if not filename or '/' in filename or '\\' in filename or '..' in filename:
            current_app.logger.warning(f"Unsafe filename in old profile image path: {filename}")
            return

        # Check if another user references this image
        other = User.query.filter(
            User.user_id != current_user_id,
            User.profile_image == trimmed,
        ).first()
        if other is not None:
            current_app.logger.info(
                f"Skipping old profile image deletion; shared with user {other.user_id}"
            )
            return

        upload_folder = current_app.config.get('UPLOAD_FOLDER', './uploads')
        profile_dir = os.path.abspath(os.path.join(upload_folder, 'profile'))
        old_filepath = os.path.abspath(os.path.join(profile_dir, filename))

        if os.path.commonpath([old_filepath, profile_dir]) != profile_dir:
            current_app.logger.warning(f"Path traversal detected for old profile image: {old_filepath}")
            return

        try:
            if os.path.exists(old_filepath) and os.path.isfile(old_filepath):
                os.remove(old_filepath)
                current_app.logger.info(f"Cleaned up old profile image: {old_filepath}")
        except Exception as exc:
            current_app.logger.warning(f"Could not remove old profile image {old_filepath}: {exc}")

    @staticmethod
    def upload_profile_image(
        current_user: User,
        file: Any,
    ) -> Dict[str, Any]:
        """Upload and associate a new profile picture for the authenticated user."""
        if current_user is None:
            raise AuthenticationError('User is not authenticated.')

        if not current_user.is_active:
            raise AuthorizationError('User account is inactive.')

        if not file or not getattr(file, 'filename', None):
            raise ValidationError('No image selected.')

        filename = secure_filename(file.filename)
        ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
        allowed_extensions = {'jpg', 'jpeg', 'png', 'webp'}
        if ext not in allowed_extensions:
            allowed_list = sorted(list(allowed_extensions))
            raise ValidationError(
                f'File type not allowed. Allowed extensions: {", ".join(allowed_list)}'
            )

        client_mime = getattr(file, 'mimetype', None)
        allowed_mimetypes = {'image/jpeg', 'image/png', 'image/webp'}
        if client_mime and client_mime != 'application/octet-stream':
            if client_mime.lower() not in allowed_mimetypes:
                raise ValidationError('Invalid MIME type for image.')

        # 5 MB maximum size check
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)

        if file_size <= 0:
            raise ValidationError('File cannot be empty.')
        if file_size > 5 * 1024 * 1024:
            raise ValidationError('File size exceeds 5MB limit.')

        # Pillow image content verification
        try:
            img = Image.open(file.stream)
            img.verify()
            img_format = (img.format or '').upper()
        except Exception as exc:
            raise ValidationError('Invalid or corrupted image file.') from exc
        finally:
            file.seek(0)

        allowed_formats = {
            'JPEG': 'jpg',
            'PNG': 'png',
            'WEBP': 'webp',
        }
        if img_format not in allowed_formats:
            raise ValidationError(
                'Image format not supported. Supported formats: JPEG, PNG, WEBP'
            )

        canonical_ext = allowed_formats[img_format]
        upload_folder = os.path.abspath(current_app.config.get('UPLOAD_FOLDER', './uploads'))
        profile_dir = os.path.abspath(os.path.join(upload_folder, 'profile'))
        os.makedirs(profile_dir, exist_ok=True)

        new_filename = f"{uuid.uuid4().hex}.{canonical_ext}"
        filepath = os.path.abspath(os.path.join(profile_dir, new_filename))

        if os.path.commonpath([filepath, profile_dir]) != profile_dir:
            raise ValidationError('Invalid filename or path.')

        try:
            file.save(filepath)
        except Exception as exc:
            current_app.logger.exception('Failed to save profile image')
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                except Exception:
                    pass
            raise AuthServiceError('Failed to save image file.', status_code=500, error_code='server_error') from exc

        old_profile_image = current_user.profile_image
        new_image_url = f"/uploads/profile/{new_filename}"
        current_user.profile_image = new_image_url

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                except Exception:
                    pass
            raise AuthServiceError('Unable to update profile image in database.', status_code=500, error_code='server_error') from exc

        # Clean up old profile image if safe
        AuthService._cleanup_old_profile_image(old_profile_image, current_user.user_id)

        return {
            'user': AuthService._serialize_user(current_user),
            'image_url': new_image_url,
        }
