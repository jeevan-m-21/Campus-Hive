"""
Amazon S3 Storage Service for CampusHive.
Handles file uploads, streaming retrieval, presigned URL generation,
and object deletions using Boto3 and the EC2 IAM role.
"""

import os
import logging
from typing import Any, Dict, Optional
from urllib.parse import urlparse

import boto3
from botocore.exceptions import ClientError
from flask import current_app, has_app_context

logger = logging.getLogger(__name__)


class S3ServiceError(Exception):
    """Custom exception for S3 service failures."""

    def __init__(self, message: str, status_code: int = 500, original_error: Optional[Exception] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.original_error = original_error


class S3Service:
    """Reusable service for interacting with Amazon S3."""

    _client = None

    @classmethod
    def get_client(cls):
        """
        Get or initialize the Boto3 S3 client.
        Uses the EC2 IAM role and standard AWS credential chain.
        Never requires or expects hardcoded credentials.
        """
        if cls._client is not None:
            return cls._client

        region = 'ap-south-1'
        if has_app_context():
            region = current_app.config.get('AWS_REGION', region)
        cls._client = boto3.client('s3', region_name=region)
        return cls._client

    @classmethod
    def set_client(cls, client):
        """Set a custom or mocked Boto3 client (useful for automated tests)."""
        cls._client = client

    @classmethod
    def is_enabled(cls) -> bool:
        """Check if S3 storage is enabled and configured."""
        if not has_app_context():
            return False
        enabled = current_app.config.get('S3_STORAGE_ENABLED', True)
        bucket = current_app.config.get('S3_BUCKET_NAME')
        return bool(enabled and bucket)

    @classmethod
    def get_bucket(cls) -> str:
        """Get the configured S3 bucket name."""
        bucket = 'campushive-media-2026'
        if has_app_context():
            bucket = current_app.config.get('S3_BUCKET_NAME', bucket)
        if not bucket:
            raise S3ServiceError('S3 bucket name is not configured.')
        return bucket

    @classmethod
    def is_bucket_url(cls, url: str) -> bool:
        """Check if an HTTP/HTTPS URL points to the configured S3 bucket."""
        if not url or not isinstance(url, str):
            return False
        trimmed = url.strip()
        if not trimmed.startswith(('http://', 'https://')):
            return False

        bucket = cls.get_bucket() if has_app_context() else 'campushive-media-2026'
        region = 'ap-south-1'
        if has_app_context():
            region = current_app.config.get('AWS_REGION', region)

        parsed = urlparse(trimmed)
        netloc = (parsed.netloc or '').lower()
        path = parsed.path or ''

        # Virtual-hosted style: <bucket>.s3.<region>.amazonaws.com or <bucket>.s3.amazonaws.com
        if netloc in (
            f"{bucket.lower()}.s3.{region.lower()}.amazonaws.com",
            f"{bucket.lower()}.s3.amazonaws.com",
            f"{bucket.lower()}.s3-control.{region.lower()}.amazonaws.com",
        ):
            return True

        # Path style: s3.<region>.amazonaws.com/<bucket>/... or s3.amazonaws.com/<bucket>/...
        if netloc in (
            's3.amazonaws.com',
            f"s3.{region.lower()}.amazonaws.com",
            f"s3-{region.lower()}.amazonaws.com",
        ):
            path_parts = [p for p in path.split('/') if p]
            if path_parts and path_parts[0].lower() == bucket.lower():
                return True

        return False

    @classmethod
    def normalize_key(cls, path_or_url: str) -> str:
        """
        Convert a URL or relative path into an S3 object key.

        Examples:
            '/uploads/complaints/abc.jpg' -> 'complaints/abc.jpg'
            'uploads/lost_found/def.png'  -> 'lost_found/def.png'
            'profile/xyz.webp'            -> 'profile/xyz.webp'
            'https://bucket.s3.amazonaws.com/profile/xyz.webp' -> 'profile/xyz.webp'
        """
        if not path_or_url or not isinstance(path_or_url, str):
            return ''

        trimmed = path_or_url.strip()
        if not trimmed:
            return ''

        # Reject null bytes
        if '\x00' in trimmed:
            raise S3ServiceError('Invalid file key: null bytes detected.', status_code=400)

        # Handle full URLs: only allow URLs belonging to our configured S3 bucket
        if trimmed.startswith(('http://', 'https://')):
            if not cls.is_bucket_url(trimmed):
                raise S3ServiceError('External URLs cannot be converted to S3 keys.', status_code=400)
            parsed = urlparse(trimmed)
            trimmed = parsed.path
            bucket = cls.get_bucket() if has_app_context() else 'campushive-media-2026'
            if trimmed.startswith(f"/{bucket}/"):
                trimmed = trimmed[len(f"/{bucket}/"):]
            elif trimmed.startswith(f"{bucket}/"):
                trimmed = trimmed[len(f"{bucket}/"):]

        # Decode URL percent-encoding to catch encoded traversal (e.g. %2e%2e)
        import urllib.parse
        unquoted = urllib.parse.unquote(trimmed)

        # Reject backslashes
        if '\\' in unquoted:
            raise S3ServiceError('Invalid file key: path traversal detected.', status_code=400)

        # Strip leading slashes
        clean_path = unquoted.lstrip('/')

        # Strip standard '/uploads/' or 'uploads/' prefix
        if clean_path.startswith('uploads/'):
            clean_path = clean_path[len('uploads/'):]

        # Security check: disallow path traversal in S3 keys
        parts = [p for p in clean_path.split('/') if p]
        if any(part in ('..', '.') for part in parts):
            raise S3ServiceError('Invalid file key: path traversal detected.', status_code=400)

        clean_path = '/'.join(parts)

        # Prepend optional S3 key prefix if configured
        prefix = ''
        if has_app_context():
            prefix = current_app.config.get('S3_KEY_PREFIX', '').strip().strip('/')
        if prefix:
            return f"{prefix}/{clean_path}"

        return clean_path

    @classmethod
    def upload_file(
        cls,
        file_obj: Any,
        key: str,
        content_type: Optional[str] = None,
        metadata: Optional[Dict[str, str]] = None,
    ) -> str:
        """
        Upload a file-like object to the configured S3 bucket.
        The S3 bucket remains strictly private (no public ACLs).

        Args:
            file_obj: A file-like object, BytesIO, or FileStorage.
            key: Target path/key (e.g. 'complaints/<uuid>.jpg').
            content_type: MIME type of the file.
            metadata: Optional user metadata dictionary.

        Returns:
            The canonical relative image URL (e.g. '/uploads/complaints/<uuid>.jpg').
        """
        client = cls.get_client()
        bucket = cls.get_bucket()
        s3_key = cls.normalize_key(key)

        if not s3_key:
            raise S3ServiceError('Target S3 key cannot be empty.', status_code=400)

        extra_args: Dict[str, Any] = {}
        if content_type:
            extra_args['ContentType'] = content_type
        if metadata:
            extra_args['Metadata'] = metadata

        try:
            if hasattr(file_obj, 'seek'):
                file_obj.seek(0)

            client.upload_fileobj(
                file_obj,
                bucket,
                s3_key,
                ExtraArgs=extra_args if extra_args else None,
            )

            logger.info(f"Successfully uploaded to S3: s3://{bucket}/{s3_key}")
        except Exception as exc:
            logger.exception(f"Failed to upload {s3_key} to S3 bucket {bucket}: {exc}")
            raise S3ServiceError(f"Failed to upload file to S3: {str(exc)}", original_error=exc) from exc

        # Return the application relative URL (/uploads/<clean_path>)
        # This keeps database schemas and Flutter resolveImageUrl 100% compatible.
        prefix = ''
        if has_app_context():
            prefix = current_app.config.get('S3_KEY_PREFIX', '').strip().strip('/')
        relative_path = s3_key
        if prefix and relative_path.startswith(f"{prefix}/"):
            relative_path = relative_path[len(f"{prefix}/"):]

        return f"/uploads/{relative_path}"

    @classmethod
    def get_file_stream(cls, path_or_url: str) -> Dict[str, Any]:
        """
        Fetch an object stream and metadata from S3.

        Returns:
            dict containing:
                'body': botocore StreamingBody
                'content_type': MIME type string
                'content_length': size in bytes (int)
                'etag': ETag string
                'last_modified': datetime
        """
        client = cls.get_client()
        bucket = cls.get_bucket()
        s3_key = cls.normalize_key(path_or_url)

        if not s3_key:
            raise S3ServiceError('File path is required.', status_code=400)

        try:
            response = client.get_object(Bucket=bucket, Key=s3_key)
            return {
                'body': response['Body'],
                'content_type': response.get('ContentType', 'application/octet-stream'),
                'content_length': response.get('ContentLength'),
                'etag': response.get('ETag', ''),
                'last_modified': response.get('LastModified'),
            }
        except ClientError as exc:
            error_code = exc.response.get('Error', {}).get('Code', '')
            if error_code in ('NoSuchKey', '404'):
                raise S3ServiceError(f"Object not found in S3: {s3_key}", status_code=404, original_error=exc) from exc
            if error_code in ('AccessDenied', '403'):
                logger.error(f"S3 access denied for key {s3_key}")
                raise S3ServiceError("Access to S3 object was denied.", status_code=500, original_error=exc) from exc
            logger.error(f"S3 get_object failed for {s3_key}: {error_code}")
            raise S3ServiceError("Failed to retrieve file from S3.", status_code=500, original_error=exc) from exc
        except S3ServiceError:
            raise
        except Exception as exc:
            logger.error(f"Unexpected error getting {s3_key} from S3: {type(exc).__name__}")
            raise S3ServiceError("Failed to retrieve file from S3.", status_code=500, original_error=exc) from exc

    @classmethod
    def generate_presigned_url(cls, path_or_url: str, expiration: Optional[int] = None) -> str:
        """
        Generate a secure, time-limited presigned GET URL for an S3 object.

        Args:
            path_or_url: The path or key of the object.
            expiration: Expiration in seconds (defaults to config S3_PRESIGNED_EXPIRES or 3600).

        Returns:
            Presigned HTTPS URL string.
        """
        client = cls.get_client()
        bucket = cls.get_bucket()
        s3_key = cls.normalize_key(path_or_url)

        if not s3_key:
            raise S3ServiceError('File path is required.', status_code=400)

        expires_in = expiration
        if expires_in is None:
            expires_in = 3600
            if has_app_context():
                expires_in = current_app.config.get('S3_PRESIGNED_EXPIRES', 3600)

        try:
            url = client.generate_presigned_url(
                'get_object',
                Params={'Bucket': bucket, 'Key': s3_key},
                ExpiresIn=expires_in,
            )
            return url
        except Exception as exc:
            logger.exception(f"Failed to generate presigned URL for {s3_key}: {exc}")
            raise S3ServiceError(f"Failed to generate presigned URL: {str(exc)}", original_error=exc) from exc

    @classmethod
    def delete_file(cls, path_or_url: str) -> bool:
        """
        Delete an object from S3.

        Args:
            path_or_url: The path, URL, or key of the object to delete.

        Returns:
            True if deletion succeeded or was a no-op, False on error.
        """
        if not path_or_url or not isinstance(path_or_url, str):
            return False

        trimmed = path_or_url.strip()
        if not trimmed:
            return False

        # External URLs not belonging to our bucket are safely preserved as a no-op
        if trimmed.startswith(('http://', 'https://')):
            if not cls.is_bucket_url(trimmed):
                return True

        try:
            s3_key = cls.normalize_key(trimmed)
        except S3ServiceError:
            return False

        if not s3_key:
            return False

        client = cls.get_client()
        bucket = cls.get_bucket()

        try:
            client.delete_object(Bucket=bucket, Key=s3_key)
            logger.info(f"Successfully deleted from S3: s3://{bucket}/{s3_key}")
            return True
        except ClientError as exc:
            error_code = exc.response.get('Error', {}).get('Code', '')
            if error_code in ('NoSuchKey', '404'):
                logger.info(f"Object {s3_key} already absent from S3.")
                return True
            logger.warning(f"Could not delete {s3_key} from S3 bucket {bucket}: {error_code}")
            return False
        except Exception as exc:
            logger.warning(f"Unexpected error deleting {s3_key} from S3: {type(exc).__name__}")
            return False

    @classmethod
    def file_exists(cls, path_or_url: str) -> bool:
        """Check if an object exists in S3."""
        s3_key = cls.normalize_key(path_or_url)
        if not s3_key:
            return False

        client = cls.get_client()
        bucket = cls.get_bucket()

        try:
            client.head_object(Bucket=bucket, Key=s3_key)
            return True
        except ClientError:
            return False
        except Exception:
            return False
