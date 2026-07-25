#!/usr/bin/env bash
# 引数に渡した .vil(JSON)を jq で整形して上書きする。
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: format-vil.sh <file.vil>..." >&2; exit 1; }

for f in "$@"; do
  jq . "$f" > "$f.tmp" && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; exit 1; }
done
