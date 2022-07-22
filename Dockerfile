# Copyright 2022 Mycroft AI Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -----------------------------------------------------------------------------
#
# Docker build script for Mark II
#
# Requires buildkit: https://docs.docker.com/develop/develop-images/build_enhancements/
# -----------------------------------------------------------------------------

ARG BASE_IMAGE=arm64v8/ubuntu:22.04

# -----------------------------------------------------------------------------
# Mycroft GUI
# -----------------------------------------------------------------------------

FROM $BASE_IMAGE as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /opt/build

COPY docker/packages-build.txt docker/packages-venv.txt ./

# Only Python 3.10 is available on Ubuntu 22.04
# Get 3.9 from the friendly dead snakes
RUN apt-get update && \
    apt install software-properties-common gpg-agent --yes --no-install-recommends
RUN add-apt-repository ppa:deadsnakes/ppa

RUN apt-get update && \
    cat packages-build.txt | xargs apt-get install --yes --no-install-recommends

RUN apt-get update && \
    cat packages-venv.txt | xargs apt-get install --yes --no-install-recommends

# Set the default Python interpreter
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1 && \
    update-alternatives --set python /usr/bin/python3.9
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    update-alternatives --set python3 /usr/bin/python3.9

WORKDIR /build

# Generate container build timestamp
COPY docker/build/mycroft/store-build-date.sh ./
RUN ./store-build-date.sh

COPY docker/build/gui/mycroft-gui/ ./mycroft-gui/
COPY docker/build/gui/build-mycroft-gui.sh ./
RUN ./build-mycroft-gui.sh

COPY docker/build/gui/lottie-qml/ ./lottie-qml/
COPY docker/build/gui/build-lottie-qml.sh ./
RUN ./build-lottie-qml.sh

COPY docker/build/gui/mycroft-gui-mark-2/ ./mycroft-gui-mark-2/
COPY docker/build/gui/build-mycroft-gui-mark-2.sh ./
RUN ./build-mycroft-gui-mark-2.sh

ADD docker/build/gui/userland ./userland
COPY docker/build/gui/build-userland.sh ./
RUN ./build-userland.sh

# Set up XMOS startup sequence
COPY docker/files/home/mycroft/.local/ /home/mycroft/.local/
RUN cd /home/mycroft/.local/share/mycroft/xmos-setup && \
    ./install-xmos.sh

# Create dinkum (shared) virtual environment
WORKDIR /opt/mycroft-dinkum

ENV DINKUM_VENV=/home/mycroft/.config/mycroft/.venv

# Just copy requirements and scripts so we don't have to rebuild this every time
# a code file changes.
COPY mycroft-dinkum/services/audio/requirements/ ./services/audio/requirements/
COPY mycroft-dinkum/services/enclosure/requirements/ ./services/enclosure/requirements/
COPY mycroft-dinkum/services/gui/requirements/ ./services/gui/requirements/
COPY mycroft-dinkum/services/intent/requirements/ ./services/intent/requirements/
COPY mycroft-dinkum/services/messagebus/requirements/ ./services/messagebus/requirements/
COPY mycroft-dinkum/services/voice/requirements/ ./services/voice/requirements/

# COPY mycroft-dinkum/skills/date.mycroftai/requirements.txt ./skills/date.mycroftai/
COPY mycroft-dinkum/skills/homescreen.mycroftai/requirements.txt ./skills/homescreen.mycroftai/
COPY mycroft-dinkum/skills/time.mycroftai/requirements.txt ./skills/time.mycroftai/

# Install dinkum services/skills
RUN python3 -m venv --upgrade-deps "${DINKUM_VENV}" && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade wheel

RUN find ./ -name 'requirements.txt' -type f -print0 | \
    xargs -0 printf -- '-r %s ' | xargs "${DINKUM_VENV}/bin/pip3" install

# Install plugins
COPY mycroft-dinkum/plugins/ ./plugins/
RUN "${DINKUM_VENV}/bin/pip3" install ./plugins/hotword_precise/ && \
    "${DINKUM_VENV}/bin/pip3" install ./plugins/stt_vosk && \
    "${DINKUM_VENV}/bin/pip3" install mycroft-plugin-tts-mimic3

# Install shared dinkum library
COPY mycroft-dinkum/shared/setup.py \
     shared/

COPY mycroft-dinkum/shared/requirements/requirements.txt \
     shared/requirements/

COPY mycroft-dinkum/shared/mycroft/py.typed \
     mycroft-dinkum/shared/mycroft/__init__.py \
     shared/mycroft/

RUN "${DINKUM_VENV}/bin/pip3" install -e ./shared/

COPY mycroft-dinkum/scripts/generate-systemd-units.py ./scripts/

# Create dinkum.target and services
RUN scripts/generate-systemd-units.py \
        --user mycroft \
        --service 0 services/messagebus \
        --service 1 services/audio \
        --service 1 services/gui \
        --service 1 services/intent \
        --service 1 services/voice \
        --service 2 services/skills \
        --service 3 services/enclosure \
        --skill skills/homescreen.mycroftai \
        --skill skills/date.mycroftai \
        --skill skills/time.mycroftai

