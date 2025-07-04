#!/usr/bin/env bash

###############################################################################
# Copyright 2024 Justin Keller
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

set -eo pipefail; [[ $TRACE ]] && set -x

readonly VERSION="2.4.0"
readonly OPENSSL_CIPHER_TYPE="aes-256-cbc"

cryptr_version() {
  echo "cryptr $VERSION"
}

cryptr_help() {
  echo "Usage: cryptr command <command-specific-options>"
  echo
  cat<<EOF | column -c2 -t -s,
  encrypt <file>, Encrypt file
  decrypt <file.aes> [--stdout], Decrypt encrypted file
  help, Displays help
  version, Displays the current version
EOF
  echo
}

cryptr_encrypt() {
  local _file="$1"
  if [[ ! -f "$_file" ]]; then
    echo "File not found" 1>&2
    exit 4
  fi

  if [[ -n "${CRYPTR_PASSWORD}" ]]; then
    echo "[notice] using environment variable CRYPTR_PASSWORD for the password"
    openssl $OPENSSL_CIPHER_TYPE -salt -pbkdf2 -in "$_file" -out "${_file}.aes" -pass env:CRYPTR_PASSWORD
  else
    openssl $OPENSSL_CIPHER_TYPE -salt -pbkdf2 -in "$_file" -out "${_file}.aes"
  fi

  if [[ $? -eq 0 ]]; then
    read -rp "do you want to delete the original file? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "[notice] deleting the original file"
      rm -f "$_file"
    fi
  else
    echo "[error] encryption failed, original file not deleted" 1>&2
    exit 6
  fi
}

cryptr_decrypt() {
  local _file="$1"
  local _stdout="$2"

  if [[ ! -f "$_file" ]]; then
    echo "File not found" 1>&2
    exit 5
  fi

  local _out_args=()
  if [[ "$_stdout" != "--stdout" ]]; then
    _out_args=(-out "${_file%\.aes}")
  fi

  if [[ -n "${CRYPTR_PASSWORD}" ]]; then
    echo "[notice] using environment variable CRYPTR_PASSWORD for the password"
    openssl $OPENSSL_CIPHER_TYPE -d -salt -pbkdf2 -in "$_file" "${_out_args[@]}" -pass env:CRYPTR_PASSWORD
  else
    openssl $OPENSSL_CIPHER_TYPE -d -salt -pbkdf2 -in "$_file" "${_out_args[@]}"
  fi
}

cryptr_main() {
  local _command="$1"

  if [[ -z $_command ]]; then
    cryptr_version
    echo
    cryptr_help
    exit 0
  fi

  shift 1
  case "$_command" in
    "encrypt")
      cryptr_encrypt "$@"
      ;;

    "decrypt")
      cryptr_decrypt "$@"
      ;;

    "version")
      cryptr_version
      ;;

    "help")
      cryptr_help
      ;;

    *)
      cryptr_help 1>&2
      exit 3
  esac
}

if [[ "$0" == "$BASH_SOURCE" ]]; then
  cryptr_main "$@"
fi
