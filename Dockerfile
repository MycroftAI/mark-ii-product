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

ARG BASE_IMAGE=mycroftai/pi-os-lite-base:2022-04-04

# Base image with locale set
FROM $BASE_IMAGE as base-with-locale
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache

# -----------------------------------------------------------------------------

# Base image for building tools and virtual environments
FROM base-with-locale as base-build

WORKDIR /build

COPY docker/packages-build.txt ./
RUN --mount=type=cache,id=apt-base-build,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

# Image where Mycroft GUI is built
FROM base-build as build-gui

COPY mycroft-dinkum/services/gui/mycroft-gui/ ./mycroft-gui/
COPY docker/build/gui/build-mycroft-gui.sh ./
RUN ./build-mycroft-gui.sh

COPY mycroft-dinkum/services/gui/lottie-qml/ ./lottie-qml/
COPY docker/build/gui/build-lottie-qml.sh ./
RUN ./build-lottie-qml.sh

COPY mycroft-dinkum/services/gui/mycroft-gui-mark-2/ ./mycroft-gui-mark-2/
COPY docker/build/gui/build-mycroft-gui-mark-2.sh ./
RUN ./build-mycroft-gui-mark-2.sh

# -----------------------------------------------------------------------------

# Image where XMOS/HAL services are built
FROM base-build as build-hal

WORKDIR /opt/mycroft

# XMOS (microhone)
COPY mark-ii-raspberrypi/files/opt/mycroft/xmos-microphone/requirements.txt \
     mark-ii-raspberrypi/files/opt/mycroft/xmos-microphone/install.sh \
     ./xmos-microphone/
RUN --mount=type=cache,id=pip-build-hal,target=/root/.cache/pip \
    cd ./xmos-microphone && \
    ./install.sh

# DBus server (LEDs, fan, buttons, volume)
COPY mark-ii-raspberrypi/files/opt/mycroft/dbus-hal/requirements.txt \
     mark-ii-raspberrypi/files/opt/mycroft/dbus-hal/install.sh \
     ./dbus-hal/
RUN --mount=type=cache,id=pip-build-hal,target=/root/.cache/pip \
    cd ./dbus-hal && \
    ./install.sh

# -----------------------------------------------------------------------------

FROM base-build as build-dinkum

# Create dinkum (shared) virtual environment
WORKDIR /opt/mycroft-dinkum

ENV DINKUM_VENV=/opt/mycroft-dinkum/.venv

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
# COPY mycroft-dinkum/skills/play-radio.mark2/requirements.txt ./skills/play-radio.mark2/
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
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    python3 -m venv --upgrade-deps --system-site-packages "${DINKUM_VENV}" && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade wheel

# Install dinkum service/skill requirements
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    find ./ -name 'requirements.txt' -type f -print0 | \
    xargs -0 printf -- '-r %s ' | xargs "${DINKUM_VENV}/bin/pip3" install

# Install plugins
COPY mycroft-dinkum/plugins/ ./plugins/
COPY mimic3/ ./mimic3/
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
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
        --user pi \
        --venv-dir "${DINKUM_VENV}" \
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
        --skill skills/play-radio.mark2 \
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
# Run
# -----------------------------------------------------------------------------

FROM base-with-locale as run

COPY docker/packages-run.txt docker/packages-dev.txt ./

RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends && \
    apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/

# Enable I2C
RUN raspi-config nonint do_i2c 0 && \
    raspi-config nonint do_spi 0

# Install the Noto Sans font family
ADD docker/build/mycroft/NotoSans-hinted.tar.gz /usr/share/fonts/truetype/noto-sans/
COPY docker/build/mycroft/install-fonts.sh ./
RUN ./install-fonts.sh

# Copy pre-built GUI files
COPY --from=build-gui /usr/local/ /usr/
COPY --from=build-gui /usr/lib/aarch64-linux-gnu/qt5/qml/ /usr/lib/aarch64-linux-gnu/qt5/qml/

# Copy HAL tools
COPY --from=build-hal --chown=pi:pi /opt/mycroft/ /opt/mycroft/

# Copy dinkum code and virtual environment
COPY --from=build-dinkum --chown=pi:pi /opt/mycroft-dinkum/ /opt/mycroft-dinkum/
COPY --chown=pi:pi mycroft-dinkum/ /opt/mycroft-dinkum/
RUN rm -f /opt/mycroft-dinkum/.git
COPY --chown=pi:pi .git/modules/mycroft-dinkum/ /opt/mycroft-dinkum/.git/
RUN sed -i 's|worktree\s+=.*|worktree = ../|' /opt/mycroft-dinkum/.git/config

# Copy system files
COPY docker/files/etc/ /etc/
COPY docker/files/opt/ /opt/
COPY docker/files/usr/ /usr/
COPY mark-ii-raspberrypi/files/etc/ /etc/
COPY mark-ii-raspberrypi/files/opt/ /opt/
COPY mark-ii-raspberrypi/files/usr/ /usr/
COPY mark-ii-raspberrypi/pre-built/ /

# Enable/disable services at boot.
COPY --from=build-dinkum /etc/systemd/system/dinkum* /etc/systemd/system/
RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-plasma.service && \
    systemctl enable /etc/systemd/system/mycroft-hal.service && \
    systemctl enable /etc/systemd/system/mycroft-boot.service && \
    systemctl enable /etc/systemd/system/mycroft-automount.service && \
    systemctl enable /etc/systemd/system/dinkum.target && \
    systemctl set-default graphical

# Copy user files
COPY --chown=mycroft:mycroft mark-ii-raspberrypi/files/home/pi/ /home/mycroft/
COPY --chown=pi:pi docker/files/home/pi/ /home/pi/

# Clean up
RUN rm -f /etc/apt/apt.conf.d/01cache
