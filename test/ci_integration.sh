#! /bin/bash
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Entry point for CI Integration Tests.  This script is expected to be run
# inside the same docker image specified in the CI Pipeline definition.

set -eu

# Always clean up.
DELETE_AT_EXIT="$(mktemp -d)"
finish() {
  kitchen destroy
  [[ -d "${DELETE_AT_EXIT}" ]] && rm -rf "${DELETE_AT_EXIT}"
}
trap finish EXIT

# inspec does not configure the environment for gcloud, so do it here.
CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$(mktemp)"
declare -rx CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE
echo "${GOOGLE_CREDENTIALS}" > "${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE}"

set -x

kitchen create
kitchen converge
kitchen verify
