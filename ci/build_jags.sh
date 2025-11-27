#!/bin/bash
set -euxo pipefail

JAGS_VERSION=4.3.1
PREFIX=/project/vendor/jags

mkdir -p /tmp/jags-src && cd /tmp/jags-src
curl -L -o jags.tar.gz "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Source/JAGS-${JAGS_VERSION}.tar.gz/download"
tar xf jags.tar.gz
cd JAGS-${JAGS_VERSION}

# manylinux has the compilers, but make sure headers/tools are present
yum install -y gcc gcc-c++ gcc-gfortran make automake libtool unzip \
  blas-devel lapack-devel >/dev/null

./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
make -j"$(nproc)"
make install
