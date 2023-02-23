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
ARG BASE_IMAGE=ubuntu:20.04

# Base image with locale set
FROM $BASE_IMAGE as base-with-locale
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN    apt-get update && apt-get install -y locales  \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# -----------------------------------------------------------------------------
# Base image for building tools and virtual environments
FROM base-with-locale as base-build

WORKDIR /build

COPY docker/packages-build.txt docker/packages-venv.txt ./
RUN --mount=type=cache,id=apt-base-build,target=/var/cache/apt \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

# Build
# -----------------------------------------------------------------------------
# Image where XMOS/HAL services are built
FROM base-build as build-hal

WORKDIR /opt/mycroft

# -----------------------------------------------------------------------------
FROM base-build as build-dinkum

RUN    apt-get update && apt-get upgrade && apt-get install -y python3-venv

# Create dinkum (shared) virtual environment
WORKDIR /opt/mycroft-dinkum

ENV DINKUM_VENV=/opt/mycroft-dinkum/.venv

# Just copy requirements and scripts so we don't have to rebuild this every time
# a code file changes.
COPY mycroft-dinkum/services/audio/requirements/ ./services/audio/requirements/
COPY mycroft-dinkum/services/enclosure/requirements/ ./services/enclosure/requirements/
COPY mycroft-dinkum/services/hal/requirements/ ./services/hal/requirements/
COPY mycroft-dinkum/services/intent/requirements/ ./services/intent/requirements/
COPY mycroft-dinkum/services/messagebus/requirements/ ./services/messagebus/requirements/
COPY mycroft-dinkum/services/voice/requirements/ ./services/voice/requirements/

# Skill requirements
COPY mycroft-dinkum/skills/alarm.mark2/requirements.txt ./skills/alarm.mark2/
COPY mycroft-dinkum/skills/homeassistant.mark2/requirements.txt ./skills/homeassistant.mark2/
COPY mycroft-dinkum/skills/homescreen.mark2/requirements.txt ./skills/homescreen.mark2/
COPY mycroft-dinkum/skills/ip.mark2/requirements.txt ./skills/ip.mark2/
COPY mycroft-dinkum/skills/news.mark2/requirements.txt ./skills/news.mark2/
COPY mycroft-dinkum/skills/play-radio.mark2/requirements.txt ./skills/play-radio.mark2/
COPY mycroft-dinkum/skills/query-duck-duck-go.mark2/requirements.txt ./skills/query-duck-duck-go.mark2/
COPY mycroft-dinkum/skills/query-wiki.mark2/requirements.txt ./skills/query-wiki.mark2/
COPY mycroft-dinkum/skills/query-wolfram-alpha.mark2/requirements.txt ./skills/query-wolfram-alpha.mark2/
COPY mycroft-dinkum/skills/time.mark2/requirements.txt ./skills/time.mark2/
COPY mycroft-dinkum/skills/timer.mark2/requirements.txt ./skills/timer.mark2/
COPY mycroft-dinkum/skills/weather.mark2/requirements.txt ./skills/weather.mark2/

# Create shared virtual environment with upgraded pip/setuptools
#
# NOTE: It's crucial that system site packages are available so the HAL service
# can access RPi.GPIO.
#
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    python3 -m venv --system-site-packages "${DINKUM_VENV}" && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade pip && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade wheel setuptools

# Install dinkum service/skill requirements
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    find ./ -name 'requirements.txt' -type f -print0 | \
    xargs -0 printf -- '-r %s ' | xargs "${DINKUM_VENV}/bin/pip3" install

# Install plugins
COPY mycroft-dinkum/plugins/ ./plugins/
COPY docker/build/mycroft/wheels/ ./wheels/
RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install ./plugins/hotword_precise/ && \
    "${DINKUM_VENV}/bin/pip3" install -f ./wheels/ ./plugins/stt_coqui/ && \
    "${DINKUM_VENV}/bin/pip3" install ./plugins/stt_vosk/ 

# Install shared dinkum library
COPY mycroft-dinkum/shared/setup.py \
     shared/

COPY mycroft-dinkum/shared/requirements/requirements.txt \
     shared/requirements/

COPY mycroft-dinkum/shared/mycroft/py.typed \
     mycroft-dinkum/shared/mycroft/__init__.py \
     shared/mycroft/

RUN --mount=type=cache,id=pip-build-dinkum,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install -e ./shared/

