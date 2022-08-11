#!/usr/bin/bash
set -ex

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

# -----------------------------------------------------------------------------

echo 'Installing required packages'
sudo apt-get update
sudo apt-get install --yes python3 python3-venv python3-dev rsync i2c-tools

echo 'Copying system files'
sudo rsync -av "${this_dir}/files/" /

# Build kernel module for XMOS microphone chip
echo 'Building kernel module for microphone'
cd /opt/mycroft/xmos-microphone/vocalfusion/vocalfusion-rpi-setup-5.2.0
./setup.sh xvf3510-int

# Create virtual environment for XMOS firmware programming
echo 'Setting up microphone service'
cd /opt/mycroft/xmos-microphone
sudo ./install.sh
sudo systemctl enable mycroft-xmos.service

echo 'Setting up DBus service'
cd /opt/mycroft/dbus-hal
sudo ./install.sh
sudo systemctl enable mycroft-hal.service

# Small script to turn off LEDS on boot, etc.
sudo systemctl enable mycroft-boot.service

# -----------------------------------------------------------------------------

echo 'Installation complete.'
echo 'Please reboot your Raspberry Pi'
