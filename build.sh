#!/usr/bin/env bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x
set -e
set -u


echo "$(uname)"

case "$(uname)" in
"Linux")
  GITHUB_RELEASE_TOOL_ARCH="linux_amd64"
  NINJA_OS="linux"
  ;;

"Darwin")
  GITHUB_RELEASE_TOOL_ARCH="darwin_amd64"
  NINJA_OS="mac"
  ;;

"MINGW"*)
  GITHUB_RELEASE_TOOL_ARCH="windows_amd64"
  NINJA_OS="win"
  ;;

*)
  echo "Unknown OS"
  exit 1
  ;;
esac

export PATH="${HOME}/bin:$PATH"

mkdir "${HOME}/bin"

pushd "${HOME}/bin"

GITHUB_RELEASE_TOOL_USER="c4milo"
GITHUB_RELEASE_TOOL_VERSION="v1.1.0"
curl -fsSL -o github-release.tar.gz "https://github.com/${GITHUB_RELEASE_TOOL_USER}/github-release/releases/download/${GITHUB_RELEASE_TOOL_VERSION}/github-release_${GITHUB_RELEASE_TOOL_VERSION}_${GITHUB_RELEASE_TOOL_ARCH}.tar.gz"
tar xf github-release.tar.gz

curl -fsSL -o ninja-build.zip "https://github.com/ninja-build/ninja/releases/download/v1.9.0/ninja-${NINJA_OS}.zip"
unzip ninja-build.zip

ls

popd

ls

ninja || true
github-release || true


