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

ARG BASE_IMAGE=arm64v8/ubuntu:20.04

# -----------------------------------------------------------------------------
# Mycroft GUI
# -----------------------------------------------------------------------------

FROM $BASE_IMAGE as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN apt-get update && apt-get install -y locales  \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /opt/build

COPY docker/packages-build.txt docker/packages-venv.txt ./

RUN apt-get update && \
    cat packages-build.txt packages-*.txt | xargs apt-get install --yes --no-install-recommends

RUN apt-get update && \
    cat packages-venv.txt | xargs apt-get install --yes --no-install-recommends

WORKDIR /build

# Generate container build timestamp
# COPY docker/build/mycroft/store-build-date.sh ./
# RUN ./store-build-date.sh

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
COPY mycroft-dinkum/services/hal/requirements/ ./services/hal/requirements/
COPY mycroft-dinkum/services/intent/requirements/ ./services/intent/requirements/
COPY mycroft-dinkum/services/messagebus/requirements/ ./services/messagebus/requirements/
COPY mycroft-dinkum/services/voice/requirements/ ./services/voice/requirements/

# Skill requirements
COPY mycroft-dinkum/skills/alarm.mark2/requirements.txt ./skills/alarm.mark2/
# COPY mycroft-dinkum/skills/date.mark2/requirements.txt ./skills/date.mark2/
# COPY mycroft-dinkum/skills/fallback-query.mark2/requirements.txt ./skills/fallback-query.mark2/
# COPY mycroft-dinkum/skills/fallback-unknown.mark2/requirements.txt ./skills/fallback-unknown.mark2/
COPY mycroft-dinkum/skills/homeassistant.mark2/requirements.txt ./skills/homeassistant.mark2/
COPY mycroft-dinkum/skills/homescreen.mark2/requirements.txt ./skills/homescreen.mark2/
COPY mycroft-dinkum/skills/ip.mark2/requirements.txt ./skills/ip.mark2/
COPY mycroft-dinkum/skills/news.mark2/requirements.txt ./skills/news.mark2/
# COPY mycroft-dinkum/skills/play.mark2/requirements.txt ./skills/play.mark2/
# COPY mycroft-dinkum/skills/play-music.mark2/requirements.txt ./skills/play-music.mark2/
COPY mycroft-dinkum/skills/query-duck-duck-go.mark2/requirements.txt ./skills/query-duck-duck-go.mark2/
COPY mycroft-dinkum/skills/query-wiki.mark2/requirements.txt ./skills/query-wiki.mark2/
COPY mycroft-dinkum/skills/query-wolfram-alpha.mark2/requirements.txt ./skills/query-wolfram-alpha.mark2/
# COPY mycroft-dinkum/skills/stop.mark2/requirements.txt ./skills/stop.mark2/
COPY mycroft-dinkum/skills/time.mark2/requirements.txt ./skills/time.mark2/
COPY mycroft-dinkum/skills/timer.mark2/requirements.txt ./skills/timer.mark2/
# COPY mycroft-dinkum/skills/volume.mark2/requirements.txt ./skills/volume.mark2/
COPY mycroft-dinkum/skills/weather.mark2/requirements.txt ./skills/weather.mark2/

# Create shared virtual environment with upgraded pip/setuptools
#
# NOTE: It's crucial that system site packages are available so the HAL service
# can access RPi.GPIO.
#
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    python3 -m venv --system-site-packages "${DINKUM_VENV}" && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade pip && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade wheel setuptools

# Install dinkum service/skill requirements
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    find ./ -name 'requirements.txt' -type f -print0 | \
    xargs -0 printf -- '-r %s ' | xargs "${DINKUM_VENV}/bin/pip3" install

# Install plugins
COPY mycroft-dinkum/plugins/ ./plugins/
COPY mimic3/ ./mimic3/
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install ./plugins/hotword_precise/ && \
    "${DINKUM_VENV}/bin/pip3" install ./mimic3 && \
    "${DINKUM_VENV}/bin/pip3" install mycroft-plugin-tts-mimic3

