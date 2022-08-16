#!/usr/bin/env bash
set -ex

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

repo_dir="$(realpath "${this_dir}/../..")"
mimic3_dir="${repo_dir}/mimic3"

venv_dir="${this_dir}/.venv"

# Create virtual environment.
#
python3 -m venv "${venv_dir}"
"${venv_dir}/bin/pip3" install --upgrade pip
"${venv_dir}/bin/pip3" install --upgrade wheel setuptools
"${venv_dir}/bin/pip3" install -e "${mimic3_dir}"
"${venv_dir}/bin/pip3" install -r "${this_dir}/requirements.txt"
