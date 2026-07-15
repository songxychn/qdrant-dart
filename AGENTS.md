# Agent guide

## First read

Read `README.md` and `PROJECT.md` before proposing or changing code. This is a
client SDK, not a vector database or RAG framework.

## Working rules

1. Deliver one endpoint family or one cross-cutting concern per change.
2. Do not add an endpoint without a Docker-backed test against Qdrant.
3. Prefer REST and Dart standard-library facilities for v0.1. Do not add gRPC,
   code generation, retry frameworks, or abstraction layers speculatively.
4. Keep public types small and Dart-idiomatic. Preserve Qdrant terms where
   they carry semantics.
5. Never log API keys or encourage privileged credentials in Flutter/web apps.
6. Update the README example and compatibility note with every public feature.

## Scope guardrails

- `v0.1` is collections plus core point operations only.
- Do not add embeddings, local storage, a query DSL, framework adapters, or
  cloud-specific convenience APIs.
- If Qdrant documentation and observed server behaviour disagree, add a
  reproducer and report the discrepancy; do not guess.

## Definition of done

Run formatting, static analysis, unit tests, and the relevant real-server
integration tests. Record the Qdrant image/version used. A mocked-only test is
not sufficient for endpoint support.

