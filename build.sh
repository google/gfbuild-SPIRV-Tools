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

# Old bash versions can't expand empty arrays, so we always include at least this option.
CMAKE_OPTIONS=("-DCMAKE_OSX_ARCHITECTURES=x86_64")

case "$(uname)" in
"Linux")
  GH_RELEASE_TOOL_ARCH="linux_amd64"
  NINJA_OS="linux"
  BUILD_PLATFORM="Linux_x64"
  PYTHON="python3"
  ;;

"Darwin")
  GH_RELEASE_TOOL_ARCH="darwin_amd64"
  NINJA_OS="mac"
  BUILD_PLATFORM="Mac_x64"
  PYTHON="python3"
  brew install md5sha1sum
  ;;

"MINGW"*)
  GH_RELEASE_TOOL_ARCH="windows_amd64"
  NINJA_OS="win"
  BUILD_PLATFORM="Windows_x64"
  PYTHON="python"
  CMAKE_OPTIONS+=("-DCMAKE_C_COMPILER=cl.exe" "-DCMAKE_CXX_COMPILER=cl.exe")
  choco install zip
  ;;

*)
  echo "Unknown OS"
  exit 1
  ;;
esac

export PATH="${HOME}/bin:$PATH"

mkdir -p "${HOME}/bin"

pushd "${HOME}/bin"

# Install github-release.
GH_RELEASE_TOOL_USER="c4milo"
GH_RELEASE_TOOL_VERSION="v1.1.0"
curl -fsSL -o github-release.tar.gz "https://github.com/${GH_RELEASE_TOOL_USER}/github-release/releases/download/${GH_RELEASE_TOOL_VERSION}/github-release_${GH_RELEASE_TOOL_VERSION}_${GH_RELEASE_TOOL_ARCH}.tar.gz"
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
HEADERS_VERSION="$(${PYTHON} "${WORK}/get_headers_version.py" <DEPS)"

git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers
pushd external/spirv-headers
git checkout "${HEADERS_VERSION}"
popd

git clone https://github.com/protocolbuffers/protobuf external/protobuf
pushd external/protobuf
git checkout v3.7.1
popd

CMAKE_OPTIONS+=("-DSPIRV_BUILD_FUZZER=ON")
GH_USER="google"
GH_REPO="gfbuild-SPIRV-Tools"

CMAKE_GENERATOR="Ninja"
CMAKE_BUILD_TYPE="${CONFIG}"
BUILD_REPO_SHA="${GITHUB_SHA}"
GROUP_DOTS="github.${GH_USER}"
GROUP_SLASHES="github/${GH_USER}"
ARTIFACT="${GH_REPO}"
ARTIFACT_VERSION="${COMMIT_ID}"
POM_FILE="${GH_REPO}-${ARTIFACT_VERSION}.pom"
TAG="${GROUP_SLASHES}/${ARTIFACT}/${ARTIFACT_VERSION}"
CLASSIFIER="${BUILD_PLATFORM}_${CMAKE_BUILD_TYPE}"
INSTALL_DIR="${ARTIFACT}-${ARTIFACT_VERSION}-${CLASSIFIER}"


BUILD_DIR="b_${CMAKE_BUILD_TYPE}"

mkdir -p "${BUILD_DIR}"
pushd "${BUILD_DIR}"

cmake -G "${CMAKE_GENERATOR}" .. "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" "${CMAKE_OPTIONS[@]}"
cmake --build . --config "${CMAKE_BUILD_TYPE}"
cmake "-DCMAKE_INSTALL_PREFIX=../${INSTALL_DIR}" "-DBUILD_TYPE=${CMAKE_BUILD_TYPE}" -P cmake_install.cmake
popd


for f in "${INSTALL_DIR}/bin/"*; do
  echo "${BUILD_REPO_SHA}">"${f}.build-version"
  cp ../COMMIT_ID "${f}.version"
done

# Add licenses file.
cp ../third_party/OPEN_SOURCE_LICENSES.TXT "${INSTALL_DIR}/"
cp ../third_party/OPEN_SOURCE_LICENSES.TXT ./

# zip file.
pushd "${INSTALL_DIR}"
zip -r "../${INSTALL_DIR}.zip" ./*
popd

sha1sum "${INSTALL_DIR}.zip" >"${INSTALL_DIR}.zip.sha1"

# POM file.
sed -e "s/@GROUP@/${GROUP_DOTS}/g" -e "s/@ARTIFACT@/${ARTIFACT}/g" -e "s/@VERSION@/${ARTIFACT_VERSION}/g" "../fake_pom.xml" >"${POM_FILE}"

sha1sum "${POM_FILE}" >"${POM_FILE}.sha1"

DESCRIPTION="$(echo -e "Automated build for ${CLONE_DIR} version ${COMMIT_ID}.\n$(git log --graph -n 3 --abbrev-commit --pretty='format:%h - %s <%an>')")"

# Only release from master branch commits.
# shellcheck disable=SC2153
if test "${GITHUB_REF}" != "refs/heads/master"; then
  exit 0
fi

# We do not use the GITHUB_TOKEN provided by GitHub Actions.
# We cannot set enviroment variables or secrets that start with GITHUB_ in .yml files,
# but the github-release tool requires GITHUB_TOKEN, so we set it here.
export GITHUB_TOKEN="${GH_TOKEN}"

github-release \
  "${GH_USER}/${GH_REPO}" \
  "${TAG}" \
  "${BUILD_REPO_SHA}" \
  "${DESCRIPTION}" \
  "${INSTALL_DIR}.zip"

github-release \
  "${GH_USER}/${GH_REPO}" \
  "${TAG}" \
  "${BUILD_REPO_SHA}" \
  "${DESCRIPTION}" \
  "${INSTALL_DIR}.zip.sha1"

# Don't fail if pom cannot be uploaded, as it might already be there.

github-release \
  "${GH_USER}/${GH_REPO}" \
  "${TAG}" \
  "${BUILD_REPO_SHA}" \
  "${DESCRIPTION}" \
  "${POM_FILE}" || true

github-release \
  "${GH_USER}/${GH_REPO}" \
  "${TAG}" \
  "${BUILD_REPO_SHA}" \
  "${DESCRIPTION}" \
  "${POM_FILE}.sha1" || true

# Don't fail if OPEN_SOURCE_LICENSES.TXT cannot be uploaded, as it might already be there.

github-release \
  "${GH_USER}/${GH_REPO}" \
  "${TAG}" \
  "${BUILD_REPO_SHA}" \
  "${DESCRIPTION}" \
  "OPEN_SOURCE_LICENSES.TXT" || true
