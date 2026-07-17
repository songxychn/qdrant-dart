# qdrant_dart

An idiomatic, REST-first Dart SDK for [Qdrant](https://qdrant.tech/).

> **Status:** v0.1.0 is release-ready for collection lifecycle and core point
> operations with default dense vectors.

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
by the compatibility harness.

The SDK supports HTTP/HTTPS client configuration, API-key authentication,
request timeouts, typed failure reporting, and collection lifecycle operations
plus point upsert, retrieval, ID-based deletion, ID-ordered scrolling, and
dense-vector queries with match/range payload filters, nested Boolean groups,
and point-ID conditions against `qdrant/qdrant:v1.18.2`. Collection creation
and point operations support one default dense vector or named dense and sparse
vectors, and payload indexes can be created, inspected, and deleted.
Sparse-vector configuration currently uses Qdrant's defaults; nested payload
filters and collection tuning are not yet supported.

## Client setup

Use the client only in a trusted Dart service or CLI. Read API keys from the
server-side environment rather than embedding them in a Flutter or browser
application.

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
  final update = await client.points.upsert('movies', [
    Point(
      id: 1,
      vector: [0.9, 0.1, 0.1, 0.2],
      payload: {'title': 'The Matrix', 'year': 1999},
    ),
  ]);
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
  await client.points.delete('movies', [1]);
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
final sparseMatches = await client.points.query(
  'documents',
  SparseVector(indices: [1, 5], values: [0.8, 0.4]),
  using: 'keywords',
  withVectors: VectorSelector.named(['text']),
);
```

When an operation fails, catch [QdrantException]. It includes the HTTP status
when Qdrant responded, its error message when available, and the request method
and URL. It never includes the API key.

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
