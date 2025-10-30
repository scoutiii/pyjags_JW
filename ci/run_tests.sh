#!/bin/bash
set -euxo pipefail

PROJECT_ROOT="$1"
TEMP_ROOT="$2"

TEST_WORKDIR="${TEMP_ROOT}/pyjags-tests"
rm -rf "${TEST_WORKDIR}"
mkdir -p "${TEST_WORKDIR}"

cp -a "${PROJECT_ROOT}/test/." "${TEST_WORKDIR}/"

cd "${TEST_WORKDIR}"
pytest -q | tee "${TEMP_ROOT}/pytest.log"
