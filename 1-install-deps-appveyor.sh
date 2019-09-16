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

GITHUB_RELEASE_TOOL_USER="c4milo"
GITHUB_RELEASE_TOOL_VERSION="v1.1.0"
GITHUB_RELEASE_TOOL_ARCH="windows_amd64"

mkdir temp
cd temp

curl -fsSL -o github-release.tar.gz "https://github.com/${GITHUB_RELEASE_TOOL_USER}/github-release/releases/download/${GITHUB_RELEASE_TOOL_VERSION}/github-release_${GITHUB_RELEASE_TOOL_VERSION}_${GITHUB_RELEASE_TOOL_ARCH}.tar.gz"

7z x github-release.tar.gz
7z x github-release.tar

curl -fsSL -o ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-win.zip
7z x ninja-win.zip

cd ..

git clone https://github.com/KhronosGroup/SPIRV-Tools.git "${CLONE_DIR}"
cd "${CLONE_DIR}"
git checkout $(cat ../COMMIT_ID)

git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers
pushd external/spirv-headers
git checkout $(cat ../../../COMMIT_ID_HEADERS)
popd

git clone https://github.com/protocolbuffers/protobuf external/protobuf
pushd external/protobuf
git checkout v3.7.1
popd
