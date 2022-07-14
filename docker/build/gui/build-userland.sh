#!/usr/bin/env bash
set -euo pipefail

cd userland
sed -i 's/sudo //' buildme
./buildme --aarch64
