#!/usr/bin/env sh
set -eu

if [ -z "${QDRANT_URL:-}" ] || [ -z "${QDRANT_API_KEY:-}" ]; then
  echo "QDRANT_URL and QDRANT_API_KEY must be set." >&2
  exit 64
fi

dart test --tags integration test/cloud_smoke_test.dart
