#!/usr/bin/env bash

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

# find_files is a helper to exclude .git directories and match only regular
# files to avoid double-processing symlinks.
find_files() {
  local pth="$1"
  shift
  find "${pth}" -path ./.git/ -prune -o -type f "$@"
}

# Compatibility with both GNU and BSD style xargs.
compat_xargs() {
  local compat=()
  if xargs --no-run-if-empty </dev/null 2>/dev/null; then
    compat=("--no-run-if-empty")
  fi
  xargs "${compat[@]}" "$@"
}

# This function makes sure that the required files for
# releasing to OSS are present
function basefiles() {
  local fn required_files="LICENSE README.md"
  echo "Checking for required files ${required_files}"
  for fn in ${required_files}; do
    test -f "${fn}" || echo "Missing required file ${fn}"
  done
}

# This function runs the hadolint linter on
# every file named 'Dockerfile'
function docker() {
  echo "Running hadolint on Dockerfiles"
  find_files . -name "Dockerfile" -print0 \
    | compat_xargs -0 hadolint
}

# This function runs 'terraform validate' against all
# directory paths which contain *.tf files.
function check_terraform() {
  echo "Running terraform validate"
  find_files . -name "*.tf" -print0 \
    | compat_xargs -0 -n1 dirname \
    | sort -u \
    | compat_xargs -n1 terraform validate --check-variables=false
}

# This function runs 'go fmt' and 'go vet' on every file
# that ends in '.go'
function golang() {
  echo "Running go fmt and go vet"
  find_files . -name "*.go" -print0 | compat_xargs -0 -n1 go fmt
  find_files . -name "*.go" -print0 | compat_xargs -0 -n1 go vet
}

# This function runs the flake8 linter on every file
# ending in '.py'
function check_python() {
  echo "Running flake8"
  find_files . -name "*.py" -print0 | compat_xargs -0 flake8
  return 0
}

# This function runs the shellcheck linter on every
# file ending in '.sh'
function check_shell() {
  echo "Running shellcheck"
  find_files . -name "*.sh" -print0 | compat_xargs -0 shellcheck -x
}

# This function makes sure that there is no trailing whitespace
# in any files in the project.
# There are some exclusions
function check_trailing_whitespace() {
  echo "The following lines have trailing whitespace"
  grep -r '[[:blank:]]$' --exclude-dir=".terraform" --exclude-dir=".kitchen" --exclude="*.png" --exclude="*.pyc" --exclude-dir=".git" .
  rc=$?
  if [[ ${rc} -eq 0 ]]; then
    return 1
  fi
}

function generate_docs() {
  echo "Generating markdown docs with terraform-docs"
  find_files . -name "*.tf" -print0 \
    | compat_xargs -0 -n1 dirname \
    | sort -u \
    | compat_xargs -I% -n1 helpers/combine_docfiles.sh -t %/README.md -r %
}

function prepare_test_variables() {
  echo "Preparing terraform.tfvars files for integration tests"
  #shellcheck disable=2044
  for i in $(find ./test/fixtures -type f -name terraform.tfvars.sample); do
    destination=${i/%.sample/}
    if [ ! -f "${destination}" ]; then
      cp "${i}" "${destination}"
      echo "${destination} has been created. Please edit it to reflect your GCP configuration."
    fi
  done
}
