#!/usr/bin/fakeroot /bin/bash
#
# Creates a squashfs file from a docker tag.
#
# Requires squashfs-tools to be installed.
# sudo apt-get install squashfs-tools
#
set -o errexit
set -o pipefail

docker_tag="$1"
squashfs_file="$2"

if [ -z "${squashfs_file}" ]; then
  echo 'Usage: docker2squash.sh DOCKER_TAG OUTPUT_FILE'
  exit 1
fi

temp_dir=$(mktemp -d -p .)

cleanup() {
  rm -rf "${temp_dir}"
}

trap cleanup EXIT

# Create docker container from tag and export to temporary directory
container_id="$(docker create "${docker_tag}")"
docker export "${container_id}" | tar -C "${temp_dir}" -p -s --same-owner -xv
docker rm "${container_id}"

# Create squashfs file
mksquashfs "${temp_dir}" "${squashfs_file}"
