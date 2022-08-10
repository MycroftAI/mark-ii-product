#!/usr/bin/env bash
#
# Install Mimic 3 TTS plugin.
# Voices are in /etc/mycroft/mimic3/voices/
#

set -euo pipefail

/home/mycroft/.config/mycroft/.venv/bin/pip3 install /etc/mycroft/mimic3/mimic3-*.tar.gz
