#!/usr/bin/env bash
#
# Miscellaneous final tasks before image is finished.
#

set -euo pipefail

echo "mycroft      -   nice      -20" >> /etc/security/limits.conf

chown -R root:root /etc/sudoers
chmod 0440 /etc/sudoers

chown -R root:root /etc/sudoers.d
chmod -R 0440 /etc/sudoers.d

# Slow, but necessary
chown -R mycroft:mycroft /opt/mycroft
chown -R mycroft:mycroft /home/mycroft

# Automatically log into the mycroft account
{
    echo 'source /opt/mycroft/.camerarc'
    echo 'su -l mycroft'
} >> /root/.bashrc
