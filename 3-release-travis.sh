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

cd "${CLONE_DIR}"

for f in "${INSTALL_DIR}/bin/"*; do
  echo "${COMMIT_ID}">"${f}.build-version"
  cp ../COMMIT_ID "${f}.version"
done

cd "${INSTALL_DIR}"
zip -r "../${INSTALL_DIR}.zip" *
cd ..

sha1sum "${INSTALL_DIR}.zip" >"${INSTALL_DIR}.zip.sha1"

sed -e "s/@GROUP@/${GROUP_DOTS}/g" -e "s/@ARTIFACT@/${ARTIFACT}/g" -e "s/@VERSION@/${VERSION}/g" "../fake_pom.xml" >"${POM_FILE}"
sha1sum "${POM_FILE}" >"${POM_FILE}.sha1"

DESCRIPTION="$(echo -e "Automated build.\n$(git log --graph -n 3 --abbrev-commit --pretty='format:%h - %s <%an>')")"

# Only release from master branch commits.
if [ "$TRAVIS_BRANCH" != "master" ]; then
  exit 0
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
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
