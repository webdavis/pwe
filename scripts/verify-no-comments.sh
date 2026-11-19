#!/usr/bin/env bash

failed=false

git grep --untracked -nE '^[[:space:]]*(//|/\*)' -- '*.rs' && failed=true
git grep --untracked -nE '^[[:space:]]*#' -- justfile '*.toml' && failed=true
git grep --untracked -nE '^[[:space:]]*--' -- '*.lua' && failed=true

if $failed; then
  echo "error: comments are not allowed" >&2
  exit 1
fi
