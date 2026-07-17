import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:qdrant_dart/qdrant_dart.dart';
import 'package:test/test.dart';

void main() {
  final expectedVersion = Platform.environment['QDRANT_VERSION'] ??
      File('tool/qdrant-version').readAsStringSync().trim();
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
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 4, distance: Distance.cosine),
        ),
      ),
      isTrue,
    );
    expect(await client.collections.list(), contains('qdrant_dart_lifecycle'));

    final collection = await client.collections.get('qdrant_dart_lifecycle');
    expect(collection.name, 'qdrant_dart_lifecycle');
    expect(collection.status, isNotEmpty);
    expect(collection.vectors.defaultDense?.size, 4);
    expect(collection.vectors.defaultDense?.distance, Distance.cosine);
    expect(collection.pointsCount, 0);
    expect(collection.indexedVectorsCount, 0);
    expect(collection.segmentsCount, greaterThanOrEqualTo(1));

    expect(await client.collections.delete('qdrant_dart_lifecycle'), isTrue);
    expect(
      await client.collections.list(),
      isNot(contains('qdrant_dart_lifecycle')),
    );
  }, tags: 'integration');

  test('real server failures preserve typed request context', () async {
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    await expectLater(
      client.collections.get('qdrant_dart_missing_collection'),
      throwsA(
        isA<QdrantException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.method, 'method', 'GET')
            .having(
              (error) => error.uri.path,
              'path',
              '/collections/qdrant_dart_missing_collection',
            )
            .having((error) => error.message, 'message', isNotEmpty),
      ),
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
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 4, distance: Distance.cosine),
        ),
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
      withVectors: const VectorSelector.all(),
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

  test('payload data lifecycle works against the pinned image', () async {
    const collectionName = 'qdrant_dart_payload_data';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 2, distance: Distance.dot),
        ),
      ),
      isTrue,
    );
    await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: [1, 0],
        payload: {'group': 'red', 'keep': 'yes', 'drop': 'first'},
      ),
      Point(
        id: 2,
        vector: [0, 1],
        payload: {'group': 'blue', 'keep': 'yes', 'drop': 'second'},
      ),
    ]);

    final setById = await client.points.setPayload(
      collectionName,
      {'added': 1, 'keep': 'changed'},
      PointSelector.ids([1]),
    );
    expect(setById.status, UpdateStatus.completed);
    expect(
      (await client.points.retrieve(collectionName, [1])).single.payload,
      {
        'group': 'red',
        'keep': 'changed',
        'drop': 'first',
        'added': 1,
      },
    );

    final blueFilter = Filter(
      must: [FieldCondition.match('group', 'blue')],
    );
    final setByFilter = await client.points.setPayload(
      collectionName,
      {'filtered': true},
      PointSelector.filter(blueFilter),
    );
    expect(setByFilter.status, UpdateStatus.completed);
    expect(
      (await client.points.retrieve(collectionName, [2]))
          .single
          .payload?['filtered'],
      isTrue,
    );

    final overwrite = await client.points.overwritePayload(
      collectionName,
      {'only': 'replacement', 'drop': 'remove-me'},
      PointSelector.ids([1]),
    );
    expect(overwrite.status, UpdateStatus.completed);
    expect(
      (await client.points.retrieve(collectionName, [1])).single.payload,
      {'only': 'replacement', 'drop': 'remove-me'},
    );

    final deletion = await client.points.deletePayload(
      collectionName,
      ['drop'],
      PointSelector.ids([1]),
    );
    expect(deletion.status, UpdateStatus.completed);
    expect(
      (await client.points.retrieve(collectionName, [1])).single.payload,
      {'only': 'replacement'},
    );

    final clear = await client.points.clearPayload(
      collectionName,
      PointSelector.filter(blueFilter),
    );
    expect(clear.status, UpdateStatus.completed);
    expect(
      (await client.points.retrieve(collectionName, [2])).single.payload,
      isEmpty,
    );

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');

  test('filtered deletion and counts work against the pinned image', () async {
    const collectionName = 'qdrant_dart_count_delete';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 2, distance: Distance.dot),
        ),
      ),
      isTrue,
    );
    await client.points.upsert(collectionName, [
      Point(id: 1, vector: [1, 0], payload: {'group': 'red'}),
      Point(id: 2, vector: [0, 1], payload: {'group': 'red'}),
      Point(id: 3, vector: [1, 1], payload: {'group': 'blue'}),
      Point(id: 4, vector: [0.5, 0.5], payload: {'group': 'blue'}),
    ]);

    final redFilter = Filter(
      must: [FieldCondition.match('group', 'red')],
    );
    expect(await client.points.count(collectionName), 4);
    expect(
      await client.points.count(collectionName, filter: redFilter),
      2,
    );
    expect(
      await client.points.count(collectionName, exact: false),
      greaterThanOrEqualTo(0),
    );

    final deletion = await client.points.deleteByFilter(
      collectionName,
      redFilter,
    );
    expect(deletion.status, UpdateStatus.completed);
    expect(await client.points.count(collectionName), 2);
    expect(await client.points.retrieve(collectionName, [1, 2]), isEmpty);
    expect(
      (await client.points.retrieve(collectionName, [3, 4]))
          .map((point) => point.id),
      [3, 4],
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
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 2, distance: Distance.dot),
        ),
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
      withVectors: const VectorSelector.all(),
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

  test('named dense and sparse vectors work against the pinned image',
      () async {
    const collectionName = 'qdrant_dart_named_vectors';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: CollectionVectors.named(
          dense: {
            'image': DenseVectorParams(size: 2, distance: Distance.dot),
          },
          sparse: const {'keywords': SparseVectorParams()},
        ),
      ),
      isTrue,
    );

    final collection = await client.collections.get(collectionName);
    expect(collection.vectors.defaultDense, isNull);
    expect(collection.vectors.namedDense['image']?.size, 2);
    expect(collection.vectors.sparse, contains('keywords'));

    await client.points.upsert(collectionName, [
      Point.named(
        id: 1,
        vectors: {
          'image': DenseVector([1, 0]),
          'keywords': SparseVector(indices: [1, 3], values: [1, 0.5]),
        },
        payload: {'title': 'first'},
      ),
      Point.named(
        id: 2,
        vectors: {
          'image': DenseVector([0, 1]),
          'keywords': SparseVector(indices: [2, 3], values: [1, 0.2]),
        },
        payload: {'title': 'second'},
      ),
    ]);

    final stored = (await client.points.retrieve(
      collectionName,
      [1],
      withVectors: VectorSelector.named(['image', 'keywords']),
    ))
        .single;
    expect((stored.vectors?.named['image'] as DenseVector).values, [1.0, 0.0]);
    final storedSparse = stored.vectors?.named['keywords'] as SparseVector;
    expect(storedSparse.indices, [1, 3]);
    expect(storedSparse.values, [1.0, 0.5]);

    final denseMatches = await client.points.query(
      collectionName,
      DenseVector([1, 0]),
      using: 'image',
      withVectors: VectorSelector.named(['image']),
    );
    expect(denseMatches.first.id, 1);
    expect(
      (denseMatches.first.vectors?.named['image'] as DenseVector).values,
      [1.0, 0.0],
    );

    final sparseMatches = await client.points.query(
      collectionName,
      SparseVector(indices: [1, 3], values: [1, 0.5]),
      using: 'keywords',
    );
    expect(sparseMatches.first.id, 1);

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');

  test('vector updates and deletion work against the pinned image', () async {
    const collectionName = 'qdrant_dart_vector_updates';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: CollectionVectors.named(
          dense: {
            'image': DenseVectorParams(size: 2, distance: Distance.dot),
            'text': DenseVectorParams(size: 2, distance: Distance.dot),
          },
          sparse: const {'keywords': SparseVectorParams()},
        ),
      ),
      isTrue,
    );
    await client.points.upsert(collectionName, [
      Point.named(
        id: 1,
        vectors: {
          'image': DenseVector([1, 0]),
          'text': DenseVector([0, 1]),
          'keywords': SparseVector(indices: [1], values: [1]),
        },
        payload: {'group': 'red'},
      ),
      Point.named(
        id: 2,
        vectors: {
          'image': DenseVector([0, 1]),
          'text': DenseVector([1, 0]),
          'keywords': SparseVector(indices: [2], values: [1]),
        },
        payload: {'group': 'blue'},
      ),
    ]);

    final update = await client.points.updateVectors(collectionName, [
      PointVectorUpdate.named(
        id: 1,
        vectors: {
          'image': DenseVector([0.5, 0.5]),
          'keywords': SparseVector(indices: [3], values: [0.75]),
        },
      ),
    ]);
    expect(update.status, UpdateStatus.completed);
    final updated = (await client.points.retrieve(
      collectionName,
      [1],
      withVectors: const VectorSelector.all(),
    ))
        .single;
    expect(updated.payload, {'group': 'red'});
    expect((updated.vectors?.named['image'] as DenseVector).values, [0.5, 0.5]);
    expect((updated.vectors?.named['text'] as DenseVector).values, [0.0, 1.0]);
    final sparse = updated.vectors?.named['keywords'] as SparseVector;
    expect(sparse.indices, [3]);
    expect(sparse.values, [0.75]);

    final deletion = await client.points.deleteVectors(
      collectionName,
      ['image'],
      PointSelector.filter(
        Filter(must: [FieldCondition.match('group', 'red')]),
      ),
    );
    expect(deletion.status, UpdateStatus.completed);
    final afterDeletion = (await client.points.retrieve(
      collectionName,
      [1, 2],
      withVectors: const VectorSelector.all(),
    ));
    expect(afterDeletion.first.vectors?.named, isNot(contains('image')));
    expect(afterDeletion.first.vectors?.named, contains('text'));
    expect(afterDeletion.first.vectors?.named, contains('keywords'));
    expect(afterDeletion.last.vectors?.named, contains('image'));

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');

  test('payload index lifecycle works against the pinned image', () async {
    const collectionName = 'qdrant_dart_payload_indexes';
    final client = QdrantClient(baseUrl: baseUrl);
    addTearDown(() => client.close(force: true));

    expect(
      await client.collections.create(
        collectionName,
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 2, distance: Distance.dot),
        ),
      ),
      isTrue,
    );

    const schemas = {
      'city': PayloadSchemaType.keyword,
      'year': PayloadSchemaType.integer,
      'rating': PayloadSchemaType.floatingPoint,
      'location': PayloadSchemaType.geo,
      'description': PayloadSchemaType.text,
      'active': PayloadSchemaType.boolean,
      'published_at': PayloadSchemaType.dateTime,
      'external_id': PayloadSchemaType.uuid,
    };
    for (final MapEntry(:key, :value) in schemas.entries) {
      final update = await client.payloadIndexes.create(
        collectionName,
        key,
        schema: value,
      );
      expect(update.status, UpdateStatus.completed);
    }

    final indexed = await client.collections.get(collectionName);
    expect(indexed.payloadIndexes.keys, containsAll(schemas.keys));
    for (final MapEntry(:key, :value) in schemas.entries) {
      expect(indexed.payloadIndexes[key]?.schema, value);
    }

    await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: [1, 0],
        payload: {'city': 'London', 'year': 1999},
      ),
    ]);
    final matches = await client.points.query(
      collectionName,
      DenseVector([1, 0]),
      filter: Filter(
        must: [
          FieldCondition.match('city', 'London'),
          FieldCondition.range('year', gte: 1990),
        ],
      ),
    );
    expect(matches.single.id, 1);

    final deletion = await client.payloadIndexes.delete(
      collectionName,
      'city',
    );
    expect(deletion.status, UpdateStatus.completed);
    final afterDeletion = await client.collections.get(collectionName);
    expect(afterDeletion.payloadIndexes, isNot(contains('city')));
    expect(afterDeletion.payloadIndexes, contains('year'));

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
        vectors: CollectionVectors.dense(
          DenseVectorParams(size: 3, distance: Distance.dot),
        ),
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
      DenseVector([1, 0, 0]),
      filter: Filter(
        must: [
          FieldCondition.match('city', 'London'),
          FieldCondition.range('price', gte: 150),
        ],
        mustNot: [FieldCondition.match('active', true)],
      ),
      withPayload: true,
      withVectors: const VectorSelector.all(),
    );
    expect(matches, hasLength(1));
    expect(matches.single.id, 2);
    expect(matches.single.score, closeTo(0.8, 0.000001));
    expect(matches.single.payload?['price'], 200);
    expect(matches.single.vector, [0.8, 0.2, 0.0]);

    final alternatives = await client.points.query(
      collectionName,
      DenseVector([1, 0, 0]),
      filter: Filter(
        should: [
          FieldCondition.match('city', 'Berlin'),
          FieldCondition.range('price', lte: 100),
        ],
      ),
    );
    expect(alternatives.map((point) => point.id).toSet(), {1, 3, 4});

    final grouped = await client.points.query(
      collectionName,
      DenseVector([1, 0, 0]),
      filter: Filter(
        must: [
          HasIdCondition([2, 3, 4]),
          Filter(
            should: [
              FieldCondition.match('city', 'London'),
              FieldCondition.range('price', gte: 300),
            ],
          ),
        ],
      ),
    );
    expect(grouped.map((point) => point.id).toSet(), {2, 4});

    final secondStrongest = await client.points.query(
      collectionName,
      DenseVector([1, 0, 0]),
      limit: 1,
      offset: 1,
      scoreThreshold: 0.85,
    );
    expect(secondStrongest.single.id, 4);
    expect(secondStrongest.single.score, closeTo(0.9, 0.000001));

    expect(await client.collections.delete(collectionName), isTrue);
  }, tags: 'integration');
}