# -----------------------------------------------------------------------------
# Mycroft Container
# -----------------------------------------------------------------------------

FROM $BASE_IMAGE as run
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /opt/build

# Only Python 3.10 is available on Ubuntu 22.04
# Get 3.9 from the friendly dead snakes
RUN apt-get update && \
    apt install software-properties-common gpg-agent --yes --no-install-recommends
RUN add-apt-repository ppa:deadsnakes/ppa

COPY docker/packages-run.txt docker/packages-dev.txt ./

RUN apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

# Set the default Python interpreter and remove 3.10 packages
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1 && \
    update-alternatives --set python /usr/bin/python3.9
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    update-alternatives --set python3 /usr/bin/python3.9
# TODO: Removing the default python packages removes a lot of system dependencies
#       that we actually need. Need to find a safe way to do this.
# RUN apt remove python3.10* libpython3.10* idle-python3.10 --no-install-recommends

# Copy pre-built GUI files
# TODO check why we are copy etc here.
COPY --from=build /etc/mycroft/ /etc/mycroft/
COPY --from=build /usr/local/ /usr/
COPY --from=build /usr/lib/aarch64-linux-gnu/qt5/qml/ /usr/lib/aarch64-linux-gnu/qt5/qml/

# Create mycroft user (#1050)
COPY docker/build/mycroft/create-mycroft-user.sh ./
RUN ./create-mycroft-user.sh

# Copy system files
COPY docker/files/usr/ /usr/
COPY docker/files/etc/ /etc/
COPY docker/files/var/ /var/
COPY docker/files/lib/ /lib/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.asoundrc /home/mycroft/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.local/ /home/mycroft/.local/

# Install the Noto Sans font family
ADD docker/build/mycroft/Font_NotoSans-hinted.tar.gz /usr/share/fonts/truetype/noto-sans/
COPY docker/build/mycroft/install-fonts.sh ./
RUN ./install-fonts.sh

# Enable/disable services at boot.
RUN systemctl disable network-manager && \
    systemctl disable udisks && \
    systemctl disable networking && \
    systemctl disable apt-daily-upgrade && \
    systemctl disable snapd.service && \
    systemctl disable snapd.socket && \
    systemctl disable kmod-static-nodes

COPY --from=build /etc/systemd/system/dinkum* /etc/systemd/system/
RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-plasma.service && \
    systemctl enable /etc/systemd/system/mycroft-switch.service && \
    systemctl enable /etc/systemd/system/mycroft-volume.service && \
    systemctl enable /etc/systemd/system/mycroft-leds.service && \
    systemctl enable /etc/systemd/system/dinkum.target && \
    systemctl set-default graphical

RUN mkdir -p /var/log/mycroft && \
    chown -R mycroft:mycroft /var/log/mycroft

# Copy dinkum code and virtual environment
COPY --from=build --chown=mycroft:mycroft /home/mycroft/.config/mycroft/.venv /home/mycroft/.config/mycroft/.venv
COPY --from=build --chown=mycroft:mycroft /home/mycroft/.local/share/mycroft/xmos-setup/venv /home/mycroft/.local/share/mycroft/xmos-setup/venv
COPY mycroft-dinkum/ /opt/mycroft-dinkum/

# Copy user files
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.bash_profile /home/mycroft/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.local/share/ /home/mycroft/.local/share/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.config/ /home/mycroft/.config/

# Install pantacor tools
COPY --chown=0:0 --from=registry.gitlab.com/pantacor/pantavisor-runtime/pvtoolbox:arm32v7-master /usr/local/bin/pvsocket /usr/local/bin/pvsocket
COPY --chown=0:0 --from=registry.gitlab.com/pantacor/pantavisor-runtime/pvtoolbox:arm32v7-master /usr/local/bin/pvlog /usr/local/bin/pvlog
COPY --chown=0:0 --from=registry.gitlab.com/pantacor/pantavisor-runtime/pvtoolbox:arm32v7-master /usr/local/bin/pvmeta /usr/local/bin/pvmeta
COPY --chown=0:0 --from=registry.gitlab.com/pantacor/pantavisor-runtime/pvtoolbox:arm32v7-master /usr/local/bin/pvreboot /usr/local/bin/pvreboot
COPY --chown=0:0 --from=registry.gitlab.com/pantacor/pantavisor-runtime/pvtoolbox:arm32v7-master /usr/local/bin/pvpoweroff /usr/local/bin/pvpoweroff

COPY docker/build/pantacor/install-pantacor-tools.sh ./
# TODO enable poweroff and reboot units
RUN ./install-pantacor-tools.sh && rm install-pantacor-tools.sh

# Install rpi.gpio last to avoid issues with switch server
RUN apt-get update && apt-get install -y python3-rpi.gpio

# TODO: remove lib/modules and lib/firmware

# Clean up
RUN apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/

WORKDIR /home/mycroft
RUN rm -rf /opt/build

ENTRYPOINT [ "/lib/systemd/systemd" ]

