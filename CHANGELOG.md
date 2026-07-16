# Changelog

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
