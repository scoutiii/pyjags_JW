# Use the official manylinux base (2.28 recommended; you can switch to 2014 if you need older glibc)
ARG BASE=quay.io/pypa/manylinux_2_28_x86_64
FROM ${BASE}

# Install build deps: compilers, BLAS/LAPACK, pkg-config, curl
# 2.28 images are based on AlmaLinux 9 → use dnf
RUN dnf -y update && \
    dnf -y install \
      gcc gcc-c++ gcc-gfortran \
      make pkgconfig \
      openblas-devel lapack-devel \
      curl tar ca-certificates && \
    dnf clean all

# Build & install latest JAGS to /opt/jags
WORKDIR /tmp/jagsbuild
RUN set -eux; \
    curl -Ls -o jags.tar.gz https://sourceforge.net/projects/mcmc-jags/files/JAGS/latest/download; \
    tar -xf jags.tar.gz; \
    cd JAGS-*; \
    ./configure --prefix=/opt/jags --disable-static \
      --with-blas='-lopenblas' --with-lapack='-lopenblas'; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/jagsbuild

# Expose pkg-config for /opt/jags
ENV PKG_CONFIG_PATH=/opt/jags/lib/pkgconfig
