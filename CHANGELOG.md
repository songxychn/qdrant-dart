# Changelog

## 0.3.0 - 2026-07-17

- Added payload set, overwrite, key deletion, and clear operations for point-ID
  and filter selectors.
- Added partial default, named dense, and sparse vector updates plus named
  vector deletion without replacing the rest of a point.
- Added filter-based point deletion and exact or approximate point counts.
- Added bounded sequential batch upserts that return every Qdrant
  `UpdateResult` in request order.
- Added real-server coverage for every new operation against the minimum
  supported `qdrant/qdrant:v1.12.0` and target `qdrant/qdrant:v1.18.2`
  images.

This release completes the production data lifecycle milestone. Its public
surface remains REST-first and standard-library-only; it does not add retries,
concurrent ingestion, embeddings, or framework-specific abstractions.

## 0.2.0 - 2026-07-17

- Added named dense and sparse vector configuration, point values, response
  selectors, and queries.
- Added extensible filter conditions with nested Boolean groups and point-ID
  matching while retaining `FieldCondition.match` and `FieldCondition.range`.
- Added payload-index creation, inspection, and deletion for keyword, integer,
  float, geo, text, bool, datetime, and UUID fields.
- Added real-server failure checks and compatibility coverage against the
  minimum supported `qdrant/qdrant:v1.12.0` and target
  `qdrant/qdrant:v1.18.2` images.

This release makes the planned pre-1.0 vector-model revision. Replace
`VectorParams` with `CollectionVectors.dense(DenseVectorParams(...))`, wrap
query values in `DenseVector` or `SparseVector`, and replace `withVector` with
`withVectors` plus a `VectorSelector`. Default dense `Point` construction and
the `PointRecord.vector` convenience getter remain available.

## 0.1.0 - 2026-07-16

- Added HTTP/HTTPS client configuration, API-key authentication, request
  timeouts, and typed `QdrantException` failures.
- Added collection create, inspect, list, and delete operations for one default
  dense vector configuration.
- Added point upsert, retrieval, ID-based deletion, ID-ordered scrolling, and
  automatic scroll pagination.
- Added dense-vector queries with match and numeric range payload filters using
  `must`, `should`, and `must_not` clauses.
- Added Docker-backed compatibility tests against `qdrant/qdrant:v1.18.2`.

Compatibility is limited to the documented v0.1 surface. Named and sparse
vectors, nested filters, collection tuning, gRPC, and administrative endpoints
are not supported in this release.
