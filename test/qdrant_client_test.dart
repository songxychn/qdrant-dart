import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qdrant_dart/qdrant_dart.dart';
import 'package:qdrant_dart/src/qdrant_transport.dart';
import 'package:test/test.dart';

void main() {
  group('QdrantClient', () {
    test('normalizes its base URL and retains its timeout', () {
      final client = QdrantClient(
        baseUrl: Uri.parse('https://qdrant.example/api/'),
        timeout: const Duration(seconds: 5),
      );
      addTearDown(client.close);

      expect(client.baseUrl, Uri.parse('https://qdrant.example/api'));
      expect(client.timeout, const Duration(seconds: 5));
    });

    test('rejects unsafe or incomplete configuration', () {
      expect(
        () => QdrantClient(baseUrl: Uri.parse('/qdrant')),
        throwsArgumentError,
      );
      expect(
        () => QdrantClient(
          baseUrl: Uri.parse('http://127.0.0.1:6333'),
          apiKey: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => QdrantClient(
          baseUrl: Uri.parse('http://127.0.0.1:6333'),
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Point', () {
    test('accepts supported IDs and copies vector and payload inputs', () {
      final vector = <num>[0.1, 0.2];
      final payload = <String, Object?>{'kind': 'example'};
      final point = Point(id: 1, vector: vector, payload: payload);
      final uuidPoint = Point(
        id: '5c56c793-69f3-4fbf-87e6-c4bf54c28c26',
        vector: [0.2, 0.1],
      );

      vector[0] = 9;
      payload['kind'] = 'changed';

      expect(point.id, 1);
      expect(point.vector, [0.1, 0.2]);
      expect(point.payload, {'kind': 'example'});
      expect(uuidPoint.id, '5c56c793-69f3-4fbf-87e6-c4bf54c28c26');
    });

    test('rejects unsupported IDs and invalid vectors', () {
      expect(() => Point(id: -1, vector: [0.1]), throwsArgumentError);
      expect(() => Point(id: true, vector: [0.1]), throwsArgumentError);
      expect(() => Point(id: 1, vector: []), throwsArgumentError);
      expect(
        () => Point(id: 1, vector: [double.infinity]),
        throwsArgumentError,
      );
    });
  });

  group('PointOperations', () {
    test('rejects an empty collection name or point list', () async {
      final client = QdrantClient(
        baseUrl: Uri.parse('http://127.0.0.1:6333'),
      );
      addTearDown(client.close);
      final point = Point(id: 1, vector: [0.1]);

      await expectLater(
        client.points.upsert('', [point]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.upsert('movies', []),
        throwsArgumentError,
      );
    });
  });

  group('QdrantTransport', () {
    test('sends JSON and API-key authentication to the configured base path',
        () async {
      final received = Completer<({String apiKey, String body, Uri uri})>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = QdrantTransport(
        baseUrl:
            Uri.parse('http://${server.address.address}:${server.port}/qdrant'),
        apiKey: 'test-api-key',
        timeout: const Duration(seconds: 1),
      );
      addTearDown(() async {
        transport.close(force: true);
        await server.close(force: true);
      });
      server.listen((request) async {
        received.complete((
          apiKey: request.headers.value('api-key')!,
          body: await utf8.decoder.bind(request).join(),
          uri: request.uri,
        ));
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"result":true}');
        await request.response.close();
      });

      final response = await transport.send(
        method: 'put',
        path: Uri(path: 'collections/books'),
        body: {
          'vectors': {'size': 4, 'distance': 'Cosine'},
        },
      );
      final request = await received.future;

      expect(response.statusCode, HttpStatus.ok);
      expect(request.apiKey, 'test-api-key');
      expect(request.uri.path, '/qdrant/collections/books');
      expect(jsonDecode(request.body), {
        'vectors': {'size': 4, 'distance': 'Cosine'},
      });
    });

    test('maps Qdrant errors without revealing the API key', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = QdrantTransport(
        baseUrl: Uri.parse('http://${server.address.address}:${server.port}'),
        apiKey: 'test-api-key',
        timeout: const Duration(seconds: 1),
      );
      addTearDown(() async {
        transport.close(force: true);
        await server.close(force: true);
      });
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..write('{"status":{"error":"Invalid API key","code":401}}');
        await request.response.close();
      });

      await expectLater(
        transport.send(method: 'GET', path: Uri(path: 'collections')),
        throwsA(
          isA<QdrantException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.message, 'message', 'Invalid API key')
              .having(
                (error) => error.toString(),
                'toString',
                isNot(contains('test-api-key')),
              ),
        ),
      );
    });

    test('maps request timeouts to QdrantException', () async {
      final started = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = QdrantTransport(
        baseUrl: Uri.parse('http://${server.address.address}:${server.port}'),
        apiKey: null,
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(() async {
        transport.close(force: true);
        await server.close(force: true);
      });
      server.listen((request) async {
        started.complete();
        await Future<void>.delayed(const Duration(seconds: 1));
        await request.response.close();
      });

      await expectLater(
        transport.send(method: 'GET', path: Uri(path: 'collections')),
        throwsA(
          isA<QdrantException>()
              .having((error) => error.statusCode, 'statusCode', isNull)
              .having(
                  (error) => error.message, 'message', contains('timed out')),
        ),
      );
      await started.future;
    });
  });
}
