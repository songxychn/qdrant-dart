#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=${QDRANT_VERSION:-$(sed -n '1p' "$root_dir/tool/qdrant-version")}
image="qdrant/qdrant:v$version"
container="qdrant-dart-test-$$"

cleanup() {
  docker rm --force "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

docker run --detach --rm \
  --name "$container" \
  --publish 127.0.0.1::6333 \
  "$image" >/dev/null

port=$(docker port "$container" 6333/tcp | sed 's/.*://')
if [ -z "$port" ]; then
  echo "Could not determine the Qdrant test port." >&2
  exit 1
fi

cd "$root_dir"
QDRANT_URL="http://127.0.0.1:$port" \
  QDRANT_VERSION="$version" \
  dart test --tags integration test/integration
