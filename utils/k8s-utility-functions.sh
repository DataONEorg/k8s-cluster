#!/usr/bin/env bash

# This script contains utility functions for Kubernetes operations.

## List all images deployed on the cluster, across all namespaces, grouped by Helm release name
## Optionally provide a command-line4 argument to highlight images whose descriptor matches a
## specific string.
## Examples:
##   helm-list-images-filter-by "bitnami/"
## ...will highlight:
##    ⚠️   Image: docker.io/bitnami/pgbouncer:1.16.1 ⚠️
##
## ...but will not highlight:
##    🐳  Image: docker.io/bitnamilegacy/postgresql:17.5.0-debian-12-r20
##
helm-list-images-filter-by() {
  local alert_match="$1"

  echo "🔍 Collecting Helm releases and deployed images..."

  helm list -A -o json | jq -r '.[] | [.name, .namespace] | @tsv' | while IFS=$'\t' read -r release namespace; do
    echo "☸️  Helm Release: $release (Namespace: $namespace)"

    manifest=$(helm get manifest "$release" -n "$namespace" 2>/dev/null)

    if [[ -z "$manifest" ]]; then
      echo "    ❌  No manifest found or chart has no resources."
      echo ""
      continue
    fi

    tmpfile=$(mktemp)
    echo "$manifest" > "$tmpfile"

    # Primary extraction: yq, remove '---' just in case
    images=$(yq e 'select(type == "!!map") | .. | select(has("image")) | .image' "$tmpfile" 2>/dev/null \
      | grep -v '^---$' \
      | sort -u)

    if [[ -z "$images" ]]; then
      images=$(grep -E '^\s*image:\s*' "$tmpfile" \
          | sed 's/.*image:[ ]*//' \
          | grep -vE '^\s*$|^---$' \
          | sort -u)     images=$(grep -E '^\s*image:\s*' "$tmpfile" | sed 's/.*image:[ ]*//' | sort -u)
    fi

    if [[ -z "$images" ]]; then
      echo "    ❌  No images found in manifest."
    else
      while IFS= read -r img; do
        if [[ -n "$alert_match" && "$img" == *"$alert_match"* ]]; then
          echo "    ⚠️   Image: $img ⚠️"
        else
          echo "    🐳  Image: $img"
        fi
      done <<< "$images"
    fi

    echo ""
    rm -f "$tmpfile"
  done
}
