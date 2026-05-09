#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
if [ -z "$version" ]; then
  echo "usage: scripts/prepare-release.sh <version>" >&2
  exit 1
fi

make artifact

source_zip="dist/apps/putio-roku-v2.zip"
if [ ! -f "$source_zip" ]; then
  echo "missing release artifact: $source_zip" >&2
  exit 1
fi

rm -rf dist/public dist/release
mkdir -p dist/public/releases/v2 dist/release

cp "$source_zip" "dist/public/v2.zip"
cp "$source_zip" "dist/public/releases/v2/${version}.zip"
cp "$source_zip" "dist/release/putio-roku-v${version}.zip"

echo "Prepared Roku release ${version}"
echo "- dist/public/v2.zip"
echo "- dist/public/releases/v2/${version}.zip"
echo "- dist/release/putio-roku-v${version}.zip"
