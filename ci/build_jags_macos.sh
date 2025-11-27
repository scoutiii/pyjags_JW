#!/bin/bash
set -euxo pipefail

JAGS_VERSION=4.3.1
PREFIX=/tmp/jags

# Ensure Homebrew is available
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; macOS builds require Homebrew." >&2
  exit 1
fi

brew update
brew install -q gcc automake libtool pkg-config openblas

mkdir -p /tmp/jags-src && cd /tmp/jags-src
curl -L -o jags.tar.gz "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Source/JAGS-${JAGS_VERSION}.tar.gz/download"
tar xf jags.tar.gz
cd JAGS-${JAGS_VERSION}

./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib" --with-blas="-L/opt/homebrew/opt/openblas/lib -lopenblas" --with-lapack
make -j"$(sysctl -n hw.ncpu)"
make install

# Export pkg-config path for subsequent build steps
echo "PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}" >> "$GITHUB_ENV"
echo "PYJAGS_VENDOR_JAGS_ROOT=${PREFIX}" >> "$GITHUB_ENV"
