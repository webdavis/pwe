#!/usr/bin/env bash

set -e

archify="${ARCHIFY:-$HOME/.omp/agent/skills/archify/bin/archify.mjs}"

rm -rf .archify

node "$archify" finalize architecture docs/architecture.json .archify/architecture.html --quality showcase
node "$archify" visual-check .archify/architecture.html --summary --require-provenance --out-dir .archify/visual-check

cp .archify/visual-check/architecture.visual-check.2048x1320.dark.png docs/architecture.png

shasum -a 256 docs/architecture.json >docs/architecture.sha256
