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

set -e
set -u

usage() {
  echo "Usage: $0 -t README.md -r /tmp/foo.md"
  echo
  echo "Inserts replacement text in between autogen_docs_start"
  echo "and autogen_docs_end lines in file TEMPLATE."
  echo
  echo "Required arguments:"
  echo "  -t <TEMPLATE> The file to update.  Need not exist."
  echo "  -r <PATH> The text file or directory to insert into the template."
  echo "     See the -c [COMMAND] option if the path is a directory."
  echo
  echo "Optional arguments:"
  echo "  -s [EXCLUDE START] Start line exclusion pattern passed to sed"
  echo "     default: '^Copyright [[:digit:]]'"
  echo "  -e [EXCLUDE END] End line exclusion pattern passed to sed"
  echo "     default: 'limitations under the License'"
  echo "  -c [COMMAND] If <PATH> is a directory, execute COMMAND PATH to"
  echo "     produce the replacement text via standard output."
  echo "     default: 'terraform-docs markdown'"
  echo
  echo "     Lines between and including EXCLUDE START and EXCLUDE END are"
  echo "     excluded from the replacement text."
  echo
}

has_anchors() {
  local pth="${1:-/dev/null}"
  grep -q autogen_docs_start "${pth}" || return 1
  grep -q autogen_docs_end "${pth}" || return 2
}

check_anchors() {
  local pth="${1:-/dev/null}"
  if ! has_anchors "${pth}"; then
    echo "Error: ${pth} does not have anchor lines."
    usage
    exit 1
  fi
}

finish() {
  [[ -d "${DELETE_AT_EXIT:-}" ]] && rm -rf "${DELETE_AT_EXIT}"
}

main() {
  local OPTIND opt template replacement exclude_start exclude_end command
  exclude_start='^Copyright [[:digit:]]'
  exclude_end='limitations under the License'
  command='terraform-docs markdown'
  while getopts ":t:r:s:e:c:" opt; do
    case "${opt}" in
      t) template="${OPTARG}" ;;
      r) replacement="${OPTARG}" ;;
      s) exclude_start="${OPTARG}" ;;
      e) exclude_end="${OPTARG}" ;;
      c) command="${OPTARG}" ;;
    :)
      echo "Invalid argument: -${OPTARG} requires an argument" >&2
      usage
      return 1
      ;;
    *)
      echo "Unknown argument: ${opt}" >&2
      usage
      return 1
      ;;
    esac
  done

  if [[ -z "${template}" ]] || [[ -z "${replacement}" ]]; then
    echo "Missing required arugments -t or -r" >&2
    usage
    return 1
  fi

  DELETE_AT_EXIT="$(mktemp -d)"
  readonly DELETE_AT_EXIT
  TMPDIR="${DELETE_AT_EXIT}"
  trap finish EXIT

  # Avoid sed No such file or directory error
  if ! [[ -e "${template}" ]]; then
    echo '[^]: (autogen_docs_start)' > "${template}"
    echo '[^]: (autogen_docs_end)' >> "${template}"
  fi

  # If replacement is a directory, generate the replacement text
  if [[ -d "${replacement}" ]]; then
    local directory="${replacement}"
    replacement="$(mktemp)"
    ${command} "${directory}" > "${replacement}"
  fi

  newfile="$(mktemp)"
  # Read line 1 to start anchor.  sed is not used because it processes at least
  # two lines and therefore does not work with a line 1 start anchor.
  awk '/autogen_docs_start/ { print; exit; } { print }' "${template}" \
    > "${newfile}"
  # Read the replacement text, deleting the copyright.
  sed '/'"${exclude_start}"'/,/'"${exclude_end}"'/d' "${replacement}" \
    >> "${newfile}"
  # Read from end anchor to end of file
  sed -n '/autogen_docs_end/,$p' "${template}" \
    >> "${newfile}"

  # Update the file if it's different.
  if cmp -s "${template}" "${newfile}"; then
    echo "No changes made: ${template}" >&2
  else
    echo "Changes made: ${template}" >&2
    cat "${newfile}" > "${template}"
  fi
}

main "$@"
