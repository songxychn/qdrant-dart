# qdrant_dart

An idiomatic, REST-first Dart SDK for [Qdrant](https://qdrant.tech/).

> **Status:** v0.6.0 is the release-ready API candidate for v1. It covers
> collection lifecycle, production data maintenance, atomic aliases, bounded
> indexing-threshold tuning, and dense/sparse search with prefetch and RRF.

## Why this exists

Qdrant has an OpenAPI and gRPC interface, but Dart developers need more than
generated protocol classes: a small, predictable client with typed errors,
practical pagination, and real compatibility checks against Qdrant.

`qdrant_dart` targets trusted Dart services, CLIs, and controlled application
backends. Do not put a Qdrant Cloud API key in a mobile or browser app.

## Product boundary

- REST is the first transport. gRPC is a later performance feature, not a
  prerequisite for a usable SDK.
- The public API is handwritten and Dart-idiomatic; protocol generation, if
  used, stays an internal implementation detail.
- Qdrant remains the database and the source of API semantics. This package
  will not add local vector storage, embedding generation, ORM behaviour, or a
  RAG framework.
- Each supported endpoint must be covered by a real Qdrant integration test,
  not only mocked HTTP tests.

## v0.1 scope

1. Client configuration, API-key authentication, timeouts, and typed errors.
2. Collections: create, inspect, list, and delete.
3. Points: upsert, retrieve, delete, scroll, and query with payload filters.
4. A Docker-backed compatibility suite pinned to a declared Qdrant version.

gRPC, cluster administration, snapshots, shard management, and local embedding
inference are explicitly out of scope for v0.1.

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Compatibility

Development is verified against a minimum supported Qdrant `v1.12.0` and the
current target `v1.18.2`. [`tool/qdrant-min-version`](tool/qdrant-min-version)
and [`tool/qdrant-version`](tool/qdrant-version) are the sources of truth used
by the compatibility harness. Collection point and indexed-vector counts are
nullable because supported Qdrant versions may omit those statistics. Vector
values and filter conditions are SDK-owned hierarchies; callers should not
assume the currently exported subtypes are exhaustive.

The SDK supports HTTP/HTTPS client configuration, API-key authentication,
request timeouts, typed failure reporting, and collection lifecycle operations
including atomic alias creation, deletion, and renaming,
plus point upsert, retrieval, ID- or filter-based deletion, exact or
approximate counts, ID-ordered scrolling, and dense- or sparse-vector queries
with match/range payload filters, nested Boolean groups, and point-ID
conditions against `qdrant/qdrant:v1.18.2`. Payload data can be set,
overwritten, partially deleted, or cleared by point IDs or filters.
Collection creation and point operations support one default dense vector or
named dense and sparse vectors. A default dense vector can also be stored with
named sparse vectors, including an empty sparse vector. Payload indexes can be
created, inspected, and deleted. Selected vectors can be updated or named
vectors deleted without replacing the rest of a point. Sparse-vector
configuration currently uses Qdrant's defaults; nested payload filters and
collection tuning beyond the optimizer indexing threshold are not yet
supported. Large point iterables can
be upserted in bounded sequential batches without hiding any per-batch update
result. Query prefetches can select
candidates with one vector before the main vector reranks them, or combine
dense and sparse rankings with Reciprocal Rank Fusion (RRF).

## Client setup

Use the client only in a trusted Dart service or CLI. Read API keys from the
server-side environment rather than embedding them in a Flutter or browser
application. Pass credentials through `apiKey`; URLs containing user info are
rejected so credentials cannot leak through request diagnostics.

```dart
import 'dart:io';

import 'package:qdrant_dart/qdrant_dart.dart';

final client = QdrantClient(
  baseUrl: Uri.parse('https://your-qdrant.example'),
  apiKey: Platform.environment['QDRANT_API_KEY'],
);

try {
  await client.collections.create(
    'movies',
    vectors: CollectionVectors.dense(
      DenseVectorParams(size: 4, distance: Distance.cosine),
    ),
  );
  await client.payloadIndexes.create(
    'movies',
    'year',
    schema: PayloadSchemaType.integer,
  );
  await client.collections.updateIndexingThreshold('movies', 0);
  final update = await client.points.upsert('movies', [
    Point(
      id: 1,
      vector: [0.9, 0.1, 0.1, 0.2],
      payload: {'title': 'The Matrix', 'year': 1999},
    ),
    Point(
      id: 2,
      vector: [0.1, 0.9, 0.2, 0.1],
      payload: {'title': 'The Matrix Reloaded', 'year': 2003},
    ),
  ]);
  await client.collections.updateIndexingThreshold('movies', 20000);
  print(update.status);
  final stored = await client.points.retrieve(
    'movies',
    [1],
    withVectors: const VectorSelector.all(),
  );
  print(stored.single.payload?['title']);
  await for (final point in client.points.scrollAll('movies')) {
    print(point.id);
  }
  final matches = await client.points.query(
    'movies',
    DenseVector([0.9, 0.1, 0.1, 0.2]),
    filter: Filter(
      must: [
        HasIdCondition([1]),
        FieldCondition.match('year', 1999),
      ],
    ),
    withPayload: true,
  );
  print(matches.single.score);
  await client.points.setPayload(
    'movies',
    {'featured': true},
    PointSelector.ids([1]),
  );
  await client.points.overwritePayload(
    'movies',
    {'title': 'The Matrix', 'year': 1999},
    PointSelector.ids([1]),
  );
  await client.points.deletePayload(
    'movies',
    ['year'],
    PointSelector.ids([1]),
  );
  await client.points.clearPayload(
    'movies',
    PointSelector.filter(
      Filter(must: [FieldCondition.match('title', 'The Matrix')]),
    ),
  );
  print(await client.points.count('movies'));
  await client.points.deleteByFilter(
    'movies',
    Filter(must: [FieldCondition.range('year', gte: 2000)]),
  );
  await client.points.delete('movies', [1]);
  await client.aliases.update([
    CollectionAliasAction.create(
      collectionName: 'movies',
      aliasName: 'current_movies',
    ),
  ]);
  print((await client.aliases.list(collectionName: 'movies')).single.aliasName);
  await client.aliases.update([
    CollectionAliasAction.delete('current_movies'),
  ]);
  await client.payloadIndexes.delete('movies', 'year');
  final movies = await client.collections.get('movies');
  print(movies.pointsCount);
  await client.collections.delete('movies');
} finally {
  client.close();
}
```

Named dense and sparse vectors share the same point and query APIs:

```dart
await client.collections.create(
  'documents',
  vectors: CollectionVectors.named(
    dense: {
      'text': DenseVectorParams(size: 4, distance: Distance.cosine),
    },
    sparse: const {'keywords': SparseVectorParams()},
  ),
);
await client.points.upsert('documents', [
  Point.named(
    id: 1,
    vectors: {
      'text': DenseVector([0.9, 0.1, 0.1, 0.2]),
      'keywords': SparseVector(indices: [1, 5], values: [0.8, 0.4]),
    },
  ),
]);
await client.points.updateVectors('documents', [
  PointVectorUpdate.named(
    id: 1,
    vectors: {'text': DenseVector([0.8, 0.2, 0.1, 0.3])},
  ),
]);
final sparseMatches = await client.points.query(
  'documents',
  SparseVector(indices: [1, 5], values: [0.8, 0.4]),
  using: 'keywords',
  withVectors: VectorSelector.named(['text']),
);
final reranked = await client.points.query(
  'documents',
  DenseVector([0.8, 0.2, 0.1, 0.3]),
  prefetch: [
    Prefetch(
      query: SparseVector(indices: [1, 5], values: [0.8, 0.4]),
      using: 'keywords',
      limit: 20,
    ),
  ],
  using: 'text',
);
final hybridMatches = await client.points.queryRrf(
  'documents',
  [
    Prefetch(
      query: DenseVector([0.8, 0.2, 0.1, 0.3]),
      using: 'text',
      limit: 20,
    ),
    Prefetch(
      query: SparseVector(indices: [1, 5], values: [0.8, 0.4]),
      using: 'keywords',
      limit: 20,
    ),
  ],
  withPayload: true,
);
await client.points.deleteVectors(
  'documents',
  ['keywords'],
  PointSelector.ids([1]),
);
```

Collections with a default dense vector can add named sparse vectors to the
same point:

```dart
await client.collections.create(
  'documents',
  vectors: CollectionVectors.dense(
    DenseVectorParams(size: 4, distance: Distance.cosine),
    sparse: const {'keywords': SparseVectorParams()},
  ),
);
final point = Point(
  id: 1,
  vector: [0.9, 0.1, 0.1, 0.2],
  sparseVectors: {
    'keywords': SparseVector(indices: [1, 5], values: [0.8, 0.4]),
  },
);
```

For larger inputs, bound each request without first copying the entire iterable:

```dart
final updates = await client.points.upsertInBatches(
  'documents',
  generatedPoints,
  batchSize: 100,
);
for (final update in updates) {
  print(update.status);
}
```

Batches are sent sequentially. If one request fails, Qdrant does not roll back
earlier successful batches.

When an operation fails, catch [QdrantException]. It includes the HTTP status
when Qdrant responded, its error message when available, and the request method
and URL. Successful responses that do not match the supported Qdrant protocol
are reported the same way, with the parsing failure in `cause`. It never
includes the API key.

## Versioning and compatibility policy

Until v1.0.0, minor releases may contain documented source-breaking changes
needed to make the API durable. Each such change includes migration notes in
the changelog.

Starting with v1.0.0, this package follows semantic versioning:

- Patch releases contain compatible fixes and documentation changes.
- Minor releases may add endpoints, optional parameters, methods, and
  SDK-owned implementation subtypes. Callers must not exhaustively switch on
  `VectorValue` or `FilterCondition`.
- Removing or changing public members, adding public enum values, raising the
  minimum Dart SDK, or raising the minimum supported Qdrant version requires a
  major release.
- A public member is normally deprecated for at least one minor release before
  removal in the next major release.

Every release declares the minimum supported and current target Qdrant
versions through the two files under `tool/` and runs the full integration
suite against both. CI also analyzes and unit-tests the package on Dart 3.0.7,
the current minimum SDK, and runs the full release bar on the latest stable
Dart SDK.

## Development

Install Dart and Docker, then run:

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test --exclude-tags integration
./tool/test-compatibility.sh
```

The compatibility script runs the real-server integration suite against both
declared Qdrant versions. Each image starts on a random localhost port and is
removed after its tests finish.

### Qdrant Cloud smoke test

The manual `Qdrant Cloud smoke test` workflow uses the same public client API
as a self-hosted server. Configure its `qdrant-cloud` GitHub Environment with
`QDRANT_URL` and `QDRANT_API_KEY` secrets, then trigger the workflow. The test
creates a uniquely named collection and alias, exercises tuning, write, and
query operations, and deletes the temporary resources even when an assertion
fails.

Run the same smoke test locally with trusted server-side credentials:

```sh
QDRANT_URL=https://your-cluster.example \
QDRANT_API_KEY=... \
./tool/test-cloud-smoke.sh
```

Do not expose either value in Flutter or browser code, logs, or repository
configuration.

## Releasing

Releases are tag-driven. Update `pubspec.yaml` and `CHANGELOG.md` in the same
commit, then create and push an annotated `v<version>` tag whose version exactly
matches the package version. The publish workflow reruns the full CI suite and,
only after it passes, uses GitHub OIDC and Dart's official reusable workflow to
publish to pub.dev. No long-lived publishing token is stored in GitHub.

Automated publishing must be enabled on the package's pub.dev Admin page for
the `songxychn/qdrant-dart` repository with tag pattern `v{{version}}` and the
required GitHub Actions environment `pub.dev`.

## For contributors and agents

Read [PROJECT.md](PROJECT.md) for the roadmap and [AGENTS.md](AGENTS.md) for
the delivery rules before adding code.