# Create dinkum.target and services
COPY mycroft-dinkum/scripts/generate-systemd-units.py ./scripts/
RUN scripts/generate-systemd-units.py \
        --user mycroft \
        --venv-dir "${DINKUM_VENV}" \
        --service 0 services/messagebus \
        --service 1 services/hal \
        --service 1 services/audio \
        --service 1 services/intent \
        --service 2 services/skills \
        --service 3 services/enclosure \
        --skill skills/alarm.mark2 \
        --skill skills/date.mark2 \
        --skill skills/fallback-query.mark2 \
        --skill skills/fallback-unknown.mark2 \
        --skill skills/homeassistant.mark2 \
        --skill skills/homescreen.mark2 \
        --skill skills/ip.mark2 \
        --skill skills/microphone.mark2 \
        --skill skills/news.mark2 \
        --skill skills/play.mark2 \
        --skill skills/play-music.mark2 \
        --skill skills/play-radio.mark2 \
        --skill skills/privacy.mark2 \
        --skill skills/query-duck-duck-go.mark2 \
        --skill skills/query-wiki.mark2 \
        --skill skills/query-wolfram-alpha.mark2 \
        --skill skills/settings.mark2 \
        --skill skills/stop.mark2 \
        --skill skills/time.mark2 \
        --skill skills/timer.mark2 \
        --skill skills/volume.mark2 \
        --skill skills/weather.mark2

# Run

FROM base-with-locale as run

# Add Mycroft alternatives
RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    apt-get update && \
    apt-get --yes --no-install-recommends install \
    software-properties-common gpg-agent locales

COPY docker/packages-run.txt docker/packages-dev.txt ./
RUN apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

# Create mycroft user (#1050)
COPY docker/build/mycroft/create-mycroft-user.sh ./
RUN ./create-mycroft-user.sh

# Enable/disable services at boot.
RUN systemctl disable NetworkManager && \
    systemctl disable networking && \
    systemctl disable apt-daily-upgrade && \
    systemctl disable snapd.service && \
    systemctl disable snapd.socket && \
    systemctl disable kmod-static-nodes

# Copy HAL tools
COPY --from=build-hal --chown=mycroft:mycroft /opt/mycroft/ /opt/mycroft/

# Copy dinkum code and virtual environment
COPY --from=build-dinkum --chown=mycroft:mycroft /opt/mycroft-dinkum/.venv/ /opt/mycroft-dinkum/.venv/
COPY --chown=mycroft:mycroft mycroft-dinkum/ /opt/mycroft-dinkum/
RUN sed -i 's|worktree\s\+=.*|worktree = ../|' /opt/mycroft-dinkum/.git/config

# Need to unzip model
RUN gunzip --keep /opt/mycroft-dinkum/.venv/lib/python3.8/site-packages/mycroft_coqui/models/english_v1.0.0-large-vocab/large_vocabulary.scorer.gz

# Copy system files
COPY docker/files/etc/ /etc/
COPY docker/files/lib/ /lib/
COPY docker/files/opt/ /opt/
COPY docker/files/usr/ /usr/
COPY mark-ii-raspberrypi/files/etc/ /etc/
COPY mark-ii-raspberrypi/files/opt/ /opt/
COPY mark-ii-raspberrypi/files/usr/ /usr/
COPY mark-ii-raspberrypi/pre-built/ /

# Copy user files
COPY --chown=mycroft:mycroft mark-ii-raspberrypi/files/home/pi/ /home/mycroft/
COPY --chown=mycroft:mycroft docker/files/home/mycroft/ /home/mycroft/
COPY --chown=mycroft:mycroft vk_tests/ /home/mycroft/

# The .config directory is not getting the right owner for some reason - force it.
RUN chown mycroft:mycroft /home/mycroft/.config

COPY --from=build-dinkum /etc/systemd/system/dinkum* /etc/systemd/system/
RUN systemctl enable /etc/systemd/system/mycroft-hal.service && \
    systemctl enable /etc/systemd/system/dinkum.target && \
    systemctl set-default graphical

# Automatically log into the mycroft account
RUN { echo 'source /opt/mycroft/.camerarc'; echo 'su -l mycroft'; } >> /root/.bashrc
RUN { echo 'bash /home/mycroft/run_vk_tests.sh'; } >> /home/mycroft/.bashrc

# Generate container build timestamp
COPY docker/build/mycroft/store-build-date.sh /opt/mycroft/bin/
RUN /opt/mycroft/bin/store-build-date.sh

# Clean up
RUN apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/ && \
    rm -f /etc/apt/apt.conf.d/01cache

WORKDIR /home/mycroft

ENTRYPOINT [ "/lib/systemd/systemd" ]
