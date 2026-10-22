"""OTP generation, verification, and rate limiting service for CampusHive."""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple

import firebase_admin
from firebase_admin import auth as firebase_auth
from flask import current_app

from app.database import db
from app.models import AcademicDepartment, EmailVerification, Organization, User
from app.services.auth_service import (
    AuthConfigurationError,
    AuthService,
    AuthServiceError,
    ConflictError,
    ValidationError,
)
from app.services.email_service import EmailDeliveryError, EmailService


class RateLimitError(AuthServiceError):
    """Raised when rate limit is exceeded."""

    status_code = 429
    error_code = 'rate_limit_exceeded'


class CooldownError(AuthServiceError):
    """Raised when resend cooldown is active."""

    status_code = 429
    error_code = 'cooldown_active'


class OtpService:
    """Service managing email OTP generation, verification, and security controls."""

    OTP_EXPIRY_MINUTES = 5
    RESEND_COOLDOWN_SECONDS = 60
    MAX_ATTEMPTS = 3
    RATE_LIMIT_HOURLY = 5
    TOKEN_EXPIRY_MINUTES = 15

    EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    OTP_REGEX = re.compile(r'^\d{6}$')

    @staticmethod
    def _get_utc_now() -> datetime:
        """Return current time in UTC (naive for consistent DB storage/comparison)."""
        return datetime.now(timezone.utc).replace(tzinfo=None)

    @classmethod
    def generate_otp(cls) -> str:
        """Generate a cryptographically secure 6-digit numeric OTP."""
        return f"{secrets.randbelow(1000000):06d}"

    @classmethod
    def hash_otp(cls, otp: str) -> str:
        """Compute HMAC-SHA256 hash of the OTP using server secret key."""
        clean_otp = str(otp).strip()
        secret_key = (
            current_app.config.get('OTP_SECRET_KEY')
            or current_app.config.get('SECRET_KEY')
            or 'campushive-default-otp-secret-key'
        )
        return hmac.new(
            secret_key.encode('utf-8'),
            clean_otp.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()

    @classmethod
    def verify_otp_hash(cls, candidate_otp: str, stored_hash: str) -> bool:
        """Verify candidate OTP against stored HMAC hash using constant-time comparison."""
        computed_hash = cls.hash_otp(candidate_otp)
        return hmac.compare_digest(stored_hash, computed_hash)

    @classmethod
    def generate_verification_token(cls) -> Tuple[str, str]:
        """Generate a secure verification token and its SHA-256 hash.

        Returns: (raw_token, token_hash)
        """
        raw_token = secrets.token_urlsafe(32)
        token_hash = cls.hash_token(raw_token)
        return raw_token, token_hash

    @classmethod
    def hash_token(cls, raw_token: str) -> str:
        """Compute SHA-256 hash of a verification token."""
        clean_token = str(raw_token).strip()
        return hashlib.sha256(clean_token.encode('utf-8')).hexdigest()

    @classmethod
    def send_registration_otp(
        cls,
        *,
        email: str,
        organization_id: int,
        academic_department_id: int,
        usn_or_employee_id: str,
        ip_address: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Validate registration request and send secure email verification OTP.

        Enforces domain matching, duplicate checks (MySQL + Firebase),
        resend cooldown, and hourly rate limits.
        Never returns the OTP or prints it in logs.
        """
        # 1. Validate inputs
        if not email or not isinstance(email, str) or not email.strip():
            raise ValidationError('Email address is required.')

        normalized_email = email.strip().lower()
        if not cls.EMAIL_REGEX.match(normalized_email):
            raise ValidationError('Invalid email address format.')

        try:
            org_id = int(organization_id)
        except (TypeError, ValueError) as exc:
            raise ValidationError('organization_id must be an integer.') from exc

        try:
            dept_id = int(academic_department_id)
        except (TypeError, ValueError) as exc:
            raise ValidationError('academic_department_id must be an integer.') from exc

        clean_usn = str(usn_or_employee_id).strip() if usn_or_employee_id else ''
        if not clean_usn:
            raise ValidationError('USN or student identifier is required.')

        # 2. Validate organization
        organization = Organization.query.filter_by(organization_id=org_id).first()
        if organization is None:
            raise ValidationError('Organization not found.')
        if not organization.is_active:
            raise ValidationError('Organization is inactive.')

        # 3. Validate academic department
        academic_dept = AcademicDepartment.query.filter_by(
            academic_department_id=dept_id,
            organization_id=org_id,
        ).first()
        if academic_dept is None or not academic_dept.is_active:
            raise ValidationError('Academic department not found for this organization.')

        # 4. Validate email domain
        email_domain = normalized_email.split('@')[-1]
        if organization.email_domain:
            expected_domain = organization.email_domain.lower()
            if email_domain != expected_domain:
                raise ValidationError(
                    f'Please register using your {organization.email_domain} email address.'
                )

        # 5. Check duplicate email in MySQL
        existing_email_user = User.query.filter(
            db.func.lower(User.email) == normalized_email,
        ).first()
        if existing_email_user is not None:
            raise ConflictError('A user with this email address is already registered.')

        # 6. Check duplicate email in Firebase Authentication
        cls._verify_email_not_in_firebase(normalized_email)

        # 7. Check duplicate USN in organization
        duplicate_usn_user = User.query.filter(
            User.organization_id == org_id,
            db.func.lower(User.usn_or_employee_id) == clean_usn.lower(),
        ).first()
        if duplicate_usn_user is not None:
            raise ConflictError('A user with this USN or student identifier already exists.')

        # 8. Rate limiting (max 5 per hour per email/IP)
        now = cls._get_utc_now()
        one_hour_ago = now - timedelta(hours=1)

        email_count = EmailVerification.query.filter(
            db.func.lower(EmailVerification.email) == normalized_email,
            EmailVerification.created_at >= one_hour_ago,
        ).count()
        if email_count >= cls.RATE_LIMIT_HOURLY:
            raise RateLimitError('Too many verification requests for this email address. Please try again later.')

        if ip_address:
            ip_count = EmailVerification.query.filter(
                EmailVerification.ip_address == ip_address,
                EmailVerification.created_at >= one_hour_ago,
            ).count()
            if ip_count >= cls.RATE_LIMIT_HOURLY:
                raise RateLimitError('Too many verification requests from this network. Please try again later.')

        # 9. Resend cooldown (60s)
        most_recent = EmailVerification.query.filter(
            db.func.lower(EmailVerification.email) == normalized_email,
        ).order_by(EmailVerification.verification_id.desc()).first()

        if most_recent and most_recent.resend_available_at:
            resend_at = most_recent.resend_available_at
            if resend_at.tzinfo is not None:
                resend_at = resend_at.replace(tzinfo=None)
            if now < resend_at:
                remaining = int((resend_at - now).total_seconds()) + 1
                raise CooldownError(
                    f'Please wait {remaining} second(s) before requesting a new code.'
                )

        # 10. Invalidate any previous unverified OTPs for this email
        EmailVerification.query.filter(
            db.func.lower(EmailVerification.email) == normalized_email,
            EmailVerification.is_verified == False,
            EmailVerification.otp_expires_at > now,
        ).update(
            {'otp_expires_at': now},
            synchronize_session=False,
        )

        # 11. Generate secure OTP and HMAC-SHA256 hash
        otp = cls.generate_otp()
        otp_hash = cls.hash_otp(otp)

        otp_expires_at = now + timedelta(minutes=cls.OTP_EXPIRY_MINUTES)
        resend_available_at = now + timedelta(seconds=cls.RESEND_COOLDOWN_SECONDS)

        # 12. Persist EmailVerification record
        verification_record = EmailVerification(
            email=normalized_email,
            ip_address=ip_address,
            otp_hash=otp_hash,
            otp_expires_at=otp_expires_at,
            attempts_left=cls.MAX_ATTEMPTS,
            resend_available_at=resend_available_at,
            is_verified=False,
            organization_id=org_id,
            academic_department_id=dept_id,
            usn_or_employee_id=clean_usn,
        )
        db.session.add(verification_record)

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            current_app.logger.error(f"Failed to persist email verification record: {exc}")
            raise AuthServiceError('Unable to process verification request. Please try again.') from exc

        # 13. Send OTP email via EmailService
        try:
            EmailService.send_registration_otp_email(
                to_email=normalized_email,
                otp=otp,
                expires_in_minutes=cls.OTP_EXPIRY_MINUTES,
            )
        except EmailDeliveryError as exc:
            # Delete/rollback record if email fails to avoid blocking user resend
            try:
                db.session.delete(verification_record)
                db.session.commit()
            except Exception:
                db.session.rollback()
            raise AuthServiceError(
                'Failed to send verification email. Please check your email configuration.',
                error_code='email_delivery_failed',
                status_code=503,
            ) from exc

        current_app.logger.info(
            f"Registration OTP successfully dispatched to {normalized_email} (record_id={verification_record.verification_id})"
        )

        return {
            'email': normalized_email,
            'expires_in_seconds': cls.OTP_EXPIRY_MINUTES * 60,
            'resend_cooldown_seconds': cls.RESEND_COOLDOWN_SECONDS,
        }

    @classmethod
    def verify_registration_otp(
        cls,
        *,
        email: str,
        otp: str,
    ) -> Dict[str, Any]:
        """Verify the 6-digit OTP using constant-time comparison and issue verification token.

        Single-use, enforces attempt limits and expiration.
        """
        if not email or not isinstance(email, str) or not email.strip():
            raise ValidationError('Email address is required.')

        normalized_email = email.strip().lower()

        if not otp or not isinstance(otp, str):
            raise ValidationError('Verification code must be exactly 6 digits.', error_code='invalid_otp')

        clean_otp = otp.strip()
        if not cls.OTP_REGEX.match(clean_otp):
            raise ValidationError('Verification code must be exactly 6 digits.', error_code='invalid_otp')

        now = cls._get_utc_now()

        # Query active unverified record with row lock to prevent race conditions
        record = (
            EmailVerification.query.filter(
                db.func.lower(EmailVerification.email) == normalized_email,
                EmailVerification.is_verified == False,
                EmailVerification.is_consumed == False,
            )
            .order_by(EmailVerification.verification_id.desc())
            .with_for_update()
            .first()
        )

        if record is None:
            raise ValidationError(
                'No active verification code found for this email address. Please request a new code.',
                error_code='invalid_otp',
            )

        # Check expiration
        expires_at = record.otp_expires_at
        if expires_at.tzinfo is not None:
            expires_at = expires_at.replace(tzinfo=None)

        if now > expires_at:
            raise ValidationError(
                'Verification code has expired. Please request a new code.',
                error_code='otp_expired',
            )

        # Check attempts left
        if record.attempts_left <= 0:
            raise ValidationError(
                'Maximum verification attempts exceeded. Please request a new code.',
                error_code='attempts_exceeded',
            )

        # Constant-time comparison
        is_match = cls.verify_otp_hash(clean_otp, record.otp_hash)

        if not is_match:
            record.attempts_left -= 1
            try:
                db.session.commit()
            except Exception:
                db.session.rollback()

            if record.attempts_left <= 0:
                raise ValidationError(
                    'Maximum verification attempts exceeded. Please request a new code.',
                    error_code='attempts_exceeded',
                )
            raise ValidationError(
                f'Invalid verification code. {record.attempts_left} attempt(s) remaining.',
                error_code='invalid_otp',
            )

        # Success: mark OTP as verified and issue 15-minute verification token
        raw_token, token_hash = cls.generate_verification_token()
        token_expires_at = now + timedelta(minutes=cls.TOKEN_EXPIRY_MINUTES)

        record.is_verified = True
        record.verified_at = now
        record.verification_token_hash = token_hash
        record.token_expires_at = token_expires_at

        try:
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            current_app.logger.error(f"Failed to save verified token state: {exc}")
            raise AuthServiceError('Unable to complete verification. Please try again.') from exc

        current_app.logger.info(
            f"Email successfully verified for {normalized_email} (record_id={record.verification_id})"
        )

        return {
            'email': normalized_email,
            'verification_token': raw_token,
            'expires_in_seconds': cls.TOKEN_EXPIRY_MINUTES * 60,
        }

    @classmethod
    def validate_and_consume_token(
        cls,
        *,
        verification_token: str,
        expected_email: str,
        organization_id: int,
        academic_department_id: int,
        usn_or_employee_id: str,
    ) -> EmailVerification:
        """Validate verification token against stored hash, expiry, email, and pending data.

        Atomically consumes the token so it cannot be reused.
        """
        if not verification_token or not str(verification_token).strip():
            raise ValidationError(
                'Email verification token is required for student registration.',
                error_code='missing_verification_token',
            )

        clean_token = str(verification_token).strip()
        token_hash = cls.hash_token(clean_token)
        now = cls._get_utc_now()

        # Query token with row lock to ensure single-use atomic consumption
        record = (
            EmailVerification.query.filter(
                EmailVerification.verification_token_hash == token_hash,
            )
            .with_for_update()
            .first()
        )

        if record is None or not record.is_verified or record.is_consumed:
            raise ValidationError(
                'Invalid or already used email verification token.',
                error_code='invalid_verification_token',
            )

        # Check expiry
        token_expires_at = record.token_expires_at
        if token_expires_at and token_expires_at.tzinfo is not None:
            token_expires_at = token_expires_at.replace(tzinfo=None)

        if token_expires_at and now > token_expires_at:
            raise ValidationError(
                'Email verification token has expired. Please verify your email again.',
                error_code='verification_token_expired',
            )

        # Validate email match
        if record.email.lower() != expected_email.strip().lower():
            raise ValidationError(
                'Email address does not match the verified email token.',
                error_code='email_mismatch',
            )

        # Anti-tampering: validate organization, academic department, and USN match
        if record.organization_id != organization_id:
            raise ValidationError(
                'Organization does not match the verified registration request.',
                error_code='data_tampered',
            )

        if record.academic_department_id != academic_department_id:
            raise ValidationError(
                'Academic department does not match the verified registration request.',
                error_code='data_tampered',
            )

        if record.usn_or_employee_id.strip().lower() != usn_or_employee_id.strip().lower():
            raise ValidationError(
                'USN or student identifier does not match the verified registration request.',
                error_code='data_tampered',
            )

        # Atomically consume token
        record.is_consumed = True
        record.consumed_at = now

        return record

    @classmethod
    def _verify_email_not_in_firebase(cls, email: str) -> None:
        """Check if email is already registered in Firebase Authentication."""
        try:
            AuthService._ensure_firebase_app()
            existing_user = firebase_auth.get_user_by_email(email)
            if existing_user:
                raise ConflictError('An account with this email address already exists.')
        except firebase_auth.UserNotFoundError:
            # User does NOT exist in Firebase, proceed
            pass
        except ConflictError:
            raise
        except (AuthConfigurationError, ValueError):
            # In test environments without Firebase credentials, allow tests to proceed
            if not current_app.config.get('TESTING'):
                raise
        except Exception as exc:
            # If Firebase throws another unexpected exception, check if UserNotFoundError is wrapped
            if 'USER_NOT_FOUND' in str(exc) or 'No user record found' in str(exc):
                return
            current_app.logger.warning(f"Firebase email lookup exception: {exc}")
            if not current_app.config.get('TESTING'):
                raise
