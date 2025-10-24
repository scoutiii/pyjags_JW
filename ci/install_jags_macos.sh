#!/usr/bin/env bash
set -euxo pipefail
PROJECT_ROOT="${1:?usage: install_jags_macos.sh <project_root>}"
: "${JAGS_VERSION:=4.3.2}"
: "${JAGS_PREFIX:=${PROJECT_ROOT}/.jags-prefix}"

mkdir -p "${JAGS_PREFIX}"

# Use system compilers; ensure basic tools
xcode-select -p >/dev/null

# GSL
curl -L -o /tmp/gsl.tar.gz https://ftp.gnu.org/gnu/gsl/gsl-2.7.1.tar.gz
tar -C /tmp -xf /tmp/gsl.tar.gz
pushd /tmp/gsl-2.7.1
./configure --prefix="${JAGS_PREFIX}"
make -j"$(sysctl -n hw.ncpu)"
make install
popd

# Accelerate provides BLAS/LAPACK on macOS; JAGS' configure detects it.

# JAGS
curl -L -o /tmp/jags.tar.gz https://sourceforge.net/projects/mcmc-jags/files/JAGS/${JAGS_VERSION}/JAGS-${JAGS_VERSION}.tar.gz/download
tar -C /tmp -xf /tmp/jags.tar.gz
pushd /tmp/JAGS-${JAGS_VERSION}
PKG_CONFIG_PATH="${JAGS_PREFIX}/lib/pkgconfig" \
LDFLAGS="-Wl,-rpath,@loader_path" \
./configure --prefix="${JAGS_PREFIX}" --with-blas --with-lapack --with-gsl-prefix="${JAGS_PREFIX}"
make -j"$(sysctl -n hw.ncpu)"
make install
popd

# Export pkg-config path so CMake can find jags.pc
echo "PKG_CONFIG_PATH=${JAGS_PREFIX}/lib/pkgconfig:\${PKG_CONFIG_PATH}" >> "${GITHUB_ENV:-/dev/null}" || true
export PKG_CONFIG_PATH="${JAGS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# FYI for delocate: leave rpaths; delocate will copy dylibs into the wheel
ls -l "${JAGS_PREFIX}/lib"
