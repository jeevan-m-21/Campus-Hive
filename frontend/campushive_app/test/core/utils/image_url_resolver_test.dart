import 'package:flutter_test/flutter_test.dart';
import 'package:campushive_app/core/constants/app_constants.dart';
import 'package:campushive_app/core/utils/image_url_resolver.dart';

void main() {
  group('resolveImageUrl', () {
    const customBase = 'http://192.168.31.90:5000/api/v1';

    test('returns absolute HTTP URL unchanged', () {
      const url = 'http://example.com/images/sample.jpg';
      expect(resolveImageUrl(url, baseUrl: customBase), equals(url));
    });

    test('returns absolute HTTPS URL unchanged', () {
      const url = 'https://example.com/images/sample.png';
      expect(resolveImageUrl(url, baseUrl: customBase), equals(url));
    });

    test(
      'converts relative path beginning with /uploads/ into full host URL without /api/v1',
      () {
        const path = '/uploads/complaints/20261018_sample.jpg';
        expect(
          resolveImageUrl(path, baseUrl: customBase),
          equals(
            'http://192.168.31.90:5000/uploads/complaints/20261018_sample.jpg',
          ),
        );
      },
    );

    test('converts relative path without leading slash into full host URL', () {
      const path = 'uploads/complaints/20261018_sample.jpg';
      expect(
        resolveImageUrl(path, baseUrl: customBase),
        equals(
          'http://192.168.31.90:5000/uploads/complaints/20261018_sample.jpg',
        ),
      );
    });

    test('handles null safely', () {
      expect(resolveImageUrl(null, baseUrl: customBase), equals(''));
    });

    test('handles empty and whitespace-only values safely', () {
      expect(resolveImageUrl('', baseUrl: customBase), equals(''));
      expect(resolveImageUrl('   ', baseUrl: customBase), equals(''));
    });

    test(
      'avoids duplicating hostname if already absolute with backend host',
      () {
        const absoluteBackendUrl =
            'http://192.168.31.90:5000/uploads/complaints/sample.jpg';
        expect(
          resolveImageUrl(absoluteBackendUrl, baseUrl: customBase),
          equals(absoluteBackendUrl),
        );
      },
    );

    test(
      'works with default AppConstants.apiBaseUrl when baseUrl is omitted',
      () {
        const path = '/uploads/complaints/default.jpg';
        final result = resolveImageUrl(path);
        final expectedOrigin = Uri.parse(AppConstants.apiBaseUrl).origin;
        expect(
          result,
          equals('$expectedOrigin/uploads/complaints/default.jpg'),
        );
        expect(result, isNot(contains('/api/v1')));
      },
    );
  });
}
