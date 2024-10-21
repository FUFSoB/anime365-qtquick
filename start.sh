#!/bin/bash

set -e

BASEDIR="$(realpath "$(dirname "${0}")")"
source "$BASEDIR/venv/bin/activate"

python "$BASEDIR/src/main.py" "$@"
