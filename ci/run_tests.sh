#!/bin/bash
set -euxo pipefail

PROJECT_ROOT="$1"
TEMP_ROOT="$2"

# CIBW leaves {tmpdir} untouched in our config; fall back to a real temp dir.
if [ -z "${TEMP_ROOT}" ] || [ "${TEMP_ROOT}" = "{tmpdir}" ]; then
  TEMP_ROOT="$(mktemp -d)"
fi

# Normalize to an absolute path so subsequent 'cd' doesn't break logging.
mkdir -p "${TEMP_ROOT}"
TEMP_ROOT="$(cd "${TEMP_ROOT}" && pwd)"

TEST_WORKDIR="${TEMP_ROOT}/pyjags-tests"
rm -rf "${TEST_WORKDIR}"
mkdir -p "${TEST_WORKDIR}"

cp -a "${PROJECT_ROOT}/test/." "${TEST_WORKDIR}/"

cd "${TEST_WORKDIR}"
pytest -q | tee "${TEMP_ROOT}/pytest.log"
