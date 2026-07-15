# Project charter

## Mission

Make Qdrant pleasant and dependable to call from Dart without hiding its data
model or turning the SDK into an AI framework.

The project succeeds when a Dart backend can create a collection, write points,
query them with filters, and upgrade Qdrant with confidence because the same
flows run against a real server in CI.

## Intended users

- Dart server applications and command-line tools.
- Flutter projects only through a trusted application backend or an
  application-controlled Qdrant deployment.
- Teams using self-hosted Qdrant or Qdrant Cloud who want a maintained Dart
  package rather than raw generated stubs.

## Non-goals

- No direct mobile/browser use of privileged Qdrant credentials.
- No embedded/local Qdrant implementation.
- No embedding-model provider, RAG chain, LangChain wrapper, or vector ORM.
- No feature-parity promise before a feature has integration coverage.

## Technical direction

Start with the HTTP API: it is easy to inspect, works in ordinary Dart
deployments, and keeps the first release focused. Prefer `dart:convert` and the
Dart standard library until a concrete transport need proves otherwise.

The SDK's public surface should be narrow and resource-oriented. It should
return Qdrant concepts instead of inventing a second query language. Errors
must preserve HTTP status, Qdrant's response message when present, and the
request context needed for debugging without exposing API keys.

## Delivery sequence

### Milestone 0: foundation

- Choose and document the first supported Qdrant server version.
- Add a Docker-backed integration test harness.
- Implement the client configuration and error model only after those tests
  exist.

### Milestone 1: usable search client

- Collection lifecycle.
- Point upsert, retrieve, delete, scroll, and query.
- Payload filters and pagination helpers.
- README examples exercised by integration tests.

### Milestone 2: broaden deliberately

- Add only requested, tested endpoint families.
- Evaluate gRPC with a benchmark before accepting its dependency and platform
  complexity.

## Release bar

An endpoint is release-ready only when it has:

1. A focused public API and example.
2. A real-server integration test.
3. Typed, documented failure behaviour.
4. A compatibility declaration in the release notes.

