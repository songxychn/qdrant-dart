import 'dart:io';

import 'package:qdrant_dart/qdrant_dart.dart';

Future<void> main() async {
  final client = QdrantClient(
    baseUrl: Uri.parse(
      Platform.environment['QDRANT_URL'] ?? 'http://127.0.0.1:6333',
    ),
    apiKey: Platform.environment['QDRANT_API_KEY'],
  );
  const collectionName = 'qdrant_dart_example';
  var created = false;

  try {
    created = await client.collections.create(
      collectionName,
      vectors: CollectionVectors.dense(
        DenseVectorParams(size: 4, distance: Distance.cosine),
      ),
    );
    await client.payloadIndexes.create(
      collectionName,
      'year',
      schema: PayloadSchemaType.integer,
    );
    await client.points.upsert(collectionName, [
      Point(
        id: 1,
        vector: [0.9, 0.1, 0.1, 0.2],
        payload: {'title': 'The Matrix', 'year': 1999},
      ),
    ]);
    await client.points.setPayload(
      collectionName,
      {'featured': true},
      PointSelector.ids([1]),
    );

    final matches = await client.points.query(
      collectionName,
      DenseVector([0.9, 0.1, 0.1, 0.2]),
      filter: Filter(
        must: [FieldCondition.match('year', 1999)],
      ),
      withPayload: true,
    );
    print(matches.single.payload?['title']);
  } finally {
    try {
      if (created) {
        await client.collections.delete(collectionName);
      }
    } finally {
      client.close(force: true);
    }
  }
}
