#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
mkdir -p .output/payload
npm ci --ignore-scripts
# Use the pinned upstream Hugo release directly on GitHub-hosted runners.
curl -fL --retry 3 https://github.com/gohugoio/hugo/releases/download/v0.128.2/hugo_extended_0.128.2_linux-amd64.tar.gz -o /tmp/hugo.tar.gz
curl -fL --retry 3 https://github.com/gohugoio/hugo/releases/download/v0.128.2/hugo_0.128.2_checksums.txt -o /tmp/hugo-checksums.txt
(cd /tmp && mv hugo.tar.gz hugo_extended_0.128.2_linux-amd64.tar.gz && sha256sum --check --ignore-missing hugo-checksums.txt)
tar -xzf /tmp/hugo_extended_0.128.2_linux-amd64.tar.gz -C node_modules/.bin hugo
npm run docs:build
test -s public/index.html
cp -a public .output/payload/site
