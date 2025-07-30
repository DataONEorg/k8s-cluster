#!/usr/bin/env bash

## HELM-based utility functions for Kubernetes operations. You can source this file in your shell
# session, or you can copy functions to your ~/.zshrc or ~/.bashrc for repeated access


## Get the values of a Helm release and filter by a specific YAML key. Using --all will return all
## values that match the filter, not just user-overridden values.
## Usage:
##   helm-get-values-filter-by [release-name] [yaml-key] [--all]
## Example:
##   helm-get-values-filter-by metacatarctic "image" --all
##
## This will return all values for the specified key across all releases that match the filter.
##
helm-get-values-filter-by() {
  if [ -z "$1" ]; then
    echo "usage: helm-get-values-filter-by [release-name] [yaml-key] [--all]"
    echo "NOTE: make sure you're in the correct context and namespace"
    return 1
  fi
  release=$1
  filter_by=$2
  expr=$(printf '.. | select(has("%s")) | {"path": path, "%s": .["%s"]}' "$filter_by" "$filter_by" "$filter_by")
  helm get values "$release" $3 | yq eval "$expr" -
}


## #NOTE: MUST BE RUN AS ADMIN (dev-k8s or prod-k8s)
## List all images deployed by all Helm releases, and if an `alert-match` string is provided,
## highlight matching images in the output.
## Usage:
## $ helm-list-images-filter-by [alert-match]
##
## Example: to find any bitnami images that are not sourced form the bitnamilegacy repo:
## $ helm-list-images-filter-by "bitnami/"
## #...will highlight:
##    ⚠️   Image: docker.io/bitnami/pgbouncer:1.16.1 ⚠️
## #...but will not highlight:
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
