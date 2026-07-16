import 'dart:convert';
import 'dart:io';

import 'package:qdrant_dart/qdrant_dart.dart';
import 'package:test/test.dart';

void main() {
  final expectedVersion = File('tool/qdrant-version').readAsStringSync().trim();
  final baseUrl = Uri.parse(
    Platform.environment['QDRANT_URL'] ?? 'http://127.0.0.1:6333',
  );

  test(
    'pinned Qdrant image reports the expected version',
    () async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      Map<String, dynamic>? serverInfo;
      Object? lastError;
      for (var attempt = 0; attempt < 30; attempt++) {
        try {
          final request = await client.getUrl(baseUrl);
          final response = await request.close();
          final body = await utf8.decoder.bind(response).join();
          if (response.statusCode == HttpStatus.ok) {
            serverInfo = jsonDecode(body) as Map<String, dynamic>;
            break;
          }
          lastError = 'HTTP ${response.statusCode}: $body';
        } catch (error) {
          lastError = error;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      expect(
        serverInfo,
        isNotNull,
        reason: 'Qdrant did not become ready at $baseUrl: $lastError',
      );
      expect(serverInfo!['version'], expectedVersion);
    },
    tags: 'integration',
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('collection lifecycle works against the pinned Qdrant image', () async {
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        'qdrant_dart_lifecycle',
        vectors: VectorParams(size: 4, distance: Distance.cosine),
      ),
      isTrue,
    );
    expect(await client.collections.list(), contains('qdrant_dart_lifecycle'));

    final collection = await client.collections.get('qdrant_dart_lifecycle');
    expect(collection.name, 'qdrant_dart_lifecycle');
    expect(collection.status, isNotEmpty);
    expect(collection.vectors.size, 4);
    expect(collection.vectors.distance, Distance.cosine);
    expect(collection.pointsCount, 0);
    expect(collection.indexedVectorsCount, 0);
    expect(collection.segmentsCount, greaterThanOrEqualTo(1));

    expect(await client.collections.delete('qdrant_dart_lifecycle'), isTrue);
    expect(
      await client.collections.list(),
      isNot(contains('qdrant_dart_lifecycle')),
    );
  }, tags: 'integration');
}
