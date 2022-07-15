#!/usr/bin/env bash

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

# Base repo for https://github.com/xmos/vocalfusion-rpi-setup
base_dir="$(realpath "${this_dir}/..")"

# Load pre-compiled kernel module (kernel 5.15)
sleep 1
sudo insmod "${base_dir}/loader/i2s_master/i2s_master_loader.ko"

# Run Alsa at startup so that alsamixer configures
arecord -d 1 > /dev/null 2>&1
aplay dummy > /dev/null 2>&1
