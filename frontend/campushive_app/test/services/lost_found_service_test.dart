import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/services/lost_found_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.postMultipartResponse,
    this.postResponse,
  });

  Map<String, dynamic>? postMultipartResponse;
  Map<String, dynamic>? postResponse;

  String? lastMultipartPath;
  String? lastMultipartToken;
  String? lastMultipartFilePath;
  String? lastMultipartFileField;

  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String idToken,
    required String filePath,
    String fileField = 'file',
  }) async {
    lastMultipartPath = path;
    lastMultipartToken = idToken;
    lastMultipartFilePath = filePath;
    lastMultipartFileField = fileField;
    if (postMultipartResponse == null) {
      throw const ApiException(
        statusCode: 400,
        code: 'bad_request',
        message: 'Multipart error',
      );
    }
    return postMultipartResponse!;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    return postResponse ?? {};
  }
}

class FakeUser implements User {
  FakeUser({this.token = 'mock-id-token'});
  final String token;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeApiClient fakeApi;
  late FakeFirebaseAuth fakeAuth;
  late LostFoundService service;

  setUp(() {
    fakeApi = FakeApiClient();
    fakeAuth = FakeFirebaseAuth(currentUser: FakeUser());
    service = LostFoundService(apiClient: fakeApi, firebaseAuth: fakeAuth);
  });

  group('LostFoundService Upload & Image Integration', () {
    test('uploadImage calls dedicated uploadLostFoundImage endpoint and returns URL', () async {
      fakeApi.postMultipartResponse = {
        'status': 'success',
        'message': 'Image uploaded successfully',
        'data': {
          'image_url': '/uploads/lost_found/abc123456789.png',
          'file_size': 4096,
          'mime_type': 'image/png',
        },
      };

      final result = await service.uploadImage('/dummy/path/to/image.png');

      expect(fakeApi.lastMultipartPath, equals(ApiEndpoints.uploadLostFoundImage));
      expect(fakeApi.lastMultipartPath, equals('/lost-found/upload-image'));
      expect(fakeApi.lastMultipartFilePath, equals('/dummy/path/to/image.png'));
      expect(fakeApi.lastMultipartToken, equals('mock-id-token'));
      expect(result, equals('/uploads/lost_found/abc123456789.png'));
    });

    test('uploadImage throws LostFoundException when user is not authenticated', () async {
      fakeAuth.currentUser = null;

      expect(
        () => service.uploadImage('/dummy/path/to/image.png'),
        throwsA(isA<LostFoundException>().having(
          (e) => e.message,
          'message',
          contains('Please sign in again'),
        )),
      );
    });

    test('uploadImage wraps ApiException in LostFoundException', () async {
      fakeApi.postMultipartResponse = null; // triggers ApiException in FakeApiClient

      expect(
        () => service.uploadImage('/dummy/path/to/image.png'),
        throwsA(isA<LostFoundException>().having(
          (e) => e.message,
          'message',
          contains('Multipart error'),
        )),
      );
    });

    test('createItem forwards uploaded imageUrl in request body', () async {
      fakeApi.postResponse = {
        'status': 'success',
        'data': {
          'item_id': 101,
          'organization_id': 1,
          'posted_by': 10,
          'item_type': 'LOST',
          'title': 'Lost Calculator',
          'description': 'TI-84 lost in library',
          'status': 'OPEN',
          'images': [
            {
              'image_id': 1,
              'item_id': 101,
              'image_url': '/uploads/lost_found/abc123456789.png',
            }
          ],
        },
      };

      final item = await service.createItem(
        itemType: 'LOST',
        title: 'Lost Calculator',
        description: 'TI-84 lost in library',
        imageUrl: '/uploads/lost_found/abc123456789.png',
      );

      expect(fakeApi.lastPostPath, equals(ApiEndpoints.lostFound));
      expect(fakeApi.lastPostBody?['image_url'], equals('/uploads/lost_found/abc123456789.png'));
      expect(item.images.first.imageUrl, equals('/uploads/lost_found/abc123456789.png'));
    });
  });
}
