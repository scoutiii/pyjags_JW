#!/usr/bin/env bash
set -euxo pipefail
PROJECT_ROOT="${1:?usage: install_jags_linux.sh <project_root>}"
: "${JAGS_VERSION:=4.3.2}"
: "${JAGS_PREFIX:=${PROJECT_ROOT}/.jags-prefix}"

mkdir -p "${JAGS_PREFIX}"

# manylinux has minimal tools; install basics
yum -y install wget make gcc gcc-c++ tar which gzip bzip2 xz || true

# BLAS/LAPACK for JAGS (OpenBLAS is available in manylinux images)
# If not present, build a minimal OpenBLAS
if ! ldconfig -p | grep -q libopenblas || [ ! -f /usr/lib64/libopenblas.so ]; then
  curl -L -o /tmp/openblas.tar.gz https://github.com/xianyi/OpenBLAS/archive/refs/tags/v0.3.21.tar.gz
  tar -C /tmp -xf /tmp/openblas.tar.gz
  pushd /tmp/OpenBLAS-0.3.21
  make NO_SHARED=0 USE_OPENMP=0
  make install PREFIX=/usr
  popd
fi

# GSL (dependency of JAGS)
curl -L -o /tmp/gsl.tar.gz https://ftp.gnu.org/gnu/gsl/gsl-2.7.1.tar.gz
tar -C /tmp -xf /tmp/gsl.tar.gz
pushd /tmp/gsl-2.7.1
./configure --prefix="${JAGS_PREFIX}"
make -j"$(nproc)"
make install
popd

# JAGS
curl -L -o /tmp/jags.tar.gz https://sourceforge.net/projects/mcmc-jags/files/JAGS/${JAGS_VERSION}/JAGS-${JAGS_VERSION}.tar.gz/download
tar -C /tmp -xf /tmp/jags.tar.gz
pushd /tmp/JAGS-${JAGS_VERSION}
PKG_CONFIG_PATH="${JAGS_PREFIX}/lib/pkgconfig" \
LDFLAGS="-Wl,-rpath,\$ORIGIN" \
./configure --prefix="${JAGS_PREFIX}" --with-blas --with-lapack --with-gsl-prefix="${JAGS_PREFIX}"
make -j"$(nproc)"
make install
popd

# Export pkg-config path so CMake can find jags.pc
echo "PKG_CONFIG_PATH=${JAGS_PREFIX}/lib/pkgconfig:\${PKG_CONFIG_PATH}" >> "${GITHUB_ENV:-/dev/null}" || true
export PKG_CONFIG_PATH="${JAGS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Show what we built
ls -l "${JAGS_PREFIX}/lib"
