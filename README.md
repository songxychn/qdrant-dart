# qdrant_dart

An idiomatic, REST-first Dart SDK for [Qdrant](https://qdrant.tech/).

> **Status:** project charter. The public API has not been implemented or
> published yet.

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

## For contributors and agents

Read [PROJECT.md](PROJECT.md) for the roadmap and [AGENTS.md](AGENTS.md) for
the delivery rules before adding code.

