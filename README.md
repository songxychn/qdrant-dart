# qdrant_dart

An idiomatic, REST-first Dart SDK for [Qdrant](https://qdrant.tech/).

> **Status:** foundation in progress. The Docker-backed compatibility harness
> is available, but the public API has not been implemented or published yet.

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
