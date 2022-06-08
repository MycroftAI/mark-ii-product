#!/usr/bin/bash
set -ex

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

venv_dir="${this_dir}/venv"

if [ ! -d "${venv_dir}" ]; then
    echo "Missing virtual environment in ${venv_dir}";
    echo 'Did you run install-xmos.sh?';
    exit 1;
fi

# Load kernel module for I2S.
# Keep going if already loaded.
"${this_dir}/vocalfusion-rpi-setup/resources/load_i2s_driver.sh" || true

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
"${venv_dir}/bin/python3" "${this_dir}/send_image_from_rpi.py" --direct "${this_dir}/app_xvf3510_int_spi_boot_v4_1_0.bin"

# Set up Ti Amp (speakers)
"${venv_dir}/bin/python3" "${this_dir}/tas5806Test.py"

# Stop LEDs and set fan to 50%
mark2-leds 0 0 0
mark2-fan 50
