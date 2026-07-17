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
      expect(point.vectors.defaultDense?.values, [0.1, 0.2]);
      expect(point.payload, {'kind': 'example'});
      expect(uuidPoint.id, '5c56c793-69f3-4fbf-87e6-c4bf54c28c26');
    });

    test('accepts named dense and sparse vectors and copies inputs', () {
      final denseValues = <num>[0.1, 0.2];
      final sparseIndices = <int>[1, 4];
      final sparseValues = <num>[0.3, 0.7];
      final point = Point.named(
        id: 1,
        vectors: {
          'image': DenseVector(denseValues),
          'keywords': SparseVector(
            indices: sparseIndices,
            values: sparseValues,
          ),
        },
      );

      denseValues[0] = 9;
      sparseIndices[0] = 9;
      sparseValues[0] = 9;

      expect(point.vector, isNull);
      expect((point.vectors.named['image'] as DenseVector).values, [0.1, 0.2]);
      final sparse = point.vectors.named['keywords'] as SparseVector;
      expect(sparse.indices, [1, 4]);
      expect(sparse.values, [0.3, 0.7]);
    });

    test('rejects unsupported IDs and invalid vectors', () {
      expect(() => Point(id: -1, vector: [0.1]), throwsArgumentError);
      expect(() => Point(id: true, vector: [0.1]), throwsArgumentError);
      expect(() => Point(id: 1, vector: []), throwsArgumentError);
      expect(
        () => Point(id: 1, vector: [double.infinity]),
        throwsArgumentError,
      );
      expect(
        () => Point.named(id: 1, vectors: const {}),
        throwsArgumentError,
      );
      expect(
        () => SparseVector(indices: [1], values: const []),
        throwsArgumentError,
      );
      expect(
        () => SparseVector(indices: [1, 1], values: [0.1, 0.2]),
        throwsArgumentError,
      );
    });
  });

  group('CollectionVectors', () {
    test('validates named vector configuration and selectors', () {
      expect(() => CollectionVectors.named(), throwsArgumentError);
      expect(
        () => CollectionVectors.named(
          dense: {
            'shared': DenseVectorParams(size: 2, distance: Distance.dot),
          },
          sparse: const {'shared': SparseVectorParams()},
        ),
        throwsArgumentError,
      );
      expect(() => VectorSelector.named([]), throwsArgumentError);
      expect(
          () => VectorSelector.named(['image', 'image']), throwsArgumentError);

      final vectors = CollectionVectors.named(
        dense: {
          'image': DenseVectorParams(size: 2, distance: Distance.dot),
        },
        sparse: const {'keywords': SparseVectorParams()},
      );
      expect(vectors.defaultDense, isNull);
      expect(vectors.namedDense['image']?.size, 2);
      expect(vectors.sparse, contains('keywords'));
    });
  });

  group('PayloadIndexOperations', () {
    test('rejects empty collection and field names', () async {
      final client = QdrantClient(
        baseUrl: Uri.parse('http://127.0.0.1:6333'),
      );
      addTearDown(client.close);

      await expectLater(
        client.payloadIndexes.create(
          '',
          'year',
          schema: PayloadSchemaType.integer,
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.payloadIndexes.create(
          'movies',
          '',
          schema: PayloadSchemaType.integer,
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.payloadIndexes.delete('movies', ''),
        throwsArgumentError,
      );
    });
  });

  group('PointOperations', () {
    test('rejects invalid point operation inputs', () async {
      final client = QdrantClient(
        baseUrl: Uri.parse('http://127.0.0.1:6333'),
      );
      addTearDown(client.close);
      final point = Point(id: 1, vector: [0.1]);
      final prefetch = [
        Prefetch(query: DenseVector([0.1]))
      ];

      await expectLater(
        client.points.upsert('', [point]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.upsert('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.upsertInBatches('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.upsertInBatches('movies', [point], batchSize: 0),
        throwsArgumentError,
      );
      await expectLater(
        client.points.retrieve('', [1]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.retrieve('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.retrieve('movies', [true]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.delete('', [1]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.delete('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deleteByFilter(
          '',
          Filter(must: [
            HasIdCondition([1])
          ]),
        ),
        throwsArgumentError,
      );
      expect(() => PointSelector.ids([]), throwsArgumentError);
      expect(() => PointSelector.ids([true]), throwsArgumentError);
      await expectLater(
        client.points.setPayload('', {}, PointSelector.ids([1])),
        throwsArgumentError,
      );
      await expectLater(
        client.points.overwritePayload('', {}, PointSelector.ids([1])),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deletePayload(
          'movies',
          [],
          PointSelector.ids([1]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deletePayload(
          'movies',
          [''],
          PointSelector.ids([1]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.clearPayload('', PointSelector.ids([1])),
        throwsArgumentError,
      );
      expect(
        () => PointVectorUpdate(id: true, vector: [0.1]),
        throwsArgumentError,
      );
      expect(
        () => PointVectorUpdate.named(id: 1, vectors: const {}),
        throwsArgumentError,
      );
      await expectLater(
        client.points.updateVectors('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.updateVectors('', [
          PointVectorUpdate(id: 1, vector: [0.1]),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deleteVectors(
          'movies',
          [],
          PointSelector.ids([1]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deleteVectors(
          'movies',
          ['', 'image'],
          PointSelector.ids([1]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.deleteVectors(
          'movies',
          ['image', 'image'],
          PointSelector.ids([1]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.count(''),
        throwsArgumentError,
      );
      await expectLater(
        client.points.scroll('', limit: 1),
        throwsArgumentError,
      );
      await expectLater(
        client.points.scroll('movies', limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        client.points.scroll('movies', offset: true),
        throwsArgumentError,
      );
      await expectLater(
        client.points.scrollAll('movies', pageSize: 0),
        emitsError(isA<ArgumentError>()),
      );
      await expectLater(
        client.points.query('', DenseVector([0.1])),
        throwsArgumentError,
      );
      expect(() => DenseVector([]), throwsArgumentError);
      await expectLater(
        client.points.query('movies', DenseVector([0.1]), limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        client.points.query('movies', DenseVector([0.1]), offset: -1),
        throwsArgumentError,
      );
      await expectLater(
        client.points.query(
          'movies',
          DenseVector([0.1]),
          scoreThreshold: double.infinity,
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.query('movies', DenseVector([0.1]), using: ''),
        throwsArgumentError,
      );
      expect(
        () => Prefetch(query: DenseVector([0.1]), limit: 0),
        throwsArgumentError,
      );
      expect(
        () => Prefetch(query: DenseVector([0.1]), using: ''),
        throwsArgumentError,
      );
      await expectLater(
        client.points.queryRrf('movies', []),
        throwsArgumentError,
      );
      await expectLater(
        client.points.queryRrf('', prefetch),
        throwsArgumentError,
      );
      await expectLater(
        client.points.queryRrf(
          'movies',
          prefetch,
          limit: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        client.points.queryRrf(
          'movies',
          prefetch,
          offset: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Filter', () {
    test('validates match and range conditions', () {
      expect(() => Filter(), throwsArgumentError);
      expect(() => FieldCondition.match('', 'red'), throwsArgumentError);
      expect(() => FieldCondition.match('price', 1.5), throwsArgumentError);
      expect(() => FieldCondition.range('price'), throwsArgumentError);
      expect(() => HasIdCondition([]), throwsArgumentError);
      expect(() => HasIdCondition([true]), throwsArgumentError);
      expect(
        () => FieldCondition.range('price', gt: double.infinity),
        throwsArgumentError,
      );

      final filter = Filter(
        must: [
          HasIdCondition([1, 2]),
          Filter(
            should: [
              FieldCondition.match('city', 'London'),
              FieldCondition.range('price', lte: 100),
            ],
          ),
        ],
        should: [FieldCondition.match('available', true)],
        mustNot: [FieldCondition.range('price', gt: 100, lte: 200)],
      );
      expect((filter.must.first as HasIdCondition).ids, [1, 2]);
      final nested = filter.must.last as Filter;
      expect((nested.should.first as FieldCondition).key, 'city');
      expect((filter.should.single as FieldCondition).matchValue, isTrue);
      expect((filter.mustNot.single as FieldCondition).gt, 100);
      expect((filter.mustNot.single as FieldCondition).lte, 200);
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
