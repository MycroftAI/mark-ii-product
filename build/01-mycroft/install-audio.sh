#!/usr/bin/env bash
set -euo pipefail

mv /usr/share/alsa/pulse-alsa.conf /usr/share/alsa/pulse-alsa.conf.old

chown mycroft:mycroft /home/mycroft/.asoundrc

# apt-get --yes remove portaudio19-dev
# apt-get --yes autoremove
# apt-get clean

apt install --reinstall --yes ./portaudio_patch.deb
