#!/usr/bin/env bash
set -euo pipefail

cd /opt/build/userland
sed -i 's/sudo //' buildme
./buildme --aarch64
