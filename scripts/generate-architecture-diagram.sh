#!/usr/bin/env bash

set -e

d2 --layout elk --sketch \
  --elk-nodeNodeBetweenLayers 90 \
  --elk-edgeNodeBetweenLayers 50 \
  docs/architecture.d2 docs/architecture.png

shasum -a 256 docs/architecture.d2 >docs/architecture.sha256
