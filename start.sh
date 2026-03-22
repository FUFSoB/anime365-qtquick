#!/usr/bin/env bash

set -e

BASEDIR="$(realpath "$(dirname "${0}")")"

cd "$BASEDIR/src"
uv run --project "$BASEDIR" python "$BASEDIR/src/main.py" "$@"
