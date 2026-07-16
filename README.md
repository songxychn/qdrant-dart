# qdrant_dart

An idiomatic, REST-first Dart SDK for [Qdrant](https://qdrant.tech/).

> **Status:** collection lifecycle plus point upsert, retrieval, deletion, and
> scrolling are available for default dense vectors; point queries are not yet
> implemented or published.

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

## First release: v0.1

1. Client configuration, API-key authentication, timeouts, and typed errors.
2. Collections: create, inspect, list, and delete.
3. Points: upsert, retrieve, delete, scroll, and query with payload filters.
4. A Docker-backed compatibility suite pinned to a declared Qdrant version.

gRPC, cluster administration, snapshots, shard management, and local embedding
inference are explicitly out of scope for v0.1.

## Compatibility

Development is verified against `qdrant/qdrant:v1.18.2`. The version in
[`tool/qdrant-version`](tool/qdrant-version) is the source of truth used by the
integration harness.

The SDK supports HTTP/HTTPS client configuration, API-key authentication,
request timeouts, typed failure reporting, and collection lifecycle operations
plus point upsert, retrieval, ID-based deletion, and ID-ordered scrolling
against `qdrant/qdrant:v1.18.2`. Collection creation and point operations
currently support one default dense vector; named/sparse vectors and collection
tuning are not yet supported.

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
    vectors: VectorParams(size: 4, distance: Distance.cosine),
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
    withVector: true,
  );
  print(stored.single.payload?['title']);
  await for (final point in client.points.scrollAll('movies')) {
    print(point.id);
  }
  await client.points.delete('movies', [1]);
  final movies = await client.collections.get('movies');
  print(movies.pointsCount);
  await client.collections.delete('movies');
} finally {
  client.close();
}
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
./tool/test-integration.sh
```

The integration script starts the pinned Qdrant image on a random localhost
port, runs the real-server tests, and removes the container afterward.

## For contributors and agents

Read [PROJECT.md](PROJECT.md) for the roadmap and [AGENTS.md](AGENTS.md) for
the delivery rules before adding code.
