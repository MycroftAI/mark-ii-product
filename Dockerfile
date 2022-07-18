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

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache

COPY docker/packages-build.txt ./

RUN --mount=type=cache,id=apt-build,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends

WORKDIR /build

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

# -----------------------------------------------------------------------------
# Mycroft Virtual Environment
# -----------------------------------------------------------------------------

FROM $BASE_IMAGE as venv
ARG TARGETARCH
ARG TARGETVARIANT

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/build

# Only Python 3.10 is available on Ubuntu 22.04
# Get 3.9 from the friendly dead snakes
RUN apt-get update && \
    apt install software-properties-common gpg-agent --yes --no-install-recommends
RUN add-apt-repository ppa:deadsnakes/ppa

COPY docker/packages-venv.txt ./

RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat packages-*.txt | xargs apt-get install --yes --no-install-recommends && \
    apt-get clean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/

# Set up XMOS startup sequence
COPY docker/files/home/mycroft/.local/ /home/mycroft/.local/
RUN --mount=type=cache,id=pip-run,target=/root/.cache/pip \
    cd /home/mycroft/.local/share/mycroft/xmos-setup && \
    ./install-xmos.sh

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

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache

# Only Python 3.10 is available on Ubuntu 22.04
# Get 3.9 from the friendly dead snakes
RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    apt install software-properties-common gpg-agent --yes --no-install-recommends
RUN add-apt-repository ppa:deadsnakes/ppa

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
# Pre-built virtual environments
COPY --from=venv --chown=mycroft:mycroft /home/mycroft/.local/share/mycroft/xmos-setup/venv/ /home/mycroft/.local/share/mycroft/xmos-setup/venv/

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

RUN systemctl enable /etc/systemd/system/mycroft-xmos.service && \
    systemctl enable /etc/systemd/system/mycroft-plasma.service && \
    systemctl enable /etc/systemd/system/mycroft-switch.service && \
    systemctl enable /etc/systemd/system/mycroft-volume.service && \
    systemctl set-default graphical

RUN mkdir -p /var/log/mycroft && \
    chown -R mycroft:mycroft /var/log/mycroft

# TODO: remove lib/modules and lib/firmware

# Clean up
RUN rm -f /etc/apt/apt.conf.d/01cache

ENTRYPOINT [ "/lib/systemd/systemd" ]

