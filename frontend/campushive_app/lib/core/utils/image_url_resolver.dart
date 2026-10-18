import '../constants/app_constants.dart';

/// Resolves raw image and attachment URLs into fully-qualified network URIs.
///
/// Rules:
/// - Absolute HTTP/HTTPS URLs are returned unchanged.
/// - Relative paths (both `/uploads/...` and `uploads/...`) are resolved against
///   the backend host origin without injecting `/api/v1` or duplicating hostnames.
/// - Null, empty, and whitespace-only strings safely return an empty string.
String resolveImageUrl(String? url, {String? baseUrl}) {
  if (url == null) return '';
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  final rawBase = (baseUrl ?? AppConstants.apiBaseUrl).trim();
  final baseUri = Uri.tryParse(rawBase);
  String origin;
  if (baseUri != null && baseUri.hasScheme && baseUri.hasAuthority) {
    origin = baseUri.origin;
  } else {
    origin = rawBase.replaceAll(RegExp(r'/api/v\d+/?$'), '');
    if (origin.endsWith('/')) {
      origin = origin.substring(0, origin.length - 1);
    }
  }

  final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$origin$normalizedPath';
}
