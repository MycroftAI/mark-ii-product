#!/bin/sh

pathtoname() {
    udevadm info -p /sys/"$1" | awk -v FS== '/DEVNAME/ {print $2}'
}

stdbuf -oL -- udevadm monitor --udev -s block | while read -r -- _ _ event devpath _; do
        if [ "$event" = add ]; then
            devname=$(pathtoname "$devpath")
            udisksctl mount --block-device "$devname" --no-user-interaction

            # HACK
            # mpd complains of permission problems regarding /media.
            # Running as the "mycroft" user does not help, nor does altering the
            # umask/dmask options during mount.
            #
            # Restarting the mpd service fixes the problem immediately for some
            # reason, so that's what we're doing here.
            systemctl restart mpd || true
        fi
done
