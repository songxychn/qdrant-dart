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

  test('core point writes work against the pinned image', () async {
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

    final stored = (await client.points.retrieve(
      collectionName,
      [1],
      withVector: true,
    ))
        .single;
    expect(stored.id, 1);
    final norm = math.sqrt(vector.fold(0, (sum, value) => sum + value * value));
    expect(
      stored.vector,
      vector.map((value) => closeTo(value / norm, 0.000001)).toList(),
    );
    expect(
      stored.payload,
      {'title': 'The Matrix Reloaded', 'year': 2003},
    );
    expect(
      (await client.points.retrieve(collectionName, [uuid])).single.id,
      uuid,
    );

    final idOnly = (await client.points.retrieve(
      collectionName,
      [1],
      withPayload: false,
    ))
        .single;
    expect(idOnly.payload, isNull);
    expect(idOnly.vector, isNull);

    final deletion = await client.points.delete(collectionName, [1]);
    expect(deletion.operationId, isNotNull);
    expect(deletion.status, UpdateStatus.completed);
    expect(await client.points.retrieve(collectionName, [1]), isEmpty);
    expect(
      (await client.points.retrieve(collectionName, [uuid])).single.id,
      uuid,
    );

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');

  test('point scrolling paginates against the pinned image', () async {
    const collectionName = 'qdrant_dart_scroll';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: VectorParams(size: 2, distance: Distance.dot),
      ),
      isTrue,
    );
    await client.points.upsert(collectionName, [
      Point(id: 1, vector: [1, 0], payload: {'page': 'first'}),
      Point(id: 2, vector: [0, 1], payload: {'page': 'first'}),
      Point(id: 3, vector: [1, 1], payload: {'page': 'second'}),
    ]);

    final firstPage = await client.points.scroll(
      collectionName,
      limit: 2,
      withVector: true,
    );
    expect(firstPage.points.map((point) => point.id), [1, 2]);
    expect(firstPage.points.first.payload, {'page': 'first'});
    expect(firstPage.points.first.vector, [1.0, 0.0]);
    expect(firstPage.nextPageOffset, 3);

    final secondPage = await client.points.scroll(
      collectionName,
      offset: firstPage.nextPageOffset,
      limit: 2,
    );
    expect(secondPage.points.map((point) => point.id), [3]);
    expect(secondPage.nextPageOffset, isNull);

    expect(
      await client.points
          .scrollAll(
            collectionName,
            pageSize: 1,
            filter: Filter(
              must: [FieldCondition.match('page', 'first')],
            ),
          )
          .map((point) => point.id)
          .toList(),
      [1, 2],
    );
    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');

  test('point query applies payload filters against the pinned image',
      () async {
    const collectionName = 'qdrant_dart_query';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: VectorParams(size: 3, distance: Distance.dot),
      ),
      isTrue,
    );
    await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: [1, 0, 0],
        payload: {'city': 'London', 'price': 100, 'active': true},
      ),
      Point(
        id: 2,
        vector: [0.8, 0.2, 0],
        payload: {'city': 'London', 'price': 200, 'active': false},
      ),
      Point(
        id: 3,
        vector: [0, 1, 0],
        payload: {'city': 'Berlin', 'price': 150, 'active': true},
      ),
      Point(
        id: 4,
        vector: [0.9, 0.1, 0],
        payload: {'city': 'Berlin', 'price': 300, 'active': true},
      ),
    ]);

    final matches = await client.points.query(
      collectionName,
      [1, 0, 0],
      filter: Filter(
        must: [
          FieldCondition.match('city', 'London'),
          FieldCondition.range('price', gte: 150),
        ],
        mustNot: [FieldCondition.match('active', true)],
      ),
      withPayload: true,
      withVector: true,
    );
    expect(matches, hasLength(1));
    expect(matches.single.id, 2);
    expect(matches.single.score, closeTo(0.8, 0.000001));
    expect(matches.single.payload?['price'], 200);
    expect(matches.single.vector, [0.8, 0.2, 0.0]);

    final alternatives = await client.points.query(
      collectionName,
      [1, 0, 0],
      filter: Filter(
        should: [
          FieldCondition.match('city', 'Berlin'),
          FieldCondition.range('price', lte: 100),
        ],
      ),
    );
    expect(alternatives.map((point) => point.id).toSet(), {1, 3, 4});

    final secondStrongest = await client.points.query(
      collectionName,
      [1, 0, 0],
      limit: 1,
      offset: 1,
      scoreThreshold: 0.85,
    );
    expect(secondStrongest.single.id, 4);
    expect(secondStrongest.single.score, closeTo(0.9, 0.000001));

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');
}
