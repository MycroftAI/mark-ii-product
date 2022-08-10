#!/usr/bin/env bash
#
# Install Precise Lite plugin.
# Model is included in plugin distribution.
#

set -euo pipefail

/home/mycroft/.config/mycroft/.venv/bin/pip3 install /etc/mycroft/precise-lite/hotword_precise_lite-*.tar.gz
