#!/bin/bash
set -euxo pipefail

# Ensure brew is available
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; macOS builds require Homebrew." >&2
  exit 1
fi

# Install JAGS and toolchain deps (provides gfortran)
brew update
brew install jags pkg-config gcc

# Nothing else to do: pkg-config will point CMake at the brewed JAGS prefix,
# and the build system will vendor the resulting libraries into the wheel.
