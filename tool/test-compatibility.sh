#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for version_file in qdrant-min-version qdrant-version; do
  version=$(sed -n '1p' "$root_dir/tool/$version_file")
  QDRANT_VERSION="$version" "$root_dir/tool/test-integration.sh"
done
