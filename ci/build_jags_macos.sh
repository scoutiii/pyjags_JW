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

BREW_PREFIX="$(brew --prefix)"
# Ensure Homebrew's gcc (and gfortran) are preferred over Apple clang.
export PATH="${BREW_PREFIX}/opt/gcc/bin:${PATH}"
# gfortran is required by JAGS' build; Homebrew installs it alongside gcc.
if command -v gfortran >/dev/null 2>&1; then
  export FC="$(command -v gfortran)"
  export F77="$FC"
else
  # Fallback to the versioned binary name used by Homebrew bottles.
  export FC="${BREW_PREFIX}/bin/gfortran-14"
  export F77="$FC"
fi
# Help the linker find libgfortran/libquadmath from Homebrew gcc.
export LDFLAGS="-L${BREW_PREFIX}/opt/gcc/lib/gcc/current ${LDFLAGS:-}"
export CPPFLAGS="-I${BREW_PREFIX}/opt/gcc/include ${CPPFLAGS:-}"

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
