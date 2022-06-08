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

FROM scratch as base

ADD raspberry-pi-os/p2.tar /

# -----------------------------------------------------------------------------

FROM base as run
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

COPY docker/packages-*.txt ./

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

# Enable/disable services at boot.
RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-firefox.service && \
    systemctl set-default graphical

# Clean up
RUN rm -f /etc/apt/apt.conf.d/01cache
