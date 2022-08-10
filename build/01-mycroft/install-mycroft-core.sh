#!/usr/bin/env bash
#
# Installs mycroft core
#

set -euo pipefail

mycroft_dir='/opt/mycroft'
bin_dir="${mycroft_dir}/bin"

# Fix submodule
sed -i \
    's|worktree = ../../../mycroft-core|worktree = /opt/mycroft|' \
    "${mycroft_dir}/.git/config"

# Fix git refs
sed -i \
    's|fetch = +refs/heads/devs:refs/remotes/origin/devs|fetch = +refs/heads/*:refs/remotes/origin/*|' \
    "${mycroft_dir}/.git/config"

# A commit template message is not needed for the Mark II and
# can fail if the mycroft_core directory is not git initialized.
LINE_TO_DELETE="git config commit.template .gitmessage"
sed -i "/${LINE_TO_DELETE}/d" "${mycroft_dir}/dev_setup.sh"

"${bin_dir}/mycroft-pip" install \
    future spidev smbus2 RPi.GPIO

cd "${mycroft_dir}"
mkdir -p skills
CI=true ./dev_setup.sh --allow-root -sm

mkdir -p scripts/logs
for name in bus voice skills audio;
do
    touch "scripts/logs/mycroft-${name}.log"
done

# Ensure scripts are executable
find "${mycroft_dir}" -mindepth 1 -maxdepth 1 -name '*.sh' -type f \
    -exec chmod +x {} \;
