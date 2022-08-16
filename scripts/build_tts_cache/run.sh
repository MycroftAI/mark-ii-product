#!/usr/bin/env bash
set -ex

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"

venv_dir="${this_dir}/.venv"
if [ ! -d "${venv_dir}" ]; then
    echo "Missing virtual environment in ${venv_dir}";
    echo 'Did you run install.sh?';
    exit 1;
fi


repo_dir="$(realpath "${this_dir}/../..")"
skills_dir="${repo_dir}/mycroft-dinkum/skills"
cache_dir="${repo_dir}/docker/files/opt/mycroft/preloaded_cache/Mimic3"

mkdir -p "${cache_dir}"

# Print lines from all en-us dialog files to stdin of program in parallel.
# A newline is added between files with echo.
find "${skills_dir}" -wholename '*/en-us/*.dialog' -print0 | \
    xargs -0 -I{} sh -c 'cat "{}"; echo ""' | \
    parallel -X --pipe "${venv_dir}/bin/python3" "${this_dir}/__main__.py" "${cache_dir}"
