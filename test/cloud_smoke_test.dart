import 'dart:io';

import 'package:qdrant_dart/qdrant_dart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Qdrant Cloud supports the production operations smoke flow',
    () async {
      final baseUrl = Uri.parse(_requiredEnvironment('QDRANT_URL'));
      final apiKey = _requiredEnvironment('QDRANT_API_KEY');
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final collectionName = 'qdrant_dart_cloud_$suffix';
      final aliasName = '${collectionName}_current';
      final client = QdrantClient(baseUrl: baseUrl, apiKey: apiKey);
      var collectionCreated = false;
      var aliasCreated = false;

      try {
        collectionCreated = await client.collections.create(
          collectionName,
          vectors: CollectionVectors.dense(
            DenseVectorParams(size: 2, distance: Distance.dot),
          ),
        );
        expect(collectionCreated, isTrue);
        expect(
          await client.collections.updateIndexingThreshold(collectionName, 0),
          isTrue,
        );
        aliasCreated = await client.aliases.update([
          CollectionAliasAction.create(
            collectionName: collectionName,
            aliasName: aliasName,
          ),
        ]);
        expect(aliasCreated, isTrue);

        final update = await client.points.upsert(collectionName, [
          Point(
            id: 1,
            vector: [1, 0],
            payload: {'source': 'qdrant_dart_cloud_smoke'},
          ),
        ]);
        expect(update.status, UpdateStatus.completed);
        final matches = await client.points.query(
          aliasName,
          DenseVector([1, 0]),
          withPayload: true,
        );
        expect(matches.single.id, 1);
        expect(matches.single.payload?['source'], 'qdrant_dart_cloud_smoke');
        expect(
          await client.collections.updateIndexingThreshold(
            collectionName,
            20000,
          ),
          isTrue,
        );
      } finally {
        try {
          if (aliasCreated) {
            await client.aliases.update([
              CollectionAliasAction.delete(aliasName),
            ]);
          }
        } finally {
          try {
            if (collectionCreated) {
              await client.collections.delete(collectionName);
            }
          } finally {
            client.close(force: true);
          }
        }
      }
    },
    tags: 'integration',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('$name must be set for the Qdrant Cloud smoke test.');
  }
  return value;
}
