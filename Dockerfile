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

# Build Mycroft GUI
FROM mycroftai/pi-os-lite-base:2022-04-04 as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache

COPY docker/packages-build.txt ./

RUN --mount=type=cache,id=apt-build,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

WORKDIR /build

COPY mycroft-dinkum/services/gui/mycroft-gui/ ./mycroft-gui/
COPY docker/build/gui/build-mycroft-gui.sh ./
RUN ./build-mycroft-gui.sh

COPY mycroft-dinkum/services/gui/lottie-qml/ ./lottie-qml/
COPY docker/build/gui/build-lottie-qml.sh ./
RUN ./build-lottie-qml.sh

COPY mycroft-dinkum/services/gui/mycroft-gui-mark-2/ ./mycroft-gui-mark-2/
COPY docker/build/gui/build-mycroft-gui-mark-2.sh ./
RUN ./build-mycroft-gui-mark-2.sh

# Create dinkum (shared) virtual environment
WORKDIR /opt/mycroft-dinkum

ENV DINKUM_VENV=/home/pi/.config/mycroft/.venv

# Just copy requirements and scripts so we don't have to rebuild this every time
# a code file changes.
COPY mycroft-dinkum/services/audio/requirements/ ./services/audio/requirements/
COPY mycroft-dinkum/services/enclosure/requirements/ ./services/enclosure/requirements/
COPY mycroft-dinkum/services/gui/requirements/ ./services/gui/requirements/
COPY mycroft-dinkum/services/intent/requirements/ ./services/intent/requirements/
COPY mycroft-dinkum/services/messagebus/requirements/ ./services/messagebus/requirements/
COPY mycroft-dinkum/services/voice/requirements/ ./services/voice/requirements/

# COPY mycroft-dinkum/skills/date.mycroftai/requirements.txt ./skills/date.mycroftai/
# COPY mycroft-dinkum/skills/mycroft-stop.mycroftai/requirements.txt ./skills/mycroft-stop.mycroftai/
# COPY mycroft-dinkum/skills/fallback-unknown.mycroftai/requirements.txt ./skills/fallback-unknown.mycroftai/
# COPY mycroft-dinkum/skills/fallback-query.mycroftai/requirements.txt ./skills/fallback-query.mycroftai/
COPY mycroft-dinkum/skills/homescreen.mycroftai/requirements.txt ./skills/homescreen.mycroftai/
COPY mycroft-dinkum/skills/time.mycroftai/requirements.txt ./skills/time.mycroftai/
COPY mycroft-dinkum/skills/mycroft-ip.mycroftai/requirements.txt ./skills/mycroft-ip.mycroftai/
COPY mycroft-dinkum/skills/fallback-query.mycroftai/requirements.txt ./skills/mycroft-fallback-query.mycroftai/
COPY mycroft-dinkum/skills/fallback-wolfram-alpha.mycroftai/requirements.txt ./skills/mycroft-fallback-wolfram-alpha.mycroftai/
COPY mycroft-dinkum/skills/mycroft-fallback-duck-duck-go.mycroftai/requirements.txt ./skills/mycroft-fallback-duck-duck-go.mycroftai/
COPY mycroft-dinkum/skills/mycroft-wiki.mycroftai/requirements.txt ./skills/mycroft-wiki.mycroftai/
COPY mycroft-dinkum/skills/mycroft-weather.mycroftai/requirements.txt ./skills/mycroft-weather.mycroftai/

# Create shared virtual environment with upgraded pip/setuptools
#
# NOTE: It's crucial that system site packages are available so the HAL service
# can access RPi.GPIO.
#
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    python3 -m venv --upgrade-deps --system-site-packages "${DINKUM_VENV}" && \
    "${DINKUM_VENV}/bin/pip3" install --upgrade wheel

# Install dinkum service/skill requirements
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    find ./ -name 'requirements.txt' -type f -print0 | \
    xargs -0 printf -- '-r %s ' | xargs "${DINKUM_VENV}/bin/pip3" install

# Install plugins
COPY mycroft-dinkum/plugins/ ./plugins/
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install ./plugins/hotword_precise/ && \
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

RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
    "${DINKUM_VENV}/bin/pip3" install -e ./shared/

# Create dinkum.target and services
COPY mycroft-dinkum/scripts/generate-systemd-units.py ./scripts/
RUN scripts/generate-systemd-units.py \
        --user pi \
        --service 0 services/messagebus \
        --service 1 services/hal \
        --service 1 services/audio \
        --service 1 services/gui \
        --service 1 services/intent \
        --service 1 services/voice \
        --service 2 services/skills \
        --service 3 services/enclosure \
        --skill skills/homescreen.mycroftai \
        --skill skills/date.mycroftai \
        --skill skills/time.mycroftai \
        --skill skills/mycroft-ip.mycroftai \
        --skill skills/mycroft-stop.mycroftai \
        --skill skills/mycroft-weather.mycroftai \
        --skill skills/fallback-unknown.mycroftai \
        --skill skills/fallback-query.mycroftai \
        --skill skills/mycroft-fallback-duck-duck-go.mycroftai \
        --skill skills/mycroft-wiki.mycroftai \
        --skill skills/fallback-wolfram-alpha.mycroftai

# -----------------------------------------------------------------------------

FROM mycroftai/pi-os-lite-base:2022-04-04 as run
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /opt/build

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache

COPY docker/packages-run.txt docker/packages-dev.txt ./

RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends && \
    apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/

# Copy pre-built GUI files
COPY --from=build /usr/local/ /usr/
COPY --from=build /usr/lib/aarch64-linux-gnu/qt5/qml/ /usr/lib/aarch64-linux-gnu/qt5/qml/

# Enable I2C
RUN raspi-config nonint do_i2c 0 && \
    raspi-config nonint do_spi 0

# Set up XMOS startup sequence
COPY --chown=pi:pi docker/files/home/pi/.local/ /home/pi/.local/
COPY --chown=pi:pi docker/files/home/pi/.asoundrc /home/pi/
RUN --mount=type=cache,id=pip-run,target=/root/.cache/pip \
    cd /home/pi/.local/share/mycroft/xmos-setup && \
    ./install-xmos.sh

# Copy system files
COPY docker/files/usr/ /usr/
COPY docker/files/etc/ /etc/
COPY docker/files/var/ /var/
COPY docker/files/opt/ /opt/

# Install the Noto Sans font family
ADD docker/build/mycroft/NotoSans-hinted.tar.gz /usr/share/fonts/truetype/noto-sans/
COPY docker/build/mycroft/install-fonts.sh ./
RUN ./install-fonts.sh

# Enable/disable services at boot.
COPY --from=build /etc/systemd/system/dinkum* /etc/systemd/system/
RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-plasma.service && \
    systemctl enable /etc/systemd/system/dinkum.target && \
    systemctl set-default graphical

# Copy dinkum code and virtual environment
COPY --from=build --chown=pi:pi /home/pi/.config/mycroft/ /home/pi/.config/mycroft/
COPY mycroft-dinkum/ /opt/mycroft-dinkum/

# Copy user files
COPY --chown=pi:pi docker/files/home/pi/.bash_profile /home/pi/
COPY --chown=pi:pi docker/files/home/pi/.local/share/ /home/pi/.local/share/
COPY --chown=pi:pi docker/files/home/pi/.config/ /home/pi/.config/

# TODO: remove lib/modules and lib/firmware

# Clean up
RUN rm -f /etc/apt/apt.conf.d/01cache
