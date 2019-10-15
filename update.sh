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

GH_USER="google"
GH_REPO="gfbuild-SPIRV-Tools"

CLONE_DIR="SPIRV-Tools"

EXPECTED_NUM_ASSETS="15"

COMMIT_ID="$(cat "${WORK}/COMMIT_ID")"

ARTIFACT="${GH_REPO}"
ARTIFACT_VERSION="${COMMIT_ID}"
GROUP_SLASHES="github/${GH_USER}"
TAG="${GROUP_SLASHES}/${ARTIFACT}/${ARTIFACT_VERSION}"

NUM_ASSETS=$(curl -fsSL "https://api.github.com/repos/${GH_USER}/${GH_REPO}/releases/tags/${TAG}" | grep -c '"uploader": {')

if test "${NUM_ASSETS}" != "${EXPECTED_NUM_ASSETS}"; then
  echo "Stopping because of previous release: expected ${EXPECTED_NUM_ASSETS} but there were ${NUM_ASSETS}."
  exit 1
fi

export GITHUB_TOKEN="${GH_TOKEN}"

# Set git user and credentials.
git config --global user.name "GraphicsFuzz GitHub Bot"
git config --global user.email "graphicsfuzz-github-bot@google.com"
git config --global credential.helper store

echo "https://graphicsfuzz-github-bot:${GITHUB_TOKEN}@github.com" >~/.git-credentials

cd "${HOME}"

# Get new commit id.
git clone https://github.com/KhronosGroup/SPIRV-Tools.git "${CLONE_DIR}"
pushd "${CLONE_DIR}"
NEW_COMMIT_ID="$(git rev-parse HEAD)"
popd

if test "${COMMIT_ID}" = "${NEW_COMMIT_ID}"; then
  echo "Stopping because our COMMIT_ID is equal to the latest commit hash."
  exit 0
fi

git branch -f update
git checkout update
echo "${NEW_COMMIT_ID}">COMMIT_ID
git add COMMIT_ID
git commit -m "Updated COMMIT_ID to ${NEW_COMMIT_ID}"
git push --force --set-upstream origin update

# Wait for the CLA check to complete.
sleep 20


