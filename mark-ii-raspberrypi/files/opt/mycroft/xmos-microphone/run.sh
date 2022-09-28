#!/usr/bin/env bash
set -ex

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

venv_dir="${this_dir}/.venv"
if [ ! -d "${venv_dir}" ]; then
    echo "Missing virtual environment in ${venv_dir}";
    echo 'Did you run install.sh?';
    exit 1;
fi

# Load kernel module for I2S.
# Keep going if already loaded.
# NOTE: Not loading on Pantacor device
# sh "${this_dir}/vocalfusion/vocalfusion-rpi-setup-5.2.0/resources/load_i2s_driver.sh" || true

# Force ALSA to configure
arecord -d 1 > /dev/null 2>&1

# Set clocks
sudo setup_mclk
sudo setup_bclk
sleep 1

# Put XMOS chip (microphone) in programming mode
gpio -g mode 16 out
gpio -g mode 27 out 
gpio -g write 16 1 
gpio -g write 27 1 
sleep 1

# Upload XMOS firmware directly
"${venv_dir}/bin/python3" "${this_dir}/send_image_from_rpi.py" --direct "${this_dir}/app_xvf3510_int_spi_boot_v4_2_0.bin"

# ---------------------------
# Set initial XMOS parameters
# ---------------------------

# Disable alternative architecture.
#
# This keeps AEC (acoustic echo cancellation) and the IC (interference
# cancellation) enabled at all times.
vfctrl_i2c --no-check-version SET_ALT_ARCH_ENABLED 0

# Lower the max gain to avoid the device hearing itself.
# This happens despite the AEC being enabled, unfortunately.
vfctrl_i2c --no-check-version SET_MAX_GAIN_CH0_AGC 150

# Start the auto delay estimator (ADEC) off closer to the actual values it will
# eventually settle of after calibration. The device automatically calibrates
# when it first plays audio, but these values are initially way off the mark.
vfctrl_i2c --no-check-version SET_DELAY_DIRECTION 1
vfctrl_i2c --no-check-version SET_DELAY_SAMPLES 120


# Set up Ti Amp (speakers)
"${venv_dir}/bin/python3" "${this_dir}/tas5806Test.py"
