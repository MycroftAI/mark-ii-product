#!/usr/bin/env bash
set -euo pipefail

ln -s /etc/systemd/system/mycroft-xmos.service \
    /etc/systemd/system/multi-user.target.wants/

systemctl enable sddm
systemctl enable pvpoweroff
systemctl enable pvreboot
systemctl set-default graphical.target

# Remove unnecessary services
rm -f /etc/systemd/system/timers.target.wants/apt-daily-upgrade.timer
rm -f /etc/systemd/system/timers.target.wants/apt-daily.timer

systemctl disable systemd-networkd
systemctl disable network-manager
systemctl disable snapd
systemctl disable ModemManager
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable wpa_supplicant

# User MPD
rm -f /etc/systemd/system/multi-user.target.wants/mpd.*
su - mycroft -c "systemctl --user enable mpd"

# Disable automatic upgrades
if [ -f  /etc/apt/apt.conf.d/20auto-upgrades ];
then
    sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades
fi

echo -e '\n[keyfile]\nunmanaged-devices=interface-name:eth*;interface-name:wlan*;interface-name:lxcbr*' \
    >> /etc/NetworkManager/NetworkManager.conf

# Install Mycroft service
# mkdir -p /home/mycroft/.config/systemd/user/default.target.wants/
# chown -R mycroft:mycroft /home/mycroft/.config/
# ln -s /usr/lib/systemd/user/mycroft.service \
#     /home/mycroft/.config/systemd/user/default.target.wants/mycroft.service

systemctl enable /etc/systemd/system/dinkum.target
