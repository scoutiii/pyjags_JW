#!/usr/bin/env bash
set -euxo pipefail

PREFIX="/opt/jags"
mkdir -p /tmp/jags && cd /tmp/jags

# always fetch the latest release automatically
LATEST_URL=$(curl -Ls -o /dev/null -w '%{url_effective}' \
  https://sourceforge.net/projects/mcmc-jags/files/JAGS/latest/download)
curl -L -o jags.tar.gz "$LATEST_URL"

tar -xf jags.tar.gz
cd JAGS-*

./configure --prefix="${PREFIX}" --disable-static
make -j"$(nproc)"
make install

export PKG_CONFIG_PATH="/opt/jags/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CPPFLAGS="-I/opt/jags/include ${CPPFLAGS:-}"
export LDFLAGS="-L/opt/jags/lib ${LDFLAGS:-}"
echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

