#!/bin/bash

set -e

BASEDIR="$(realpath "$(dirname "${0}")")"
source "$BASEDIR/venv/bin/activate"

(
    cd $BASEDIR/src
    python "$BASEDIR/src/main.py" "$@"
)
