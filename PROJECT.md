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

Milestones 0 through 2 are complete through v0.2.0. The next releases favor
production data management before advanced hybrid-query features.

### Milestone 0: foundation (complete)

- Choose and document the first supported Qdrant server version.
- Add a Docker-backed integration test harness.
- Implement the client configuration and error model only after those tests
  exist.

### Milestone 1: usable search client (complete for v0.1.0)

- Collection lifecycle.
- Point upsert, retrieve, delete, scroll, and query.
- Payload filters and pagination helpers.
- README examples exercised by integration tests.

### Milestone 2: extensible search model (complete for v0.2.0)

- Make one controlled pre-1.0 revision to the vector and filter models before
  their current default-dense-vector shape becomes entrenched.
- Add named dense and sparse vector configuration, values, and selectors.
- Introduce extensible filter conditions while retaining convenient match and
  range construction.
- Add payload-index lifecycle so production users can create indexes before
  ingesting filtered data.
- Exercise typed server failures against both the minimum supported and current
  target Qdrant versions in CI.

### Milestone 3: production data lifecycle (v0.3.0)

- Set, overwrite, delete, and clear payload data.
- Update and delete vectors without replacing entire points.
- Delete points by filter and expose count operations.
- Add bounded, chunked ingestion helpers without hiding Qdrant update results.

### Milestone 4: hybrid queries (v0.4.0)

- Extend the Query API with named and sparse queries.
- Add prefetch and reciprocal-rank or distribution-based score fusion.
- Cover one complete dense-plus-sparse hybrid-search flow against Qdrant.

### Milestone 5: production operations (v0.5.0)

- Add collection aliases and only the collection tuning requested by real
  deployments.
- Add a Qdrant Cloud smoke test without introducing cloud-specific public APIs.
- Defer snapshots, shard administration, and cluster management until user
  demand justifies their maintenance cost.

### Stable API (v1.0.0)

- Publish a compatibility and deprecation policy.
- Freeze the core vector, filter, collection, and point models.
- Complete migration guidance and end-to-end examples.

Evaluate gRPC with a benchmark before accepting its dependency and platform
complexity. Embeddings, RAG orchestration, and ORM behavior remain non-goals.

## Release bar

An endpoint is release-ready only when it has:

1. A focused public API and example.
2. A real-server integration test.
3. Typed, documented failure behaviour.
4. A compatibility declaration in the release notes.
