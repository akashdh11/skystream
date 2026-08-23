#!/usr/bin/env bash
set -euo pipefail

version="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
tag="${1:-${GITHUB_REF_NAME:-}}"
tag_version="${tag#v}"

if [[ -z "$tag" ]]; then
  echo "::error::Expected a tag argument or GITHUB_REF_NAME."
  exit 1
fi

if [[ "$version" != "$tag_version" ]]; then
  echo "::error::Tag $tag does not match pubspec version $version."
  exit 1
fi
