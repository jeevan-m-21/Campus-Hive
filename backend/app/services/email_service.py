"""Email service for CampusHive.

Handles sending transactional and verification emails via SMTP.
Credentials and server configuration are loaded strictly from environment/Flask config.
Never logs credentials or OTP values.
"""

from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Any, Dict, List, Optional

from flask import current_app


def _sanitize_smtp_error(error_val: Any) -> Optional[str]:
    """Sanitize SMTP server response message for safe logging.

    Ensures no sensitive data is leaked and formats bytes/strings cleanly.
    """
    if error_val is None:
        return None
    if isinstance(error_val, bytes):
        try:
            error_val = error_val.decode("utf-8", errors="replace")
        except Exception:
            error_val = str(error_val)
    text = " ".join(str(error_val).split())
    if len(text) > 200:
        return text[:197] + "..."
    return text


class EmailDeliveryError(Exception):
    """Raised when an email cannot be delivered via SMTP."""

    def __init__(self, message: str, original_exception: Optional[Exception] = None):
        super().__init__(message)
        self.message = message
        self.original_exception = original_exception


class EmailService:
    """Service for sending application emails."""

    # In-memory outbox used for testing and assertions
    outbox: List[Dict[str, Any]] = []

    @classmethod
    def clear_outbox(cls) -> None:
        """Clear captured test emails."""
        cls.outbox.clear()

    @classmethod
    def send_registration_otp_email(
        cls,
        to_email: str,
        otp: str,
        *,
        expires_in_minutes: int = 5,
    ) -> bool:
        """Send a professionally formatted registration OTP email.

        Never logs the OTP value or email credentials.
        """
        subject = f"CampusHive - Verification Code: {otp[:2]}****"
        actual_subject = "CampusHive - Your Registration Verification Code"

        text_content = (
            f"Welcome to CampusHive!\n\n"
            f"Your registration verification code is: {otp}\n\n"
            f"This code is valid for {expires_in_minutes} minutes and can only be used once.\n\n"
            f"If you did not request this verification code, please ignore this email.\n\n"
            f"Best regards,\n"
            f"The CampusHive Team\n"
        )

        html_content = cls._build_otp_html_template(otp, expires_in_minutes)

        return cls.send_email(
            to_email=to_email,
            subject=actual_subject,
            text_body=text_content,
            html_body=html_content,
        )

    @classmethod
    def send_email(
        cls,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: Optional[str] = None,
    ) -> bool:
        """Send a multipart email via SMTP or record in memory if in testing."""
        config = current_app.config

        # In testing mode or when locmem backend is specified, capture email in outbox
        if config.get("TESTING") or config.get("MAIL_BACKEND") == "locmem":
            cls.outbox.append(
                {
                    "to": to_email,
                    "subject": subject,
                    "text_body": text_body,
                    "html_body": html_body,
                }
            )
            current_app.logger.info(f"Captured test email for recipient: {to_email}")
            return True

        mail_server = config.get("MAIL_SERVER")
        mail_port = int(config.get("MAIL_PORT", 587))
        mail_use_tls = config.get("MAIL_USE_TLS")
        mail_username = config.get("MAIL_USERNAME")
        mail_password = config.get("MAIL_PASSWORD")
        sender = config.get("MAIL_DEFAULT_SENDER", "campushive.team@gmail.com")

        # Convert mail_use_tls to bool if passed as string
        if isinstance(mail_use_tls, str):
            use_tls = mail_use_tls.strip().lower() in ("true", "1", "yes")
        else:
            use_tls = bool(mail_use_tls)

        has_credentials = bool(mail_username and mail_password)

        if not mail_server:
            current_app.logger.error("SMTP delivery failed: MAIL_SERVER is not configured.")
            raise EmailDeliveryError("SMTP server is not configured.")

        # Create MIME message
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = sender
        msg["To"] = to_email

        # Attach text and html alternatives
        part_text = MIMEText(text_body, "plain", "utf-8")
        msg.attach(part_text)

        if html_body:
            part_html = MIMEText(html_body, "html", "utf-8")
            msg.attach(part_html)

        current_app.logger.info(
            f"Attempting to send email to {to_email} via SMTP server {mail_server}:{mail_port} "
            f"(tls={use_tls}, credentials_configured={has_credentials})"
        )

        stage = "initialization"
        server = None
        try:
            stage = "connection"
            if mail_port == 465:
                server = smtplib.SMTP_SSL(mail_server, mail_port, timeout=15)
            else:
                server = smtplib.SMTP(mail_server, mail_port, timeout=15)
                if use_tls:
                    stage = "starttls"
                    server.starttls()

            if has_credentials:
                stage = "authentication"
                server.login(mail_username, mail_password)
            else:
                current_app.logger.warning(
                    f"SMTP authentication skipped: credentials not configured "
                    f"(has_username={bool(mail_username)}, has_password={bool(mail_password)})"
                )

            stage = "message_delivery"
            server.send_message(msg)
            current_app.logger.info(f"Successfully sent email to {to_email}")
            return True

        except (smtplib.SMTPException, OSError, TimeoutError) as exc:
            smtp_code = getattr(exc, "smtp_code", None)
            smtp_err_raw = getattr(exc, "smtp_error", None)
            sanitized_err = _sanitize_smtp_error(smtp_err_raw)

            current_app.logger.error(
                f"SMTP delivery failed for {to_email} via {mail_server}:{mail_port} "
                f"[stage: {stage}, exc: {exc.__class__.__name__}, "
                f"smtp_code: {smtp_code}, error: {sanitized_err}, "
                f"credentials_configured: {has_credentials}]"
            )
            raise EmailDeliveryError(
                "Unable to deliver email via SMTP. Please try again later.",
                original_exception=exc,
            ) from exc
        finally:
            if server:
                try:
                    server.quit()
                except Exception:
                    pass

    @classmethod
    def verify_smtp_connection(cls, app: Optional[Any] = None) -> Dict[str, Any]:
        """Test SMTP connection and authentication safely without sending an email.

        Returns a dictionary summarizing the result:
        - success (bool)
        - stage (str: 'initialization' | 'connection' | 'starttls' | 'authentication' | 'completed')
        - server (str)
        - port (int)
        - tls (bool)
        - credentials_configured (bool)
        - smtp_code (Optional[int])
        - error_class (Optional[str])
        - error (Optional[str])
        - message (Optional[str])
        """
        if app is not None:
            config = app.config
        else:
            config = current_app.config

        mail_server = config.get("MAIL_SERVER")
        mail_port = int(config.get("MAIL_PORT", 587))
        mail_use_tls = config.get("MAIL_USE_TLS")
        mail_username = config.get("MAIL_USERNAME")
        mail_password = config.get("MAIL_PASSWORD")

        if isinstance(mail_use_tls, str):
            use_tls = mail_use_tls.strip().lower() in ("true", "1", "yes")
        else:
            use_tls = bool(mail_use_tls)

        has_credentials = bool(mail_username and mail_password)

        if not mail_server:
            return {
                "success": False,
                "stage": "initialization",
                "server": None,
                "port": mail_port,
                "tls": use_tls,
                "credentials_configured": has_credentials,
                "error": "SMTP server is not configured.",
                "error_class": "ConfigurationError",
            }

        stage = "connection"
        server = None
        try:
            if mail_port == 465:
                server = smtplib.SMTP_SSL(mail_server, mail_port, timeout=15)
            else:
                server = smtplib.SMTP(mail_server, mail_port, timeout=15)
                if use_tls:
                    stage = "starttls"
                    server.starttls()

            if has_credentials:
                stage = "authentication"
                server.login(mail_username, mail_password)

            return {
                "success": True,
                "stage": "completed",
                "server": mail_server,
                "port": mail_port,
                "tls": use_tls,
                "credentials_configured": has_credentials,
                "message": f"SMTP connection and authentication verified successfully on {mail_server}:{mail_port}",
            }
        except (smtplib.SMTPException, OSError, TimeoutError) as exc:
            code = getattr(exc, "smtp_code", None)
            raw_err = getattr(exc, "smtp_error", None)
            sanitized = _sanitize_smtp_error(raw_err) or str(exc)
            return {
                "success": False,
                "stage": stage,
                "server": mail_server,
                "port": mail_port,
                "tls": use_tls,
                "credentials_configured": has_credentials,
                "error_class": exc.__class__.__name__,
                "smtp_code": code,
                "error": sanitized,
            }
        finally:
            if server:
                try:
                    server.quit()
                except Exception:
                    pass

    @staticmethod
    def _build_otp_html_template(otp: str, expires_in_minutes: int) -> str:
        """Render modern CampusHive branded HTML email template for registration OTP."""
        return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CampusHive Email Verification</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #F8FAFC; padding: 40px 10px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 520px; background-color: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);">
          <!-- Header Banner -->
          <tr>
            <td style="background-color: #172033; padding: 30px 40px; text-align: center;">
              <h1 style="color: #FFFFFF; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">CampusHive</h1>
              <p style="color: #94A3B8; margin: 6px 0 0; font-size: 13px; font-weight: 500;">Campus Community & Grievance Portal</p>
            </td>
          </tr>
          <!-- Main Content -->
          <tr>
            <td style="padding: 36px 40px;">
              <h2 style="color: #1E293B; margin: 0 0 14px; font-size: 20px; font-weight: 700;">Verify Your Email Address</h2>
              <p style="color: #475569; font-size: 15px; line-height: 1.6; margin: 0 0 24px;">
                Welcome to CampusHive! To verify your official college email and complete your student registration, enter the verification code below:
              </p>
              
              <!-- OTP Box -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin: 24px 0;">
                <tr>
                  <td align="center" style="background-color: #F0FDF4; border: 2px dashed #0F766E; border-radius: 12px; padding: 20px;">
                    <span style="font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #0F766E; font-family: 'Courier New', Courier, monospace; display: inline-block;">{otp}</span>
                  </td>
                </tr>
              </table>

              <p style="color: #64748B; font-size: 13px; line-height: 1.5; margin: 0 0 12px;">
                &#9201; <strong>This verification code expires in {expires_in_minutes} minutes</strong> and is valid for a single use.
              </p>
              <p style="color: #94A3B8; font-size: 12px; line-height: 1.5; margin: 0;">
                If you did not initiate this registration request on CampusHive, you can safely ignore this email. No account will be created.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 40px; text-align: center;">
              <p style="color: #94A3B8; font-size: 12px; margin: 0;">
                &copy; CampusHive &bull; Automated notification &bull; Please do not reply to this email
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""
