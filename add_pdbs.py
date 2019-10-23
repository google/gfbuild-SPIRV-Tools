# -*- coding: utf-8 -*-

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

import shutil
import sys
from pathlib import Path
from typing import Dict


def log(s):
    print(s, file=sys.stderr, flush=True)


def copy(source, dest):
    log("Copying " + source + " to " + dest)
    shutil.copy(source, dest)


def main():
    # add_pdbs.py build_dir install_dir

    build_dir = Path(sys.argv[1])
    install_dir = Path(sys.argv[2])

    binaries = []
    binaries.extend(install_dir.rglob("*.exe"))
    binaries.extend(install_dir.rglob("*.dll"))

    # E.g. hello -> bin/hello.exe
    binaries_map = {b.with_suffix("").name: b for b in binaries}  # type: Dict[str, Path]

    assert len(binaries) == len(binaries_map), "Duplicate binaries: " + str(binaries_map)

    pdbs = [p for p in build_dir.rglob("*.pdb") if p.with_suffix("").name in binaries_map]

    pdbs_set = {p.with_suffix("").name for p in pdbs}

    if len(pdbs) != len(pdbs_set):
        log("Duplicate pdbs:")
        log(pdbs)
        sys.exit(1)

    for pdb in pdbs:
        name = pdb.with_suffix("").name
        if name in binaries_map:
            binary_path = binaries_map[name]
            copy(str(pdb), str(binary_path.with_name(pdb.name)))


if __name__ == '__main__':
    main()
