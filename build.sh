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

WORK="$(pwd)"

uname

case "$(uname)" in
"Linux")
  GITHUB_RELEASE_TOOL_ARCH="linux_amd64"
  NINJA_OS="linux"
  PYTHON="python3"
  ;;

"Darwin")
  GITHUB_RELEASE_TOOL_ARCH="darwin_amd64"
  NINJA_OS="mac"
  PYTHON="python3"
  ;;

"MINGW"*)
  GITHUB_RELEASE_TOOL_ARCH="windows_amd64"
  NINJA_OS="win"
  PYTHON="python"
  ;;

*)
  echo "Unknown OS"
  exit 1
  ;;
esac

export PATH="${HOME}/bin:$PATH"

mkdir "${HOME}/bin"

pushd "${HOME}/bin"

# Install github-release.
GITHUB_RELEASE_TOOL_USER="c4milo"
GITHUB_RELEASE_TOOL_VERSION="v1.1.0"
curl -fsSL -o github-release.tar.gz "https://github.com/${GITHUB_RELEASE_TOOL_USER}/github-release/releases/download/${GITHUB_RELEASE_TOOL_VERSION}/github-release_${GITHUB_RELEASE_TOOL_VERSION}_${GITHUB_RELEASE_TOOL_ARCH}.tar.gz"
tar xf github-release.tar.gz

# Install ninja.
curl -fsSL -o ninja-build.zip "https://github.com/ninja-build/ninja/releases/download/v1.9.0/ninja-${NINJA_OS}.zip"
unzip ninja-build.zip

ls

popd


COMMIT_ID="$(cat "${WORK}/COMMIT_ID")"
CLONE_DIR="SPIRV-Tools"

git clone https://github.com/KhronosGroup/SPIRV-Tools.git "${CLONE_DIR}"
cd "${CLONE_DIR}"
git checkout "${COMMIT_ID}"

# Get headers version from the DEPS file.
HEADERS_VERSION="$(${PYTHON} "${WORK}/get_headers_version.py" < DEPS)"

git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers
pushd external/spirv-headers
git checkout "${HEADERS_VERSION}"
popd

git clone https://github.com/protocolbuffers/protobuf external/protobuf
pushd external/protobuf
git checkout v3.7.1
popd

CMAKE_OPTIONS="-DSPIRV_BUILD_FUZZER=ON"
GITHUB_USER="google"
GITHUB_REPO="gfbuild-SPIRV-Tools"

CMAKE_GENERATOR="Ninja"
CMAKE_BUILD_TYPE="${CONFIG}"
BUILD_SHA="${GITHUB_SHA}"
GROUP_DOTS="github.${GITHUB_USER}"
GROUP_SLASHES="github/${GITHUB_USER}"
ARTIFACT="${GITHUB_REPO}"
VERSION="${BUILD_SHA}"
POM_FILE="${GITHUB_REPO}-${VERSION}.pom"
TAG="${GROUP_SLASHES}/${ARTIFACT}/${VERSION}"
CLASSIFIER="${BUILD_PLATFORM}_${CMAKE_BUILD_TYPE}"
INSTALL_DIR="${ARTIFACT}-${VERSION}-${CLASSIFIER}"


BUILD_DIR="${INSTALL_DIR}-build"

mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}"
cmake -G "${CMAKE_GENERATOR}" .. "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" -DCMAKE_OSX_ARCHITECTURES=x86_64 ${CMAKE_OPTIONS}
cmake --build . --config "${CMAKE_BUILD_TYPE}"
cmake "-DCMAKE_INSTALL_PREFIX=../${INSTALL_DIR}" "-DBUILD_TYPE=${CMAKE_BUILD_TYPE}" -P cmake_install.cmake
popd


for f in "${INSTALL_DIR}/bin/"*; do
  echo "${BUILD_SHA}">"${f}.build-version"
  cp ../COMMIT_ID "${f}.version"
done

# zip file.
pushd "${INSTALL_DIR}"
zip -r "../${INSTALL_DIR}.zip" ./*
popd

sha1sum "${INSTALL_DIR}.zip" >"${INSTALL_DIR}.zip.sha1"

# POM file.
sed -e "s/@GROUP@/${GROUP_DOTS}/g" -e "s/@ARTIFACT@/${ARTIFACT}/g" -e "s/@VERSION@/${VERSION}/g" "../fake_pom.xml" >"${POM_FILE}"

sha1sum "${POM_FILE}" >"${POM_FILE}.sha1"

DESCRIPTION="$(echo -e "Automated build for ${CLONE_DIR} version ${COMMIT_ID}.\n$(git log --graph -n 3 --abbrev-commit --pretty='format:%h - %s <%an>')")"

# Only release from master branch commits.
# shellcheck disable=SC2153
if test "${GITHUB_REF}" != "refs/heads/master"; then
  exit 0
fi

github-release \
  "${GITHUB_USER}/${GITHUB_REPO}" \
  "${TAG}" \
  "${COMMIT_ID}" \
  "${DESCRIPTION}" \
  "${INSTALL_DIR}.zip"

github-release \
  "${GITHUB_USER}/${GITHUB_REPO}" \
  "${TAG}" \
  "${COMMIT_ID}" \
  "${DESCRIPTION}" \
  "${INSTALL_DIR}.zip.sha1"

# Don't fail if pom cannot be uploaded, as it might already be there.

github-release \
  "${GITHUB_USER}/${GITHUB_REPO}" \
  "${TAG}" \
  "${COMMIT_ID}" \
  "${DESCRIPTION}" \
  "${POM_FILE}" || true

github-release \
  "${GITHUB_USER}/${GITHUB_REPO}" \
  "${TAG}" \
  "${COMMIT_ID}" \
  "${DESCRIPTION}" \
  "${POM_FILE}.sha1" || true
