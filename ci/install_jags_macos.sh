#!/usr/bin/env bash
set -euxo pipefail
# Use brew to get JAGS (shared libs), then point pkg-config at it
brew update
brew install jags pkg-config

echo BREW_PREFIX="$(brew --prefix)"
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

