#!/usr/bin/env bash
#
# Creates mycroft user and adds it to the necessary groups.
#

set -euo pipefail

home_dir=/home/mycroft
mycroft_config_dir="${home_dir}/.config/mycroft"

adduser --disabled-password --gecos "" --uid 1050 mycroft
c_rehash

groupadd -f --system gpio
groupadd -f --system i2c
groupadd -f --system spi
groupadd -f --system kmem
groupadd -f --system render
groupadd -f --system tty

usermod -a -G gpio mycroft
usermod -a -G i2c mycroft
usermod -a -G spi mycroft
usermod -a -G audio mycroft
usermod -a -G video mycroft
usermod -a -G kmem mycroft
usermod -a -G render mycroft
usermod -a -G tty mycroft
usermod -a -G input mycroft
usermod -a -G plugdev mycroft
usermod -a -G games mycroft
usermod -a -G users mycroft
usermod -a -G adm mycroft

# Add Mycroft config directory - ensuring it already exists on first boot
mkdir -p $mycroft_config_dir
chmod 700 $mycroft_config_dir

# Update .bashrc
{
    echo "source /opt/mycroft-dinkum/.venv/bin/activate"
    echo "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/opt/vc/lib/"
} >> "${home_dir}/.bashrc"

