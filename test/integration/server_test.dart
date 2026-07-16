import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

  test('point upsert works against the pinned Qdrant image', () async {
    const collectionName = 'qdrant_dart_upsert';
    const uuid = '5c56c793-69f3-4fbf-87e6-c4bf54c28c26';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: VectorParams(size: 4, distance: Distance.cosine),
      ),
      isTrue,
    );

    const vector = [0.9, 0.1, 0.1, 0.2];
    final update = await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: vector,
        payload: {'title': 'The Matrix', 'year': 1999},
      ),
      Point(
        id: uuid,
        vector: [0.1, 0.9, 0.2, 0.1],
      ),
    ]);

    expect(update.operationId, isNotNull);
    expect(update.status, UpdateStatus.completed);
    final replacement = await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: vector,
        payload: {'title': 'The Matrix Reloaded', 'year': 2003},
      ),
    ]);
    expect(replacement.status, UpdateStatus.completed);

    final stored = await _getPoint(baseUrl, collectionName, 1);
    expect(stored['id'], 1);
    final norm = math.sqrt(vector.fold(0, (sum, value) => sum + value * value));
    expect(
      stored['vector'],
      vector.map((value) => closeTo(value / norm, 0.000001)).toList(),
    );
    expect(
      stored['payload'],
      {'title': 'The Matrix Reloaded', 'year': 2003},
    );
    expect((await _getPoint(baseUrl, collectionName, uuid))['id'], uuid);

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');
}

Future<Map<String, Object?>> _getPoint(
  Uri baseUrl,
  String collectionName,
  Object id,
) async {
  final httpClient = HttpClient();
  try {
    final uri = baseUrl.resolveUri(Uri(
      pathSegments: ['collections', collectionName, 'points', '$id'],
      queryParameters: {'with_vector': 'true'},
    ));
    final request = await httpClient.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    expect(response.statusCode, HttpStatus.ok, reason: body);
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return Map<String, Object?>.from(decoded['result'] as Map);
  } finally {
    httpClient.close(force: true);
  }
}