# Install shared dinkum library
COPY mycroft-dinkum/shared/setup.py \
     shared/

COPY mycroft-dinkum/shared/requirements/requirements.txt \
     shared/requirements/

COPY mycroft-dinkum/shared/mycroft/py.typed \
     mycroft-dinkum/shared/mycroft/__init__.py \
     shared/mycroft/

RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install -e ./shared/

# Create dinkum.target and services
COPY mycroft-dinkum/scripts/generate-systemd-units.py ./scripts/
RUN scripts/generate-systemd-units.py \
        --user mycroft \
        --service 0 services/messagebus \
        --service 1 services/hal \
        --service 1 services/audio \
        --service 1 services/gui \
        --service 1 services/intent \
        --service 1 services/voice \
        --service 2 services/skills \
        --service 3 services/enclosure \
        --skill skills/alarm.mark2 \
        --skill skills/date.mark2 \
        --skill skills/fallback-query.mark2 \
        --skill skills/fallback-unknown.mark2 \
        --skill skills/homeassistant.mark2 \
        --skill skills/homescreen.mark2 \
        --skill skills/ip.mark2 \
        --skill skills/news.mark2 \
        --skill skills/play.mark2 \
        --skill skills/play-music.mark2 \
        --skill skills/query-duck-duck-go.mark2 \
        --skill skills/query-wiki.mark2 \
        --skill skills/query-wolfram-alpha.mark2 \
        --skill skills/settings.mark2 \
        --skill skills/stop.mark2 \
        --skill skills/time.mark2 \
        --skill skills/timer.mark2 \
        --skill skills/volume.mark2 \
        --skill skills/weather.mark2

# -----------------------------------------------------------------------------
# Mycroft Container
# -----------------------------------------------------------------------------

FROM $BASE_IMAGE as run
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Add Mycroft alternatives
RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    apt-get update && \
    apt-get --yes --no-install-recommends install \
    software-properties-common gpg-agent locales

# Set the locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install external repo for plasma-nano package
COPY docker/build/mycroft/mycroft-alternatives.gpg.key ./
RUN apt-key add ./mycroft-alternatives.gpg.key
COPY docker/build/mycroft/mycroft-alt.list /etc/apt/sources.list.d/

WORKDIR /opt/build

COPY docker/packages-run.txt docker/packages-dev.txt ./
RUN apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

# Copy pre-built GUI files
# TODO check why we are copy etc here.
# COPY --from=build /etc/mycroft/ /etc/mycroft/
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
COPY docker/files/opt/ /opt/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.asoundrc /home/mycroft/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/.local/ /home/mycroft/.local/

# Install the Noto Sans font family
ADD docker/build/mycroft/Font_NotoSans-hinted.tar.gz /usr/share/fonts/truetype/noto-sans/
COPY docker/build/mycroft/install-fonts.sh ./
RUN ./install-fonts.sh

# Enable/disable services at boot.
RUN systemctl disable NetworkManager && \
    systemctl disable udisks2 && \
    systemctl disable networking && \
    systemctl disable apt-daily-upgrade && \
    systemctl disable snapd.service && \
    systemctl disable snapd.socket && \
    systemctl disable kmod-static-nodes

COPY --from=build /etc/systemd/system/dinkum* /etc/systemd/system/
RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-plasma.service && \
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
# The .config directory is not getting the right owner for some reason - force it.
RUN chown mycroft:mycroft /home/mycroft/.config

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
# TODO - This should be available to the XMOS service but it is failing to find the module.
#        Have installed it in the XMOS venv as well.
RUN apt-get update && apt-get install -y python3-rpi.gpio

# TODO: remove lib/modules and lib/firmware

# Clean up
RUN apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/

WORKDIR /home/mycroft
RUN rm -rf /opt/build

ENTRYPOINT [ "/lib/systemd/systemd" ]
