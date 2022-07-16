#!/usr/bin/env bash
#
# Creates mycroft user and adds it to the necessary groups.
#

set -euo pipefail

home_dir=/home/mycroft
mycroft_dir=/opt/mycroft

adduser --disabled-password --gecos "" --uid 1050 mycroft
c_rehash

groupadd -f --system gpio
groupadd -f --system i2c
groupadd -f --system kmem

usermod -a -G gpio mycroft
usermod -a -G i2c mycroft
usermod -a -G video mycroft
usermod -a -G kmem mycroft

# Add Mycroft config directory - ensuring it already exists on first boot
mkdir -p "${home_dir}/.config/mycroft/"
chmod 700 "${home_dir}/.config/mycroft/"

# Update .bashrc
{
    echo "export PATH=\${PATH}:${mycroft_dir}/bin"
    echo "source ${mycroft_dir}/.venv/bin/activate"
    echo "export PYTHONPATH=${mycroft_dir}:\${PYTHONPATH}"
    echo "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/opt/vc/lib/"
} >> "${home_dir}/.bashrc"
